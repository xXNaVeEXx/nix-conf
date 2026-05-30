//! xdg_popup-based right-click context menu for the dock.
//!
//! When the user right-clicks a dock tile, we create a transient popup
//! anchored above the tile. The popup is its own wl_surface, with its
//! own Renderer + Ui rooted at the MenuApp component. Click on a menu
//! action mutates dock.toml (toggle pinned) or sends close() to all
//! matching foreign_toplevel handles. Click outside (compositor sends
//! `popup_done`) or finishing an action destroys the popup.

use anyhow::{Context, Result};
use smithay_client_toolkit::{
    globals::ProvidesBoundGlobal,
    reexports::{
        client::QueueHandle,
        protocols::xdg::shell::client::xdg_positioner::{Anchor, ConstraintAdjustment, Gravity},
    },
    shell::{
        wlr_layer::LayerSurface,
        xdg::popup::Popup,
        WaylandSurface,
    },
};

use crate::render::Renderer;
use crate::ui::{MenuApp, MenuContext, Ui};
use crate::wayland::shell::{State, XdgWmBaseHolder};

const MENU_WIDTH: u32 = 200;
const MENU_HEIGHT: u32 = 80;

pub struct MenuPopup {
    pub popup: Popup,
    pub renderer: Option<Renderer>,
    pub width: u32,
    pub height: u32,
    pub configured: bool,
    pub context: MenuContext,
    pending_ctx: Option<MenuContext>,
}

impl MenuPopup {
    /// Create a popup anchored to the given dock tile's rect (in dock
    /// surface-local coordinates). The popup positions itself above the
    /// tile (gravity Top) and is dismissed automatically by the compositor
    /// when input goes elsewhere.
    pub fn new(
        compositor: &smithay_client_toolkit::compositor::CompositorState,
        xdg_wm_base: &XdgWmBaseHolder,
        parent: &LayerSurface,
        qh: &QueueHandle<State>,
        tile_x: i32,
        tile_y: i32,
        tile_w: i32,
        tile_h: i32,
        context: MenuContext,
    ) -> Result<Self> {
        // XdgPositioner is created via the xdg_wm_base global directly.
        let wm_base = xdg_wm_base
            .bound_global()
            .context("xdg_wm_base bound_global")?;
        let positioner = wm_base.create_positioner(qh, ());
        positioner.set_size(MENU_WIDTH as i32, MENU_HEIGHT as i32);
        positioner.set_anchor_rect(tile_x, tile_y, tile_w, tile_h);
        positioner.set_anchor(Anchor::Top);
        positioner.set_gravity(Gravity::Top);
        // Slide horizontally if the menu would overflow; flip vertically
        // (i.e. drop below the tile) only if there's no room above.
        positioner.set_constraint_adjustment(
            (ConstraintAdjustment::SlideX | ConstraintAdjustment::FlipY).into(),
        );

        let popup_surface = compositor.create_surface(qh);
        let popup =
            Popup::from_surface(None, &positioner, qh, popup_surface, xdg_wm_base)
                .context("create popup")?;
        // Layer-shell parents own popups via get_popup, before commit.
        parent.get_popup(popup.xdg_popup());
        // Initial commit (no buffer) so the compositor sends configure.
        popup.wl_surface().commit();

        positioner.destroy();

        Ok(Self {
            popup,
            renderer: None,
            width: MENU_WIDTH,
            height: MENU_HEIGHT,
            configured: false,
            context: context.clone(),
            pending_ctx: Some(context),
        })
    }

    pub fn configure(&mut self, width: u32, height: u32) -> Result<()> {
        let resized = width != self.width || height != self.height;
        self.width = width.max(1);
        self.height = height.max(1);
        self.configured = true;

        if self.renderer.is_none() {
            let ctx = self
                .pending_ctx
                .take()
                .expect("MenuPopup configured twice without a renderer");
            let renderer = Renderer::new(
                self.popup.wl_surface(),
                self.width,
                self.height,
                move |w, h| {
                    Ui::new(
                        w,
                        h,
                        MenuApp,
                        vec![Box::new(ctx) as Box<dyn std::any::Any>],
                    )
                },
            )?;
            self.renderer = Some(renderer);
        } else if let Some(r) = self.renderer.as_mut() {
            if resized {
                r.resize(self.width, self.height);
            }
        }

        if let Some(r) = self.renderer.as_mut() {
            r.tick()?;
        }
        self.popup.wl_surface().commit();
        Ok(())
    }

    pub fn tick(&mut self) {
        if !self.configured {
            return;
        }
        if let Some(r) = self.renderer.as_mut() {
            match r.tick() {
                Ok(true) => self.popup.wl_surface().commit(),
                Ok(false) => {}
                Err(e) => log::warn!("menu render failed: {e:#}"),
            }
        }
    }

    /// Hit-test for menu actions. Returns the action attribute value if
    /// the cursor is on a menu button, or None.
    pub fn hit_test(&mut self, x: f64, y: f64) -> Option<String> {
        let r = self.renderer.as_mut()?;
        r.ui().menu_action_at(x, y)
    }
}

