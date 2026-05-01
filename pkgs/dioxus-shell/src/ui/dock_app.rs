//! Root component for the dock surface.

use crate::ui::icon_data_url;
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
                DockTile {
                    key: "{app.app_id}",
                    app_id: app.app_id.clone(),
                    title: app.title.clone(),
                    activated: app.activated,
                }
            }
        }
    }
}

#[component]
fn DockTile(app_id: String, title: String, activated: bool) -> Element {
    let icon_url = icon_url_for(&app_id);
    let label = if title.trim().is_empty() {
        short_app_id(&app_id)
    } else {
        title.clone()
    };
    let icon_url_str = icon_url.unwrap_or_default();
    let has_icon = !icon_url_str.is_empty();
    let fallback_letter = short_app_id(&app_id).chars().next().unwrap_or('?').to_string();
    rsx! {
        div {
            class: if activated { "tile activated" } else { "tile" },
            title: "{label}",
            div { class: "icon-wrap",
                if has_icon {
                    img { class: "icon", src: "{icon_url_str}", alt: "{app_id}" }
                }
                if !has_icon {
                    div { class: "icon-fallback", "{fallback_letter}" }
                }
            }
            div { class: "running-dot" }
        }
    }
}

fn icon_url_for(app_id: &str) -> Option<String> {
    icon_data_url(app_id)
}

fn short_app_id(app_id: &str) -> String {
    if app_id.is_empty() {
        return String::from("?");
    }
    app_id.rsplit('.').next().unwrap_or(app_id).to_string()
}

const STYLES: &str = "
html, body { margin: 0; padding: 0; height: 100%; }
body {
  background: rgba(18, 23, 31, 0.85);
  color: rgb(220, 220, 230);
  font-family: monospace;
  font-size: 11px;
  height: 100%;
}
.dock {
  display: flex;
  justify-content: center;
  align-items: flex-end;
  gap: 6px;
  height: 100%;
  padding: 6px 12px 4px 12px;
}
.tile {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  padding: 2px;
  /* border-radius removed: triggers NaN in vello_common::flatten */
}
.tile.activated {
  background: rgba(80, 130, 200, 0.25);
}
.icon-wrap {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.icon {
  width: 40px;
  height: 40px;
}
.icon-fallback {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgb(40, 50, 65);
  border: 1px solid rgb(60, 75, 95);
  color: rgb(200, 210, 230);
  font-size: 18px;
  text-transform: uppercase;
}
.running-dot {
  width: 4px;
  height: 4px;
  background: rgb(140, 200, 255);
}
";
