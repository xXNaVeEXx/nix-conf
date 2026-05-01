use anyhow::{anyhow, Context, Result};
use raw_window_handle::{
    DisplayHandle, HandleError, HasDisplayHandle, HasWindowHandle, RawDisplayHandle,
    RawWindowHandle, WaylandDisplayHandle, WaylandWindowHandle, WindowHandle,
};
use smithay_client_toolkit::reexports::client::{protocol::wl_surface::WlSurface, Proxy};
use std::num::NonZeroUsize;
use std::ptr::NonNull;
use std::time::Instant;
use vello::peniko::Color;
use vello::wgpu::util::TextureBlitter;
use vello::{
    AaConfig, AaSupport, RenderParams, Renderer as VelloRenderer, RendererOptions, Scene,
};
use wgpu::{
    Backends, CommandEncoderDescriptor, Device, Extent3d, Instance, InstanceDescriptor, PresentMode,
    Queue, Surface, SurfaceConfiguration, Texture, TextureDescriptor, TextureDimension,
    TextureFormat, TextureUsages, TextureView, TextureViewDescriptor,
};

use crate::ui::Ui;

// Vello uses a compute shader to render. It needs a Rgba8Unorm storage texture
// as its target; the result then gets blitted onto the swapchain. See
// vello::util::create_targets at vello-0.8.0/src/util.rs:189.
const VELLO_TARGET_FORMAT: TextureFormat = TextureFormat::Rgba8Unorm;

// Backgound color for the bar. Vello applies its own gamma; the swapchain
// format is non-sRGB so this is the value the user sees.
const BAR_BG: Color = Color::from_rgba8(18, 23, 31, 255);

/// The Vello rendering backend chosen at startup based on the wgpu adapter.
enum VelloBackend {
    /// GPU compute path: vello::Renderer renders into an intermediate texture
    /// that we then blit to the swapchain.
    Gpu {
        vello: VelloRenderer,
        target_texture: Texture,
        target_view: TextureView,
    },
    /// CPU rasterization path: vello_cpu produces a Pixmap (RGBA bytes) which
    /// we upload to an intermediate texture, then blit to the swapchain. Used
    /// when the wgpu adapter is software (llvmpipe etc.) where the GPU compute
    /// path is unreliable for image rendering.
    Cpu {
        target_texture: Texture,
        target_view: TextureView,
    },
}

pub struct Renderer {
    _instance: Instance,
    surface: Surface<'static>,
    device: Device,
    queue: Queue,
    config: SurfaceConfiguration,
    backend: VelloBackend,
    blitter: TextureBlitter,
    ui: Ui,
    started_at: Instant,
    first_paint: bool,
}

impl Renderer {
    pub fn new(
        wl_surface: &WlSurface,
        width: u32,
        height: u32,
        build_ui: impl FnOnce(u32, u32) -> Ui,
    ) -> Result<Self> {
        let instance = Instance::new(&InstanceDescriptor {
            backends: Backends::VULKAN,
            ..Default::default()
        });

        let raw_display = wl_surface
            .backend()
            .upgrade()
            .ok_or_else(|| anyhow!("wayland backend gone"))?;
        let display_ptr = raw_display.display_ptr() as *mut std::ffi::c_void;
        let surface_ptr = wl_surface.id().as_ptr() as *mut std::ffi::c_void;

        let target = RawWaylandTarget {
            display: NonNull::new(display_ptr).ok_or_else(|| anyhow!("null wl_display"))?,
            surface: NonNull::new(surface_ptr).ok_or_else(|| anyhow!("null wl_surface"))?,
        };

        let raw_display = target
            .display_handle()
            .map_err(|e| anyhow!("display handle: {e}"))?
            .as_raw();
        let raw_window = target
            .window_handle()
            .map_err(|e| anyhow!("window handle: {e}"))?
            .as_raw();

        // SAFETY: wl_display + wl_surface remain valid for the lifetime of
        // `Renderer` because BarSurface owns the LayerSurface (and thus the
        // WlSurface), and the Connection lives for the program's lifetime.
        let surface = unsafe {
            instance
                .create_surface_unsafe(wgpu::SurfaceTargetUnsafe::RawHandle {
                    raw_display_handle: raw_display,
                    raw_window_handle: raw_window,
                })
                .context("create_surface")?
        };

        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::LowPower,
            compatible_surface: Some(&surface),
            force_fallback_adapter: false,
        }))
        .map_err(|e| anyhow!("no compatible wgpu adapter: {e}"))?;

        // Default to the GPU path — it's faster and works on both real GPUs
        // and software-Vulkan adapters (llvmpipe). vello_cpu is the fallback
        // if GPU init fails.
        //
        // Override via DIOXUS_SHELL_RENDER env: "gpu" forces GPU, "cpu" forces
        // vello_cpu, anything else uses the default (try GPU first).
        let info = adapter.get_info();
        let prefer_cpu = matches!(
            std::env::var("DIOXUS_SHELL_RENDER")
                .unwrap_or_default()
                .to_lowercase()
                .as_str(),
            "cpu"
        );
        log::info!(
            "wgpu adapter: {} ({}; type={:?}); render path: {}",
            info.name,
            info.driver,
            info.device_type,
            if prefer_cpu { "CPU (vello_cpu)" } else { "GPU (vello)" }
        );

        let (device, queue) = pollster::block_on(adapter.request_device(
            &wgpu::DeviceDescriptor {
                label: Some("dioxus-shell"),
                required_features: wgpu::Features::empty(),
                required_limits: wgpu::Limits::default(),
                experimental_features: wgpu::ExperimentalFeatures::default(),
                memory_hints: wgpu::MemoryHints::Performance,
                trace: wgpu::Trace::Off,
            },
        ))
        .context("request_device")?;

        // Vello requires a non-sRGB swapchain format. Prefer Bgra8Unorm if the
        // surface advertises it, otherwise Rgba8Unorm.
        let caps = surface.get_capabilities(&adapter);
        let format = caps
            .formats
            .iter()
            .copied()
            .find(|f| matches!(f, TextureFormat::Bgra8Unorm | TextureFormat::Rgba8Unorm))
            .ok_or_else(|| anyhow!("surface supports neither Bgra8Unorm nor Rgba8Unorm"))?;

        let config = SurfaceConfiguration {
            usage: TextureUsages::RENDER_ATTACHMENT,
            format,
            width: width.max(1),
            height: height.max(1),
            present_mode: PresentMode::Fifo,
            alpha_mode: caps.alpha_modes[0],
            view_formats: vec![],
            desired_maximum_frame_latency: 2,
        };
        surface.configure(&device, &config);

        let backend = if prefer_cpu {
            // CPU path: target texture receives uploaded RGBA bytes from
            // vello_cpu's Pixmap.
            let (texture, view) = create_cpu_target(&device, config.width, config.height);
            VelloBackend::Cpu {
                target_texture: texture,
                target_view: view,
            }
        } else {
            // GPU path: try to init vello's wgpu renderer; on failure (e.g.
            // unsupported feature on this adapter) fall back to vello_cpu.
            let (texture, view) = create_vello_target(&device, config.width, config.height);
            match VelloRenderer::new(
                &device,
                RendererOptions {
                    use_cpu: false,
                    antialiasing_support: AaSupport::all(),
                    num_init_threads: NonZeroUsize::new(1),
                    pipeline_cache: None,
                },
            ) {
                Ok(vello_renderer) => VelloBackend::Gpu {
                    vello: vello_renderer,
                    target_texture: texture,
                    target_view: view,
                },
                Err(e) => {
                    log::warn!(
                        "vello GPU renderer init failed ({e}); falling back to vello_cpu"
                    );
                    let (texture, view) =
                        create_cpu_target(&device, config.width, config.height);
                    VelloBackend::Cpu {
                        target_texture: texture,
                        target_view: view,
                    }
                }
            }
        };

        let blitter = TextureBlitter::new(&device, format);
        let ui = build_ui(config.width, config.height);

        Ok(Self {
            _instance: instance,
            surface,
            device,
            queue,
            config,
            backend,
            blitter,
            ui,
            started_at: Instant::now(),
            first_paint: true,
        })
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        let w = width.max(1);
        let h = height.max(1);
        if w == self.config.width && h == self.config.height {
            return;
        }
        self.config.width = w;
        self.config.height = h;
        self.surface.configure(&self.device, &self.config);
        match &mut self.backend {
            VelloBackend::Gpu {
                target_texture,
                target_view,
                ..
            } => {
                let (t, v) = create_vello_target(&self.device, w, h);
                *target_texture = t;
                *target_view = v;
            }
            VelloBackend::Cpu {
                target_texture,
                target_view,
            } => {
                let (t, v) = create_cpu_target(&self.device, w, h);
                *target_texture = t;
                *target_view = v;
            }
        }
        self.ui.resize(w, h);
    }

    /// Called from the per-tick loop. Polls Dioxus; if the document changed
    /// or this is the first paint, runs a full render. Returns true iff a
    /// render+present happened (so the caller knows whether to commit).
    pub fn tick(&mut self) -> Result<bool> {
        let dirty_flag = self.ui.dirty_flag();
        let was_dirty = dirty_flag.take();
        // Always poll: drives tokio forward (use_future intervals etc.) even
        // when no signal fired this round.
        let dom_changed = self.ui.poll();
        if !was_dirty && !dom_changed && !self.first_paint {
            return Ok(false);
        }
        self.render()?;
        self.first_paint = false;
        Ok(true)
    }

    fn render(&mut self) -> Result<()> {
        let frame = self
            .surface
            .get_current_texture()
            .context("acquire surface texture")?;
        let swapchain_view = frame.texture.create_view(&TextureViewDescriptor::default());

        let now_secs = self.started_at.elapsed().as_secs_f64();

        let target_view = match &mut self.backend {
            VelloBackend::Gpu {
                vello,
                target_texture: _,
                target_view,
            } => {
                let mut scene = Scene::new();
                self.ui.paint(&mut scene, now_secs);
                vello
                    .render_to_texture(
                        &self.device,
                        &self.queue,
                        &scene,
                        target_view,
                        &RenderParams {
                            base_color: BAR_BG,
                            width: self.config.width,
                            height: self.config.height,
                            antialiasing_method: AaConfig::Area,
                        },
                    )
                    .map_err(|e| anyhow!("vello render_to_texture: {e}"))?;
                &*target_view
            }
            VelloBackend::Cpu {
                target_texture,
                target_view,
            } => {
                let pixmap = self.ui.paint_cpu(now_secs);
                // Upload the CPU-rasterized pixels into the target texture.
                // vello_cpu's Pixmap is RGBA8 premultiplied; our target
                // texture format is Rgba8Unorm.
                let bytes = pixmap.data();
                self.queue.write_texture(
                    wgpu::TexelCopyTextureInfo {
                        texture: target_texture,
                        mip_level: 0,
                        origin: wgpu::Origin3d::ZERO,
                        aspect: wgpu::TextureAspect::All,
                    },
                    bytemuck::cast_slice(bytes),
                    wgpu::TexelCopyBufferLayout {
                        offset: 0,
                        bytes_per_row: Some(self.config.width * 4),
                        rows_per_image: Some(self.config.height),
                    },
                    wgpu::Extent3d {
                        width: self.config.width,
                        height: self.config.height,
                        depth_or_array_layers: 1,
                    },
                );
                &*target_view
            }
        };

        let mut encoder = self
            .device
            .create_command_encoder(&CommandEncoderDescriptor {
                label: Some("vello-blit"),
            });
        self.blitter
            .copy(&self.device, &mut encoder, target_view, &swapchain_view);
        self.queue.submit(Some(encoder.finish()));
        frame.present();
        Ok(())
    }
}

fn create_vello_target(device: &Device, width: u32, height: u32) -> (Texture, TextureView) {
    let texture = device.create_texture(&TextureDescriptor {
        label: Some("vello-target"),
        size: Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: TextureDimension::D2,
        format: VELLO_TARGET_FORMAT,
        usage: TextureUsages::STORAGE_BINDING | TextureUsages::TEXTURE_BINDING,
        view_formats: &[],
    });
    let view = texture.create_view(&TextureViewDescriptor::default());
    (texture, view)
}

/// Target texture for the CPU rasterization path. Receives uploads from
/// `Queue::write_texture`; sampled by `TextureBlitter::copy` to reach the
/// swapchain. Different usage flags than the GPU path.
fn create_cpu_target(device: &Device, width: u32, height: u32) -> (Texture, TextureView) {
    let texture = device.create_texture(&TextureDescriptor {
        label: Some("vello-cpu-target"),
        size: Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: TextureDimension::D2,
        format: VELLO_TARGET_FORMAT,
        usage: TextureUsages::COPY_DST | TextureUsages::TEXTURE_BINDING,
        view_formats: &[],
    });
    let view = texture.create_view(&TextureViewDescriptor::default());
    (texture, view)
}

// Bridge between SCTK's raw Wayland pointers and raw-window-handle 0.6, which
// is what wgpu expects.
struct RawWaylandTarget {
    display: NonNull<std::ffi::c_void>,
    surface: NonNull<std::ffi::c_void>,
}

impl HasDisplayHandle for RawWaylandTarget {
    fn display_handle(&self) -> std::result::Result<DisplayHandle<'_>, HandleError> {
        let raw = RawDisplayHandle::Wayland(WaylandDisplayHandle::new(self.display));
        // SAFETY: pointer remains valid for as long as RawWaylandTarget exists.
        Ok(unsafe { DisplayHandle::borrow_raw(raw) })
    }
}

impl HasWindowHandle for RawWaylandTarget {
    fn window_handle(&self) -> std::result::Result<WindowHandle<'_>, HandleError> {
        let raw = RawWindowHandle::Wayland(WaylandWindowHandle::new(self.surface));
        // SAFETY: same as above.
        Ok(unsafe { WindowHandle::borrow_raw(raw) })
    }
}
