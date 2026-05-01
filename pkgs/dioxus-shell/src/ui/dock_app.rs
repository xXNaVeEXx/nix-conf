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
    // Group windows by app_id: one tile per app, count badge for multi-window.
    let groups = group_by_app_id(&apps_read);
    rsx! {
        style { {STYLES} }
        div { class: "dock",
            for group in groups.iter() {
                DockTile {
                    key: "{group.app_id}",
                    app_id: group.app_id.clone(),
                    title: group.representative_title.clone(),
                    activated: group.any_activated,
                    count: group.count,
                }
            }
        }
    }
}

#[derive(Clone)]
struct AppGroup {
    app_id: String,
    count: usize,
    any_activated: bool,
    representative_title: String,
}

fn group_by_app_id(toplevels: &[Toplevel]) -> Vec<AppGroup> {
    use std::collections::BTreeMap;
    let mut map: BTreeMap<String, AppGroup> = BTreeMap::new();
    for t in toplevels {
        let entry = map.entry(t.app_id.clone()).or_insert_with(|| AppGroup {
            app_id: t.app_id.clone(),
            count: 0,
            any_activated: false,
            representative_title: String::new(),
        });
        entry.count += 1;
        if t.activated {
            entry.any_activated = true;
            // Activated window's title is the most informative.
            entry.representative_title = t.title.clone();
        } else if entry.representative_title.is_empty() {
            entry.representative_title = t.title.clone();
        }
    }
    map.into_values().collect()
}

#[component]
fn DockTile(app_id: String, title: String, activated: bool, count: usize) -> Element {
    let icon_url = icon_url_for(&app_id);
    let label = if title.trim().is_empty() {
        short_app_id(&app_id)
    } else {
        title.clone()
    };
    let icon_url_str = icon_url.unwrap_or_default();
    let has_icon = !icon_url_str.is_empty();
    let fallback_letter = short_app_id(&app_id).chars().next().unwrap_or('?').to_string();
    let count_str = count.to_string();
    rsx! {
        div {
            class: if activated { "tile activated" } else { "tile" },
            title: "{label}",
            "data-app-id": "{app_id}",
            div { class: "icon-wrap",
                if has_icon {
                    img { class: "icon", src: "{icon_url_str}", alt: "{app_id}" }
                }
                if !has_icon {
                    div { class: "icon-fallback", "{fallback_letter}" }
                }
                if count > 1 {
                    div { class: "count-badge", "{count_str}" }
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
  position: relative;
}
.icon {
  width: 40px;
  height: 40px;
}
.count-badge {
  position: absolute;
  top: -2px;
  right: -2px;
  background: rgb(80, 160, 255);
  color: rgb(20, 28, 40);
  font-size: 10px;
  font-weight: bold;
  min-width: 16px;
  height: 16px;
  padding: 0 4px;
  display: flex;
  align-items: center;
  justify-content: center;
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
