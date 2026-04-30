use anyhow::{anyhow, Context, Result};
use raw_window_handle::{
    DisplayHandle, HandleError, HasDisplayHandle, HasWindowHandle, RawDisplayHandle,
    RawWindowHandle, WaylandDisplayHandle, WaylandWindowHandle, WindowHandle,
};
use smithay_client_toolkit::reexports::client::{protocol::wl_surface::WlSurface, Proxy};
use std::ptr::NonNull;
use wgpu::{
    Backends, Color, CommandEncoderDescriptor, Device, Instance, InstanceDescriptor,
    LoadOp, Operations, PresentMode, Queue, RenderPassColorAttachment, RenderPassDescriptor,
    StoreOp, Surface, SurfaceConfiguration, TextureUsages, TextureViewDescriptor,
};

pub struct Renderer {
    _instance: Instance,
    surface: Surface<'static>,
    device: Device,
    queue: Queue,
    config: SurfaceConfiguration,
}

impl Renderer {
    pub fn new(wl_surface: &WlSurface, width: u32, height: u32) -> Result<Self> {
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

        // SAFETY: wl_display + wl_surface remain valid for the lifetime of `Renderer`
        // because BarSurface owns the LayerSurface (and thus the WlSurface), and the
        // Connection lives for the program's lifetime.
        let raw_display = target
            .display_handle()
            .map_err(|e| anyhow!("display handle: {e}"))?
            .as_raw();
        let raw_window = target
            .window_handle()
            .map_err(|e| anyhow!("window handle: {e}"))?
            .as_raw();

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

        let (device, queue) = pollster::block_on(adapter.request_device(
            &wgpu::DeviceDescriptor {
                label: Some("dioxus-shell"),
                required_features: wgpu::Features::empty(),
                required_limits: wgpu::Limits::downlevel_defaults(),
                experimental_features: wgpu::ExperimentalFeatures::default(),
                memory_hints: wgpu::MemoryHints::Performance,
                trace: wgpu::Trace::Off,
            },
        ))
        .context("request_device")?;

        let caps = surface.get_capabilities(&adapter);
        let format = caps
            .formats
            .iter()
            .copied()
            .find(|f| f.is_srgb())
            .unwrap_or(caps.formats[0]);

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

        Ok(Self {
            _instance: instance,
            surface,
            device,
            queue,
            config,
        })
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        self.config.width = width.max(1);
        self.config.height = height.max(1);
        self.surface.configure(&self.device, &self.config);
    }

    pub fn render(&mut self) -> Result<()> {
        let frame = self
            .surface
            .get_current_texture()
            .context("acquire surface texture")?;
        let view = frame.texture.create_view(&TextureViewDescriptor::default());
        let mut encoder = self
            .device
            .create_command_encoder(&CommandEncoderDescriptor { label: None });
        {
            let _pass = encoder.begin_render_pass(&RenderPassDescriptor {
                label: Some("clear-bar"),
                color_attachments: &[Some(RenderPassColorAttachment {
                    view: &view,
                    depth_slice: None,
                    resolve_target: None,
                    ops: Operations {
                        // Dark slate (#121720) as linear values — sRGB framebuffer
                        // expects linear input and applies the gamma curve at output.
                        load: LoadOp::Clear(Color {
                            r: 0.0056,
                            g: 0.0080,
                            b: 0.0144,
                            a: 1.0,
                        }),
                        store: StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });
        }
        self.queue.submit(Some(encoder.finish()));
        frame.present();
        Ok(())
    }
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
        // SAFETY: pointer remains valid for as long as RawWaylandTarget exists,
        // which is bounded by the surrounding `unsafe { create_surface_unsafe ... }`
        // call in Renderer::new.
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
