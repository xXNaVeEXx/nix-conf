use anyrender_vello::VelloScenePainter;
use blitz_dom::{Document, DocumentConfig};
use blitz_traits::shell::{ColorScheme, Viewport};
use chrono::Local;
use dioxus::prelude::*;
use dioxus_native_dom::DioxusDocument;
use std::sync::Arc;
use std::task::{Context, Wake, Waker};
use tokio::runtime::Runtime;
use vello::Scene;

/// Holds the Dioxus VirtualDom + blitz-dom Document plus the tokio runtime
/// that drives async hooks (`use_future`, intervals, etc.). Single-threaded —
/// `DioxusDocument` contains `Rc<RefCell<...>>`.
pub struct Ui {
    runtime: Runtime,
    doc: DioxusDocument,
    waker: Waker,
    dirty: Arc<DirtyFlag>,
    width: u32,
    height: u32,
}

/// Cheap atomic flag that the waker flips. Checked at the top of each event-
/// loop tick; if set, we drive Dioxus and request a redraw.
pub struct DirtyFlag(std::sync::atomic::AtomicBool);

impl DirtyFlag {
    fn new() -> Self {
        // Start dirty so the first poll runs.
        Self(std::sync::atomic::AtomicBool::new(true))
    }

    pub fn take(&self) -> bool {
        self.0
            .swap(false, std::sync::atomic::Ordering::AcqRel)
    }

    fn set(&self) {
        self.0.store(true, std::sync::atomic::Ordering::Release);
    }
}

struct DirtyWaker(Arc<DirtyFlag>);

impl Wake for DirtyWaker {
    fn wake(self: Arc<Self>) {
        self.0.set();
    }
    fn wake_by_ref(self: &Arc<Self>) {
        self.0.set();
    }
}

impl Ui {
    pub fn new(width: u32, height: u32) -> Self {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_time()
            .build()
            .expect("build tokio runtime");

        // Enter the runtime while constructing the VirtualDom so use_future hooks
        // inside `app()` find a runtime to spawn into.
        let _guard = runtime.enter();

        let vdom = VirtualDom::new(app);
        let mut doc = DioxusDocument::new(
            vdom,
            DocumentConfig {
                viewport: Some(Viewport::new(width, height, 1.0, ColorScheme::Dark)),
                ..Default::default()
            },
        );
        doc.initial_build();

        let dirty = Arc::new(DirtyFlag::new());
        let waker = Waker::from(Arc::new(DirtyWaker(dirty.clone())));

        drop(_guard);

        Self {
            runtime,
            doc,
            waker,
            dirty,
            width,
            height,
        }
    }

    pub fn dirty_flag(&self) -> Arc<DirtyFlag> {
        self.dirty.clone()
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        if width == self.width && height == self.height {
            return;
        }
        self.width = width;
        self.height = height;
        let mut inner = self.doc.inner.borrow_mut();
        inner.set_viewport(Viewport::new(width, height, 1.0, ColorScheme::Dark));
        // Layout changed — force a redraw next tick.
        self.dirty.set();
    }

    /// Poll Dioxus + drive the tokio runtime. Call before painting whenever
    /// the dirty flag is set or a `wl_surface::frame` callback fires. Returns
    /// true if the document changed (should re-paint).
    pub fn poll(&mut self) -> bool {
        let _guard = self.runtime.enter();

        // Spin the runtime briefly so `use_future` futures get a chance to
        // wake their wakers (e.g. `tokio::time::interval` ticks). We do not
        // block — block_on of yield_now polls once and returns.
        self.runtime
            .block_on(async { tokio::task::yield_now().await });

        let mut cx = Context::from_waker(&self.waker);
        // DioxusDocument::poll returns true if it ran render_immediate and the
        // DOM may have mutations. False = vdom is idle.
        // `TaskContext` in blitz-dom is just an alias for std::task::Context.
        self.doc.poll(Some(cx))
    }

    pub fn paint(&mut self, scene: &mut Scene, now_secs: f64) {
        let mut inner = self.doc.inner.borrow_mut();
        inner.resolve(now_secs);
        let mut painter = VelloScenePainter::new(scene);
        blitz_paint::paint_scene(&mut painter, &inner, 1.0, self.width, self.height, 0, 0);
    }
}

fn app() -> Element {
    let clock = use_signal(current_time_string);

    // Tick the clock once per second using a tokio interval. The signal set
    // wakes the VirtualDom; our DirtyWaker flips the flag so the event loop
    // knows to redraw.
    use_future(move || {
        let mut clock = clock;
        async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(1));
            interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
            // First tick fires immediately; skip it (signal already initialized).
            interval.tick().await;
            loop {
                interval.tick().await;
                clock.set(current_time_string());
            }
        }
    });

    rsx! {
        style { {STYLES} }
        div { class: "bar",
            div { class: "left", "dioxus-shell" }
            div { class: "right", "{clock}" }
        }
    }
}

fn current_time_string() -> String {
    Local::now().format("%H:%M:%S").to_string()
}

const STYLES: &str = "
html, body { margin: 0; padding: 0; height: 100%; }
body {
  background: rgb(18, 23, 31);
  color: rgb(220, 220, 230);
  font-family: monospace;
  font-size: 14px;
  height: 100%;
}
.bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 12px;
  height: 100%;
}
.left { color: rgb(140, 160, 220); }
.right { color: rgb(220, 220, 230); }
";
