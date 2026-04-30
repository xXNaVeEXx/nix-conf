//! Raw zwlr_foreign_toplevel_management_v1 wiring.
//!
//! SCTK 0.19 has no helper for this protocol, so we dispatch it directly via
//! `wayland_client::Dispatch`. Events arrive incrementally and are committed
//! atomically on `done` — `State::toplevels` accumulates per-handle state and
//! `publish_toplevels` flushes a snapshot to a `tokio::sync::watch::Sender`
//! that widgets subscribe to.

use log::debug;
use wayland_client::{event_created_child, Connection, Dispatch, QueueHandle};
use wayland_protocols_wlr::foreign_toplevel::v1::client::{
    zwlr_foreign_toplevel_handle_v1::{self, ZwlrForeignToplevelHandleV1},
    zwlr_foreign_toplevel_manager_v1::{self, ZwlrForeignToplevelManagerV1},
};

use crate::wayland::shell::State;

/// Public, immutable snapshot of a top-level window.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Toplevel {
    pub app_id: String,
    pub title: String,
    pub activated: bool,
    pub minimized: bool,
}

/// Mutable accumulator for per-handle state. Events update this; on `done`
/// the relevant fields are flushed into the public Vec<Toplevel>.
#[derive(Default, Clone)]
pub struct PendingToplevel {
    pub app_id: Option<String>,
    pub title: Option<String>,
    pub activated: Option<bool>,
    pub minimized: Option<bool>,
    pub closed: bool,
}

impl Dispatch<ZwlrForeignToplevelManagerV1, ()> for State {
    fn event(
        state: &mut Self,
        _proxy: &ZwlrForeignToplevelManagerV1,
        event: zwlr_foreign_toplevel_manager_v1::Event,
        _data: &(),
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
        match event {
            zwlr_foreign_toplevel_manager_v1::Event::Toplevel { toplevel } => {
                debug!("foreign_toplevel: new handle");
                state.toplevels.entry(toplevel).or_default();
            }
            zwlr_foreign_toplevel_manager_v1::Event::Finished => {
                state.toplevels.clear();
                state.publish_toplevels();
            }
            _ => {}
        }
    }

    // The `toplevel` event (opcode 0) creates a child object of type
    // ZwlrForeignToplevelHandleV1. wayland-client doesn't auto-derive this;
    // we must declare it.
    event_created_child!(State, ZwlrForeignToplevelManagerV1, [
        0 => (ZwlrForeignToplevelHandleV1, ()),
    ]);
}

impl Dispatch<ZwlrForeignToplevelHandleV1, ()> for State {
    fn event(
        state: &mut Self,
        proxy: &ZwlrForeignToplevelHandleV1,
        event: zwlr_foreign_toplevel_handle_v1::Event,
        _data: &(),
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
        use zwlr_foreign_toplevel_handle_v1::Event;
        let pending = state.toplevels.entry(proxy.clone()).or_default();
        match event {
            Event::Title { title } => pending.title = Some(title),
            Event::AppId { app_id } => pending.app_id = Some(app_id),
            Event::OutputEnter { .. } | Event::OutputLeave { .. } => {
                // Per-output filtering not needed — dock shows all toplevels.
            }
            Event::State { state: bits } => {
                // The state event payload is a Vec<u8>; each chunk of 4 bytes
                // is a u32 enum value. 0=maximized, 1=minimized, 2=activated,
                // 3=fullscreen.
                let mut activated = false;
                let mut minimized = false;
                for chunk in bits.chunks_exact(4) {
                    let v = u32::from_ne_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
                    match v {
                        1 => minimized = true,
                        2 => activated = true,
                        _ => {}
                    }
                }
                pending.activated = Some(activated);
                pending.minimized = Some(minimized);
            }
            Event::Done => {
                state.publish_toplevels();
            }
            Event::Closed => {
                pending.closed = true;
                state.toplevels.remove(proxy);
                state.publish_toplevels();
                proxy.destroy();
            }
            Event::Parent { .. } => {
                // Parent/transient relationships — not relevant for the dock.
            }
            _ => {}
        }
    }
}
