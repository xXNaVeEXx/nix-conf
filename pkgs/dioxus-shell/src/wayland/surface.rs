use anyhow::Result;
use log::{debug, warn};
use smithay_client_toolkit::{
    reexports::client::{protocol::wl_output, QueueHandle},
    shell::{wlr_layer::LayerSurface, WaylandSurface},
};

use crate::render::Renderer;
use crate::wayland::shell::State;

pub struct BarSurface {
    layer: LayerSurface,
    renderer: Option<Renderer>,
    width: u32,
    height: u32,
    configured: bool,
}

impl BarSurface {
    pub fn new(layer: LayerSurface) -> Self {
        Self {
            layer,
            renderer: None,
            width: 0,
            height: 0,
            configured: false,
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
            let renderer = Renderer::new(self.layer.wl_surface(), width, height)?;
            self.renderer = Some(renderer);
            debug!("renderer initialized {width}x{height}");
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
