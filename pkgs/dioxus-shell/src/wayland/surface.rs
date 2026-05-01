use anyhow::Result;
use log::{debug, warn};
use smithay_client_toolkit::{
    reexports::client::{protocol::wl_output, QueueHandle},
    shell::{wlr_layer::LayerSurface, WaylandSurface},
};

use crate::config::Config;
use crate::render::Renderer;
use crate::ui::{DockApp, Ui};
use crate::wayland::shell::State;
use crate::wayland::Toplevel;
use tokio::sync::watch;

pub struct BarSurface {
    layer: LayerSurface,
    renderer: Option<Renderer>,
    width: u32,
    height: u32,
    configured: bool,
    pending_rx: Option<watch::Receiver<Vec<Toplevel>>>,
}

impl BarSurface {
    pub fn new(layer: LayerSurface, rx: watch::Receiver<Vec<Toplevel>>) -> Self {
        Self {
            layer,
            renderer: None,
            width: 0,
            height: 0,
            configured: false,
            pending_rx: Some(rx),
        }
    }

    pub fn surface(&self) -> &LayerSurface {
        &self.layer
    }

    pub fn output(&self) -> Option<wl_output::WlOutput> {
        // SCTK doesn't expose the output bound at create time on LayerSurface.
        None
    }

    /// Compositor sent us a configure event with new dimensions. Initialize
    /// the renderer (first time) or resize it. Always paints once after.
    pub fn configure(&mut self, width: u32, height: u32) -> Result<()> {
        let resized = width != self.width || height != self.height;
        self.width = width;
        self.height = height;
        self.configured = true;

        if self.renderer.is_none() {
            let rx = self
                .pending_rx
                .take()
                .expect("BarSurface configured twice without a renderer");
            let renderer = Renderer::new(
                self.layer.wl_surface(),
                width,
                height,
                move |w, h| Ui::new_bar(w, h, rx),
            )?;
            self.renderer = Some(renderer);
            debug!("bar renderer initialized {width}x{height}");
        } else if let Some(r) = self.renderer.as_mut() {
            if resized {
                r.resize(width, height);
            }
        }

        if let Some(r) = self.renderer.as_mut() {
            r.tick()?;
        }
        self.layer.commit();
        Ok(())
    }

    /// Called from the calloop tick timer. Drives Dioxus + tokio; only
    /// repaints + commits if the document changed (renderer.tick() handles the
    /// dirty check).
    pub fn tick(&mut self, _qh: &QueueHandle<State>) {
        if !self.configured {
            return;
        }
        if let Some(r) = self.renderer.as_mut() {
            match r.tick() {
                Ok(painted) => {
                    if painted {
                        self.layer.commit();
                    }
                }
                Err(e) => warn!("render failed: {e:#}"),
            }
        }
    }
}

/// A bottom-anchored layer-shell surface displaying running + pinned apps.
/// Sister structure to `BarSurface`: same render+tick lifecycle, different
/// root component (`DockApp`) and a context-injected toplevel receiver.
pub struct DockSurface {
    layer: LayerSurface,
    renderer: Option<Renderer>,
    width: u32,
    height: u32,
    configured: bool,
    /// Stashed at creation time; consumed when the renderer is built so
    /// the dock UI can subscribe to live updates.
    pending_toplevel_rx: Option<watch::Receiver<Vec<Toplevel>>>,
    pending_config_rx: Option<watch::Receiver<Config>>,
    /// Last known pointer position in surface-local coords. None when the
    /// pointer isn't on this dock.
    pointer_pos: Option<(f64, f64)>,
}

impl DockSurface {
    pub fn new(
        layer: LayerSurface,
        toplevel_rx: watch::Receiver<Vec<Toplevel>>,
        config_rx: watch::Receiver<Config>,
    ) -> Self {
        Self {
            layer,
            renderer: None,
            width: 0,
            height: 0,
            configured: false,
            pending_toplevel_rx: Some(toplevel_rx),
            pending_config_rx: Some(config_rx),
            pointer_pos: None,
        }
    }

    pub fn on_pointer_motion(&mut self, x: f64, y: f64) {
        self.pointer_pos = Some((x, y));
    }

    pub fn on_pointer_leave(&mut self) {
        self.pointer_pos = None;
    }

    /// Hit-test which icon-tile is under the cursor and return its app_id.
    /// Caller decides what to do with it (focus existing or launch fresh).
    pub fn hit_test_app_id(&mut self, x: f64, y: f64) -> Option<String> {
        let r = self.renderer.as_mut()?;
        let result = r.ui().app_id_at(x, y);
        log::info!("hit-test at ({x}, {y}) -> {:?}", result);
        result
    }

    pub fn surface(&self) -> &LayerSurface {
        &self.layer
    }

    pub fn configure(&mut self, width: u32, height: u32) -> Result<()> {
        let resized = width != self.width || height != self.height;
        self.width = width;
        self.height = height;
        self.configured = true;

        if self.renderer.is_none() {
            let trx = self
                .pending_toplevel_rx
                .take()
                .expect("DockSurface configured twice without a renderer");
            let crx = self
                .pending_config_rx
                .take()
                .expect("DockSurface configured twice without a renderer");
            let renderer = Renderer::new(
                self.layer.wl_surface(),
                width,
                height,
                move |w, h| {
                    Ui::new(
                        w,
                        h,
                        DockApp,
                        vec![
                            Box::new(trx) as Box<dyn std::any::Any>,
                            Box::new(crx) as Box<dyn std::any::Any>,
                        ],
                    )
                },
            )?;
            self.renderer = Some(renderer);
            debug!("dock renderer initialized {width}x{height}");
        } else if let Some(r) = self.renderer.as_mut() {
            if resized {
                r.resize(width, height);
            }
        }

        if let Some(r) = self.renderer.as_mut() {
            r.tick()?;
        }
        self.layer.commit();
        Ok(())
    }

    pub fn tick(&mut self, _qh: &QueueHandle<State>) {
        if !self.configured {
            return;
        }
        if let Some(r) = self.renderer.as_mut() {
            match r.tick() {
                Ok(painted) => {
                    if painted {
                        self.layer.commit();
                    }
                }
                Err(e) => warn!("dock render failed: {e:#}"),
            }
        }
    }
}
