use anyhow::{Context, Result};
use calloop::{EventLoop, LoopHandle, timer::{TimeoutAction, Timer}};
use calloop_wayland_source::WaylandSource;
use log::{debug, info, warn};
use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState},
    delegate_compositor, delegate_layer, delegate_output, delegate_pointer, delegate_registry,
    delegate_seat,
    output::{OutputHandler, OutputState},
    reexports::client::{
        globals::registry_queue_init, protocol::wl_output, protocol::wl_pointer,
        protocol::wl_seat, protocol::wl_surface, Connection, QueueHandle,
    },
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    seat::{
        pointer::{PointerEvent, PointerEventKind, PointerHandler},
        Capability, SeatHandler, SeatState,
    },
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
use crate::config::{self, Config};

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
    seat_state: SeatState,
    pub bars: Vec<BarSurface>,
    pub docks: Vec<DockSurface>,
    pub running: bool,
    pub qh: QueueHandle<State>,
    /// Pointers we've created. Held to keep them alive.
    _pointers: Vec<wl_pointer::WlPointer>,
    /// Most recently bound seat. Used as the activation seat for
    /// foreign_toplevel `activate` requests.
    pub seat: Option<wl_seat::WlSeat>,
    /// Per-app round-robin index for cycling through windows of an app
    /// when its dock tile is clicked multiple times.
    cycle_index: HashMap<String, usize>,
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
    /// Receiver for the user's `dock.toml` config (pinned apps etc.).
    /// The watcher thread holds the sending half; we clone this receiver
    /// into the dock UI's Dioxus context.
    config_rx: watch::Receiver<Config>,
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

        // Spin up the config watcher (best-effort — falls back to defaults
        // if the path can't be determined or the watcher can't start).
        let config_rx = match Config::default_path() {
            Some(p) => {
                info!("config path: {}", p.display());
                match config::watch_config(p) {
                    Ok(rx) => rx,
                    Err(e) => {
                        warn!("config watcher failed: {e:#}; using defaults");
                        let (tx, rx) = watch::channel(Config::default());
                        drop(tx);
                        rx
                    }
                }
            }
            None => {
                warn!(
                    "no config path: neither $XDG_CONFIG_HOME nor $HOME set; \
                     dock will use defaults (no pinned apps)"
                );
                let (tx, rx) = watch::channel(Config::default());
                drop(tx);
                rx
            }
        };

        let state = State {
            registry_state: RegistryState::new(&globals),
            output_state: OutputState::new(&globals, &qh),
            compositor_state,
            layer_shell,
            seat_state: SeatState::new(&globals, &qh),
            bars: Vec::new(),
            docks: Vec::new(),
            running: true,
            qh,
            _pointers: Vec::new(),
            seat: None,
            cycle_index: HashMap::new(),
            _toplevel_manager: toplevel_manager,
            toplevels: HashMap::new(),
            toplevel_tx,
            toplevel_rx,
            config_rx,
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
        layer.set_anchor(smithay_client_toolkit::shell::wlr_layer::Anchor::BOTTOM);
        layer.set_size(800, DOCK_HEIGHT);
        layer.set_exclusive_zone(0);
        layer.set_margin(0, 0, 12, 0);
        // Default to None — we don't want the dock to steal keyboard focus
        // from regular toplevels just because the cursor is hovering it.
        // Pointer events (motion + click) are delivered regardless of
        // keyboard interactivity per the wlr-layer-shell spec.
        layer.set_keyboard_interactivity(
            smithay_client_toolkit::shell::wlr_layer::KeyboardInteractivity::None,
        );
        layer.commit();

        let dock = DockSurface::new(
            layer,
            self.toplevel_rx.clone(),
            self.config_rx.clone(),
        );
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

    /// Try to focus a running window matching `app_id`. Cycles through
    /// multiple windows of the same app on repeated clicks. Returns true
    /// if a matching handle was found and an `activate` request was sent.
    pub fn focus_existing(&mut self, app_id: &str) -> bool {
        let Some(seat) = self.seat.clone() else {
            return false;
        };
        // Collect all open handles for this app_id in a stable order.
        // HashMap iteration is unstable, so we sort by the handle's protocol
        // ID to get a deterministic per-app ordering.
        let mut matches: Vec<(_, _)> = self
            .toplevels
            .iter()
            .filter(|(_, p)| !p.closed && p.app_id.as_deref() == Some(app_id))
            .map(|(h, p)| (h.clone(), p.clone()))
            .collect();
        if matches.is_empty() {
            return false;
        }
        matches.sort_by_key(|(h, _)| {
            use wayland_client::Proxy;
            h.id().protocol_id()
        });

        // Pick which window to focus. If the currently activated window is
        // one of the matches, advance to the next; otherwise pick the
        // first one that isn't already activated (so the click does
        // something visible) — fall back to round-robin from the stored
        // index if all are non-activated.
        let activated_idx = matches.iter().position(|(_, p)| p.activated.unwrap_or(false));
        let target_idx = if let Some(i) = activated_idx {
            // Already on one of this app's windows — advance.
            (i + 1) % matches.len()
        } else {
            // Resume where we left off (or start at 0).
            let stored = self.cycle_index.get(app_id).copied().unwrap_or(0);
            stored % matches.len()
        };
        self.cycle_index
            .insert(app_id.to_string(), (target_idx + 1) % matches.len());

        let (handle, pending) = &matches[target_idx];
        if pending.minimized.unwrap_or(false) {
            handle.unset_minimized();
        }
        handle.activate(&seat);
        log::info!(
            "focus_existing {app_id}: window {}/{}",
            target_idx + 1,
            matches.len()
        );
        true
    }

    /// Toggle whether `app_id` is pinned in `dock.toml`. Loads the current
    /// config, mutates pinned, and writes atomically. The notify watcher
    /// then picks up the change and broadcasts the new config to dock UIs.
    pub fn toggle_pinned(&self, app_id: &str) {
        let Some(path) = Config::default_path() else {
            warn!("toggle_pinned: no config path resolvable");
            return;
        };
        let mut cfg = match Config::load_from(&path) {
            Ok(c) => c,
            Err(e) => {
                warn!("toggle_pinned: load failed ({e:#}); aborting");
                return;
            }
        };
        cfg.toggle_pinned(app_id);
        match cfg.save_to(&path) {
            Ok(()) => log::info!("toggled pin for {app_id} (now: {:?})", cfg.pinned),
            Err(e) => warn!("toggle_pinned: save failed: {e:#}"),
        }
    }

    /// Drop cycle_index entries for app_ids that no longer have running
    /// windows. Keeps the map from growing unboundedly.
    fn prune_cycle_index(&mut self) {
        use std::collections::HashSet;
        let live_app_ids: HashSet<String> = self
            .toplevels
            .values()
            .filter(|p| !p.closed)
            .filter_map(|p| p.app_id.clone())
            .collect();
        self.cycle_index.retain(|k, _| live_app_ids.contains(k));
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
            self.prune_cycle_index();
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
        info!("new output detected; creating bar + dock surfaces");
        if let Err(e) = self.create_bar(qh, &output) {
            warn!("failed to create bar for new output: {e:#}");
        }
        if let Err(e) = self.create_dock(qh, &output) {
            warn!("failed to create dock for new output: {e:#}");
        }
        info!(
            "now have {} bar(s), {} dock(s)",
            self.bars.len(),
            self.docks.len()
        );
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
                let width = if w == 0 { 1920 } else { w };
                let height = if h == 0 { DOCK_HEIGHT } else { h };
                if let Err(e) = dock.configure(width, height) {
                    warn!("dock configure failed: {e:#}");
                }
                return;
            }
        }
        // unreachable for matched layers
    }
}

impl ProvidesRegistryState for State {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    registry_handlers![OutputState, SeatState];
}

impl SeatHandler for State {
    fn seat_state(&mut self) -> &mut SeatState {
        &mut self.seat_state
    }
    fn new_seat(&mut self, _conn: &Connection, _qh: &QueueHandle<Self>, seat: wl_seat::WlSeat) {
        self.seat = Some(seat);
    }
    fn new_capability(
        &mut self,
        _conn: &Connection,
        qh: &QueueHandle<Self>,
        seat: wl_seat::WlSeat,
        capability: Capability,
    ) {
        if self.seat.is_none() {
            self.seat = Some(seat.clone());
        }
        if capability == Capability::Pointer {
            match self.seat_state.get_pointer(qh, &seat) {
                Ok(p) => {
                    debug!("created pointer for seat");
                    self._pointers.push(p);
                }
                Err(e) => warn!("failed to create pointer: {e}"),
            }
        }
    }
    fn remove_capability(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _seat: wl_seat::WlSeat,
        _capability: Capability,
    ) {
    }
    fn remove_seat(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _seat: wl_seat::WlSeat,
    ) {
    }
}

impl PointerHandler for State {
    fn pointer_frame(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _pointer: &wl_pointer::WlPointer,
        events: &[PointerEvent],
    ) {
        for event in events {
            // Find which dock surface this pointer event landed on.
            let dock_idx = self
                .docks
                .iter()
                .position(|d| d.surface().wl_surface() == &event.surface);
            let on_dock = dock_idx.is_some();
            log::info!(
                "pointer event kind={:?} on_dock={on_dock} pos={:?}",
                event.kind,
                event.position
            );
            let Some(idx) = dock_idx else {
                continue;
            };
            match event.kind {
                PointerEventKind::Enter { .. } | PointerEventKind::Motion { .. } => {
                    self.docks[idx].on_pointer_motion(event.position.0, event.position.1);
                }
                PointerEventKind::Leave { .. } => {
                    self.docks[idx].on_pointer_leave();
                }
                PointerEventKind::Press { button, .. } => {
                    log::info!("pointer press button=0x{button:x} on dock");
                    let pos = event.position;
                    let app_id = self.docks[idx].hit_test_app_id(pos.0, pos.1);
                    let Some(app_id) = app_id else { continue };
                    match button {
                        // BTN_LEFT: focus existing or launch.
                        0x110 => {
                            if self.focus_existing(&app_id) {
                                log::info!("focused existing {app_id}");
                            } else {
                                log::info!(
                                    "no running instance of {app_id}; launching"
                                );
                                if let Err(e) = crate::ui::launch_app(&app_id) {
                                    warn!("launch_app({app_id}) failed: {e:#}");
                                }
                            }
                        }
                        // BTN_RIGHT: toggle pinned in dock.toml. A proper
                        // popup-menu UX needs an xdg_popup or second
                        // layer-shell surface (mango doesn't size the
                        // dock layer-shell surface the way we expected
                        // when we tried in-surface menu rendering). For
                        // now this is a fast, functional UX — right-click
                        // to add/remove from the dock.
                        0x111 => self.toggle_pinned(&app_id),
                        _ => {}
                    }
                }
                _ => {}
            }
        }
    }
}

delegate_compositor!(State);
delegate_output!(State);
delegate_layer!(State);
delegate_registry!(State);
delegate_seat!(State);
delegate_pointer!(State);
