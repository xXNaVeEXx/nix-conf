use anyrender_vello::VelloScenePainter;
use anyrender_vello_cpu::VelloCpuScenePainter;
use blitz_dom::{Document, DocumentConfig};
use blitz_traits::shell::{ColorScheme, Viewport};
use dioxus::prelude::*;
use dioxus_native_dom::DioxusDocument;
use std::any::Any;
use std::sync::Arc;
use std::task::{Context, Wake, Waker};
use tokio::runtime::Runtime;
use vello::Scene;
use vello_cpu::{Pixmap, RenderContext};

mod dock_app;
mod icons;
mod net_provider;
mod widgets;

pub use dock_app::DockApp;
pub use icons::data_url as icon_data_url;

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
        self.0.swap(false, std::sync::atomic::Ordering::AcqRel)
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
    /// Convenience constructor for the bar. Takes the toplevel-watch receiver
    /// so the WindowTitle widget can subscribe.
    pub fn new_bar(
        width: u32,
        height: u32,
        toplevel_rx: tokio::sync::watch::Receiver<Vec<crate::wayland::Toplevel>>,
    ) -> Self {
        Self::new(
            width,
            height,
            App,
            vec![Box::new(toplevel_rx) as Box<dyn Any>],
        )
    }

    /// General constructor: build a Ui rooted at `root`, with `contexts` made
    /// available to descendant components via `use_context::<T>()`.
    pub fn new(
        width: u32,
        height: u32,
        root: fn() -> Element,
        contexts: Vec<Box<dyn Any>>,
    ) -> Self {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_time()
            .enable_io()
            .build()
            .expect("build tokio runtime");

        // Enter the runtime while constructing the VirtualDom so use_future
        // hooks find a runtime to spawn into.
        let _guard = runtime.enter();

        let mut vdom = VirtualDom::new(root);
        for ctx in contexts {
            vdom.insert_any_root_context(ctx);
        }
        let mut doc = DioxusDocument::new(
            vdom,
            DocumentConfig {
                viewport: Some(Viewport::new(width, height, 1.0, ColorScheme::Dark)),
                net_provider: Some(net_provider::LocalFileProvider::arc()),
                ..Default::default()
            },
        );
        doc.initial_build();
        // initial_build creates the DOM and triggers any synchronous resource
        // fetches (our LocalFileProvider serves data URLs inline). Drain the
        // resulting ResourceLoad events so special_data is populated before
        // the first paint.
        doc.inner.borrow_mut().handle_messages();

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

    /// Poll Dioxus + drive the tokio runtime. Returns true if the document
    /// changed (caller should re-paint).
    pub fn poll(&mut self) -> bool {
        let _guard = self.runtime.enter();

        // Spin the runtime briefly so `use_future` futures get a chance to
        // wake their wakers (e.g. `tokio::time::interval` ticks). We do not
        // block — block_on of yield_now polls once and returns.
        self.runtime
            .block_on(async { tokio::task::yield_now().await });

        let cx = Context::from_waker(&self.waker);
        // `TaskContext` in blitz-dom is just an alias for std::task::Context.
        let dioxus_changed = self.doc.poll(Some(cx));

        // Drain Blitz's internal resource-load events (bytes from net_provider
        // arrive here as DocumentEvent::ResourceLoad). Without this, fetched
        // images never make it into the rendered scene.
        self.doc.inner.borrow_mut().handle_messages();

        dioxus_changed
    }

    /// GPU rendering path: emit Blitz paint into a vello::Scene that the
    /// caller will hand to vello::Renderer::render_to_texture.
    pub fn paint(&mut self, scene: &mut Scene, now_secs: f64) {
        let mut inner = self.doc.inner.borrow_mut();
        inner.resolve(now_secs);
        let mut painter = VelloScenePainter::new(scene);
        blitz_paint::paint_scene(&mut painter, &inner, 1.0, self.width, self.height, 0, 0);
    }

    /// CPU rendering path: rasterize to a Pixmap (RGBA bytes) on the CPU.
    /// Caller uploads the pixels to a texture. Used on llvmpipe / no-GPU
    /// environments where Vello's GPU compute pipeline is unreliable.
    pub fn paint_cpu(&mut self, now_secs: f64) -> Pixmap {
        let mut inner = self.doc.inner.borrow_mut();
        inner.resolve(now_secs);
        let mut painter = VelloCpuScenePainter(RenderContext::new(
            self.width as u16,
            self.height as u16,
        ));
        blitz_paint::paint_scene(&mut painter, &inner, 1.0, self.width, self.height, 0, 0);
        // Flush the render context into an RGBA pixmap.
        let mut pixmap = Pixmap::new(self.width as u16, self.height as u16);
        painter.0.render_to_pixmap(&mut pixmap);
        pixmap
    }
}

#[component]
fn App() -> Element {
    rsx! {
        style { {STYLES} }
        div { class: "bar",
            div { class: "left",
                widgets::TagIndicators {}
                div { class: "title",
                    widgets::WindowTitle {}
                }
            }
            div { class: "right",
                widgets::Wlan {}
                widgets::SystemInfo {}
                widgets::Clock {}
            }
        }
    }
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
  gap: 16px;
}
.left {
  flex: 1 1 auto;
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 12px;
  color: rgb(200, 210, 230);
}
.title {
  flex: 1 1 auto;
  min-width: 0;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.right {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  gap: 14px;
  color: rgb(220, 220, 230);
}
.sysinfo {
  display: flex;
  gap: 10px;
  align-items: center;
  font-variant-numeric: tabular-nums;
  color: rgb(180, 200, 220);
}
.metric { display: inline-flex; gap: 4px; }
.metric .label { color: rgb(120, 140, 170); }
.metric .value { color: rgb(220, 230, 245); }
.wlan { color: rgb(180, 200, 220); }
.wlan.strong { color: rgb(140, 230, 170); }
.wlan.medium { color: rgb(200, 220, 130); }
.wlan.weak { color: rgb(230, 180, 120); }
.wlan.poor { color: rgb(230, 130, 130); }
.wlan.offline { color: rgb(120, 120, 130); }
.tag-indicators {
  display: flex;
  gap: 8px;
  align-items: center;
  flex: 0 0 auto;
}
.tag-dot {
  width: 10px;
  height: 10px;
  border-radius: 5px;
  background: rgb(50, 60, 75);
  border: 1px solid rgb(70, 85, 105);
}
.tag-dot.active {
  background: rgb(80, 160, 255);
  border: 2px solid rgb(160, 200, 255);
}
";
