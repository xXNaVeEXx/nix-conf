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
use std::time::Duration;

use super::surface::BarSurface;

const BAR_HEIGHT: u32 = 32;

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
    pub running: bool,
    pub qh: QueueHandle<State>,
}

impl Shell {
    pub fn new() -> Result<Self> {
        let conn = Connection::connect_to_env().context("connect to wayland display")?;
        let (globals, event_queue) = registry_queue_init(&conn).context("init registry")?;
        let qh = event_queue.handle();

        let compositor_state =
            CompositorState::bind(&globals, &qh).context("bind wl_compositor")?;
        let layer_shell = LayerShell::bind(&globals, &qh).context("bind zwlr_layer_shell_v1")?;

        let event_loop: EventLoop<'static, State> =
            EventLoop::try_new().context("calloop event loop")?;

        WaylandSource::new(conn, event_queue)
            .insert(event_loop.handle())
            .map_err(|e| anyhow::anyhow!("insert wayland source: {e}"))?;

        let state = State {
            registry_state: RegistryState::new(&globals),
            output_state: OutputState::new(&globals, &qh),
            compositor_state,
            layer_shell,
            bars: Vec::new(),
            running: true,
            qh,
        };

        Ok(Self { event_loop, state })
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
        info!("running with {} bar surface(s)", self.state.bars.len());

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

        let bar = BarSurface::new(layer);
        self.bars.push(bar);
        Ok(())
    }

    /// Called every TICK_INTERVAL. Drives Dioxus, renders bars whose state changed.
    fn tick(&mut self) {
        let qh = self.qh.clone();
        for bar in &mut self.bars {
            bar.tick(&qh);
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
        if self.bars.is_empty() {
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
        let width = if w == 0 { 1920 } else { w };
        let height = if h == 0 { BAR_HEIGHT } else { h };
        for bar in &mut self.bars {
            if bar.surface() == layer {
                if let Err(e) = bar.configure(width, height) {
                    warn!("bar configure failed: {e:#}");
                }
                break;
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
