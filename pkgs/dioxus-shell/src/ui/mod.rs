use anyrender_vello::VelloScenePainter;
use blitz_dom::DocumentConfig;
use blitz_traits::shell::{ColorScheme, Viewport};
use chrono::Local;
use dioxus::prelude::*;
use dioxus_native_dom::DioxusDocument;
use vello::Scene;

pub struct Ui {
    doc: DioxusDocument,
    width: u32,
    height: u32,
}

impl Ui {
    pub fn new(width: u32, height: u32) -> Self {
        let vdom = VirtualDom::new(app);
        let mut doc = DioxusDocument::new(
            vdom,
            DocumentConfig {
                viewport: Some(Viewport::new(width, height, 1.0, ColorScheme::Dark)),
                ..Default::default()
            },
        );
        doc.initial_build();
        Self { doc, width, height }
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        if width == self.width && height == self.height {
            return;
        }
        self.width = width;
        self.height = height;
        let mut inner = self.doc.inner.borrow_mut();
        inner.set_viewport(Viewport::new(width, height, 1.0, ColorScheme::Dark));
    }

    /// Resolve layout + paint into the given vello scene. Call once per frame
    /// before handing the scene to vello::Renderer::render_to_texture.
    pub fn paint(&mut self, scene: &mut Scene, now_secs: f64) {
        let mut inner = self.doc.inner.borrow_mut();
        inner.resolve(now_secs);
        let mut painter = VelloScenePainter::new(scene);
        blitz_paint::paint_scene(&mut painter, &inner, 1.0, self.width, self.height, 0, 0);
    }
}

fn app() -> Element {
    let time = use_signal(|| current_time_string());

    rsx! {
        style { {STYLES} }
        div { class: "bar",
            div { class: "left", "dioxus-shell" }
            div { class: "right", "{time}" }
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
