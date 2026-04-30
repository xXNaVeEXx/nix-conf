use anyhow::{Context, Result};
use calloop::{EventLoop, LoopHandle, timer::{TimeoutAction, Timer}};
use calloop_wayland_source::WaylandSource;
use log::{debug, info, warn};
use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState},
    delegate_compositor, delegate_layer, delegate_output, delegate_registry,
    output::{OutputHandler, OutputState},
    reexports::client::{
        globals::registry_queue_init, protocol::wl_output, protocol::wl_surface, Connection,
        QueueHandle,
    },
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    shell::{
        wlr_layer::{
            Layer, LayerShell, LayerShellHandler, LayerSurface, LayerSurfaceConfigure,
        },
        WaylandSurface,
    },
};
use std::collections::HashMap;
use std::time::Duration;
use tokio::sync::watch;
use wayland_protocols_wlr::foreign_toplevel::v1::client::{
    zwlr_foreign_toplevel_handle_v1::ZwlrForeignToplevelHandleV1,
    zwlr_foreign_toplevel_manager_v1::ZwlrForeignToplevelManagerV1,
};

use super::surface::{BarSurface, DockSurface};
use super::toplevel::{PendingToplevel, Toplevel};

const BAR_HEIGHT: u32 = 32;
const DOCK_HEIGHT: u32 = 56;

/// How often the calloop timer fires to drive Dioxus + tokio. 100ms is a
/// compromise: low enough that signal updates feel instant, high enough to
/// keep idle CPU low. wgpu's FIFO present mode throttles renders to vsync
/// regardless.
const TICK_INTERVAL: Duration = Duration::from_millis(100);

pub struct Shell {
    event_loop: EventLoop<'static, State>,
    state: State,
}

pub struct State {
    registry_state: RegistryState,
    output_state: OutputState,
    compositor_state: CompositorState,
    layer_shell: LayerShell,
    pub bars: Vec<BarSurface>,
    pub docks: Vec<DockSurface>,
    pub running: bool,
    pub qh: QueueHandle<State>,
    /// Foreign-toplevel manager. Held to keep the global alive; protocol
    /// events are dispatched via the Dispatch impl in toplevel.rs.
    _toplevel_manager: Option<ZwlrForeignToplevelManagerV1>,
    /// Per-handle accumulator. Mutated on each protocol event; flushed into
    /// the watch channel on `done`.
    pub toplevels: HashMap<ZwlrForeignToplevelHandleV1, PendingToplevel>,
    /// Broadcast channel for the public Vec<Toplevel> snapshot. Widgets
    /// subscribe via `toplevel_rx()`.
    toplevel_tx: watch::Sender<Vec<Toplevel>>,
    toplevel_rx: watch::Receiver<Vec<Toplevel>>,
}

impl Shell {
    pub fn new() -> Result<Self> {
        let conn = Connection::connect_to_env().context("connect to wayland display")?;
        let (globals, event_queue) = registry_queue_init(&conn).context("init registry")?;
        let qh = event_queue.handle();

        let compositor_state =
            CompositorState::bind(&globals, &qh).context("bind wl_compositor")?;
        let layer_shell = LayerShell::bind(&globals, &qh).context("bind zwlr_layer_shell_v1")?;
        // Foreign toplevel manager is optional — not all compositors implement
        // it. Log if it's missing but don't fail.
        let toplevel_manager: Option<ZwlrForeignToplevelManagerV1> =
            match globals.bind(&qh, 1..=3, ()) {
                Ok(m) => Some(m),
                Err(e) => {
                    warn!("zwlr_foreign_toplevel_management_v1 unavailable: {e}");
                    None
                }
            };

        let event_loop: EventLoop<'static, State> =
            EventLoop::try_new().context("calloop event loop")?;

        WaylandSource::new(conn, event_queue)
            .insert(event_loop.handle())
            .map_err(|e| anyhow::anyhow!("insert wayland source: {e}"))?;

        let (toplevel_tx, toplevel_rx) = watch::channel(Vec::new());

        let state = State {
            registry_state: RegistryState::new(&globals),
            output_state: OutputState::new(&globals, &qh),
            compositor_state,
            layer_shell,
            bars: Vec::new(),
            docks: Vec::new(),
            running: true,
            qh,
            _toplevel_manager: toplevel_manager,
            toplevels: HashMap::new(),
            toplevel_tx,
            toplevel_rx,
        };

        Ok(Self { event_loop, state })
    }

    /// Subscribe to the live top-level window list. Widgets use this to power
    /// the dock's running-app indicators.
    #[allow(dead_code)]
    pub fn toplevel_rx(&self) -> watch::Receiver<Vec<Toplevel>> {
        self.state.toplevel_rx.clone()
    }

    pub fn run(&mut self) -> Result<()> {
        // First dispatch — the WaylandSource has already set up the connection,
        // and the initial roundtrip happens via the calloop dispatch below.
        // We schedule a tick timer that drives Dioxus + repaints when needed.
        let handle = self.event_loop.handle();
        schedule_tick(&handle);

        // Pump once to surface initial outputs (fires OutputHandler::new_output).
        self.event_loop
            .dispatch(Some(Duration::from_millis(0)), &mut self.state)
            .context("initial dispatch")?;
        info!(
            "running with {} bar(s), {} dock(s)",
            self.state.bars.len(),
            self.state.docks.len()
        );

        while self.state.running {
            self.event_loop
                .dispatch(None, &mut self.state)
                .context("event dispatch")?;
        }
        Ok(())
    }
}

fn schedule_tick(handle: &LoopHandle<'static, State>) {
    let timer = Timer::from_duration(TICK_INTERVAL);
    let _ = handle.insert_source(timer, move |_deadline, _, state| {
        state.tick();
        TimeoutAction::ToDuration(TICK_INTERVAL)
    });
}

impl State {
    fn create_bar(&mut self, qh: &QueueHandle<Self>, output: &wl_output::WlOutput) -> Result<()> {
        let surface = self.compositor_state.create_surface(qh);
        let layer = self.layer_shell.create_layer_surface(
            qh,
            surface,
            Layer::Top,
            Some("dioxus-shell-bar"),
            Some(output),
        );
        layer.set_anchor(
            smithay_client_toolkit::shell::wlr_layer::Anchor::TOP
                | smithay_client_toolkit::shell::wlr_layer::Anchor::LEFT
                | smithay_client_toolkit::shell::wlr_layer::Anchor::RIGHT,
        );
        layer.set_size(0, BAR_HEIGHT);
        layer.set_exclusive_zone(BAR_HEIGHT as i32);
        layer.commit();

        let bar = BarSurface::new(layer, self.toplevel_rx.clone());
        self.bars.push(bar);
        Ok(())
    }

    fn create_dock(&mut self, qh: &QueueHandle<Self>, output: &wl_output::WlOutput) -> Result<()> {
        let surface = self.compositor_state.create_surface(qh);
        let layer = self.layer_shell.create_layer_surface(
            qh,
            surface,
            Layer::Top,
            Some("dioxus-shell-dock"),
            Some(output),
        );
        // Bottom-anchored, no exclusive zone — overlay style. We anchor only
        // bottom (no left/right) so the dock sizes itself horizontally to its
        // content; the compositor will pick the size we requested.
        layer.set_anchor(smithay_client_toolkit::shell::wlr_layer::Anchor::BOTTOM);
        // Width 0 means "let the compositor choose" only when paired with
        // left+right anchors; otherwise it means we need to specify. Pick a
        // generous width for now (Phase A static row); Phase C will resize
        // to fit.
        layer.set_size(800, DOCK_HEIGHT);
        layer.set_exclusive_zone(0);
        layer.set_margin(0, 0, 12, 0);
        layer.commit();

        let dock = DockSurface::new(layer, self.toplevel_rx.clone());
        self.docks.push(dock);
        Ok(())
    }

    /// Called every TICK_INTERVAL. Drives Dioxus, renders surfaces whose state changed.
    fn tick(&mut self) {
        let qh = self.qh.clone();
        for bar in &mut self.bars {
            bar.tick(&qh);
        }
        for dock in &mut self.docks {
            dock.tick(&qh);
        }
    }

    /// Build the public snapshot Vec from the pending-handle map and broadcast
    /// it through the watch channel. Called from foreign_toplevel `done` and
    /// `closed` events.
    pub fn publish_toplevels(&mut self) {
        let list: Vec<Toplevel> = self
            .toplevels
            .values()
            .filter(|p| !p.closed)
            .map(|p| Toplevel {
                app_id: p.app_id.clone().unwrap_or_default(),
                title: p.title.clone().unwrap_or_default(),
                activated: p.activated.unwrap_or(false),
                minimized: p.minimized.unwrap_or(false),
            })
            .collect();
        // Skip notify if the snapshot is identical to the last published one.
        // The protocol sends state events frequently (focus changes within
        // windows etc.) but the dock only cares when the visible Vec changes.
        let changed = self.toplevel_tx.send_if_modified(|current| {
            if *current == list {
                false
            } else {
                *current = list;
                true
            }
        });
        if changed {
            let snapshot = self.toplevel_tx.borrow();
            debug!(
                "toplevels published: {} app(s): {:?}",
                snapshot.len(),
                snapshot.iter().map(|t| &t.app_id).collect::<Vec<_>>()
            );
        }
    }
}

impl CompositorHandler for State {
    fn scale_factor_changed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _new_factor: i32,
    ) {
    }

    fn transform_changed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _new_transform: wl_output::Transform,
    ) {
    }

    fn frame(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _time: u32,
    ) {
        // We don't drive renders from frame callbacks anymore — the calloop
        // timer is the redraw heartbeat. Frame callbacks are still requested
        // implicitly by wgpu's swapchain (Fifo present mode), and the protocol
        // dispatches them harmlessly.
    }

    fn surface_enter(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _output: &wl_output::WlOutput,
    ) {
    }

    fn surface_leave(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _output: &wl_output::WlOutput,
    ) {
    }
}

impl OutputHandler for State {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.output_state
    }

    fn new_output(
        &mut self,
        _conn: &Connection,
        qh: &QueueHandle<Self>,
        output: wl_output::WlOutput,
    ) {
        debug!("new output");
        if let Err(e) = self.create_bar(qh, &output) {
            warn!("failed to create bar for new output: {e:#}");
        }
        if let Err(e) = self.create_dock(qh, &output) {
            warn!("failed to create dock for new output: {e:#}");
        }
    }

    fn update_output(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _output: wl_output::WlOutput,
    ) {
    }

    fn output_destroyed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        output: wl_output::WlOutput,
    ) {
        self.bars.retain(|b| b.output().as_ref() != Some(&output));
    }
}

impl LayerShellHandler for State {
    fn closed(&mut self, _conn: &Connection, _qh: &QueueHandle<Self>, layer: &LayerSurface) {
        self.bars.retain(|b| b.surface() != layer);
        self.docks.retain(|d| d.surface() != layer);
        if self.bars.is_empty() && self.docks.is_empty() {
            self.running = false;
        }
    }

    fn configure(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        layer: &LayerSurface,
        configure: LayerSurfaceConfigure,
        _serial: u32,
    ) {
        let (w, h) = configure.new_size;
        for bar in &mut self.bars {
            if bar.surface() == layer {
                let width = if w == 0 { 1920 } else { w };
                let height = if h == 0 { BAR_HEIGHT } else { h };
                if let Err(e) = bar.configure(width, height) {
                    warn!("bar configure failed: {e:#}");
                }
                return;
            }
        }
        for dock in &mut self.docks {
            if dock.surface() == layer {
                let width = if w == 0 { 800 } else { w };
                let height = if h == 0 { DOCK_HEIGHT } else { h };
                if let Err(e) = dock.configure(width, height) {
                    warn!("dock configure failed: {e:#}");
                }
                return;
            }
        }
    }
}

impl ProvidesRegistryState for State {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    registry_handlers![OutputState];
}

delegate_compositor!(State);
delegate_output!(State);
delegate_layer!(State);
delegate_registry!(State);
