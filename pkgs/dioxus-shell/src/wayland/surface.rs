use anyhow::Result;
use log::debug;
use smithay_client_toolkit::{
    reexports::client::protocol::wl_output,
    shell::{wlr_layer::LayerSurface, WaylandSurface},
};

use crate::render::Renderer;

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
        // SCTK doesn't expose the output bound at create time on LayerSurface
        // directly; for now we don't track it here. Multi-output handling at
        // the skeleton stage is by-surface, not by-output.
        None
    }

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
            r.render()?;
        }
        self.layer.commit();
        Ok(())
    }

    pub fn on_frame(&mut self) {
        // Nothing to do at the skeleton stage — bar is static.
        // Future: drive widget animations / Dioxus renders here.
    }
}
