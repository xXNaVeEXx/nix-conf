//! Root component for the dock surface. Renders one tile per running app
//! plus (Phase B) per pinned app. For Phase A this is a plain text row.

use crate::wayland::Toplevel;
use dioxus::prelude::*;
use tokio::sync::watch;

#[component]
pub fn DockApp() -> Element {
    let rx = use_context::<watch::Receiver<Vec<Toplevel>>>();
    let mut apps = use_signal(|| rx.borrow().clone());

    use_future(move || {
        let mut rx = rx.clone();
        async move {
            // Initial value is already in the signal; await subsequent changes.
            while rx.changed().await.is_ok() {
                let new = rx.borrow().clone();
                if *apps.read() != new {
                    apps.set(new);
                }
            }
        }
    });

    let apps_read = apps.read();
    rsx! {
        style { {STYLES} }
        div { class: "dock",
            for app in apps_read.iter() {
                div {
                    key: "{app.app_id}",
                    class: if app.activated { "tile activated" } else { "tile" },
                    div { class: "label", "{display_name(&app.app_id)}" }
                    div { class: "running-dot" }
                }
            }
        }
    }
}

/// Strip reverse-DNS prefixes for a cleaner label until icons land.
/// "org.gnome.Nautilus" -> "Nautilus"; "brave-browser" -> "brave-browser".
fn display_name(app_id: &str) -> String {
    app_id
        .rsplit('.')
        .next()
        .unwrap_or(app_id)
        .to_string()
}

const STYLES: &str = "
html, body { margin: 0; padding: 0; height: 100%; }
body {
  background: rgba(18, 23, 31, 0.85);
  color: rgb(220, 220, 230);
  font-family: monospace;
  font-size: 13px;
  height: 100%;
}
.dock {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 12px;
  height: 100%;
  padding: 0 16px;
}
.tile {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 3px;
  padding: 4px 10px;
  border-radius: 8px;
  background: rgb(30, 38, 50);
  border: 1px solid rgb(50, 60, 75);
  color: rgb(210, 220, 235);
}
.tile.activated {
  background: rgb(50, 80, 130);
  border: 1px solid rgb(120, 170, 230);
}
.tile .label {
  white-space: nowrap;
}
.tile .running-dot {
  width: 4px;
  height: 4px;
  border-radius: 2px;
  background: rgb(140, 200, 255);
}
";
