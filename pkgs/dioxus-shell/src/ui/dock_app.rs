//! Root component for the dock surface.

use crate::config::Config;
use crate::ui::icon_data_url;
use crate::wayland::Toplevel;
use dioxus::prelude::*;
use tokio::sync::watch;

#[component]
pub fn DockApp() -> Element {
    let toplevels_rx = use_context::<watch::Receiver<Vec<Toplevel>>>();
    let config_rx = use_context::<watch::Receiver<Config>>();
    let mut apps = use_signal(|| toplevels_rx.borrow().clone());
    let mut config = use_signal(|| config_rx.borrow().clone());

    use_future(move || {
        let mut rx = toplevels_rx.clone();
        async move {
            while rx.changed().await.is_ok() {
                let new = rx.borrow().clone();
                if *apps.read() != new {
                    apps.set(new);
                }
            }
        }
    });
    use_future(move || {
        let mut rx = config_rx.clone();
        async move {
            while rx.changed().await.is_ok() {
                let new = rx.borrow().clone();
                if *config.read() != new {
                    config.set(new);
                }
            }
        }
    });

    let apps_read = apps.read();
    let config_read = config.read();
    let items = build_dock_items(&apps_read, &config_read);
    rsx! {
        style { {STYLES} }
        div { class: "dock",
            for item in items.iter() {
                DockTile {
                    key: "{item.app_id}",
                    app_id: item.app_id.clone(),
                    title: item.representative_title.clone(),
                    activated: item.any_activated,
                    count: item.count,
                    pinned: item.pinned,
                }
            }
        }
    }
}

#[derive(Clone)]
struct DockItem {
    app_id: String,
    /// Number of running windows of this app. 0 for pinned-but-not-running.
    count: usize,
    any_activated: bool,
    representative_title: String,
    /// True if this entry comes from `config.pinned`.
    pinned: bool,
}

/// Compose the dock's tile list from running windows + the user's pinned
/// list. Order:
///   1. Pinned apps (from config) in config order, regardless of running state.
///   2. Unpinned running apps appended in app_id order (stable for now;
///      future improvement: insertion order via Toplevel arrival).
fn build_dock_items(toplevels: &[Toplevel], config: &Config) -> Vec<DockItem> {
    use std::collections::BTreeMap;

    // Aggregate running windows by app_id.
    let mut running: BTreeMap<String, DockItem> = BTreeMap::new();
    for t in toplevels {
        let entry = running.entry(t.app_id.clone()).or_insert_with(|| DockItem {
            app_id: t.app_id.clone(),
            count: 0,
            any_activated: false,
            representative_title: String::new(),
            pinned: false,
        });
        entry.count += 1;
        if t.activated {
            entry.any_activated = true;
            entry.representative_title = t.title.clone();
        } else if entry.representative_title.is_empty() {
            entry.representative_title = t.title.clone();
        }
    }

    let mut items = Vec::with_capacity(config.pinned.len() + running.len());
    // Pinned apps first, in config order.
    for app_id in &config.pinned {
        if let Some(mut item) = running.remove(app_id) {
            item.pinned = true;
            items.push(item);
        } else {
            items.push(DockItem {
                app_id: app_id.clone(),
                count: 0,
                any_activated: false,
                representative_title: String::new(),
                pinned: true,
            });
        }
    }
    // Then any running apps that weren't in the pinned list.
    items.extend(running.into_values());
    items
}

#[component]
fn DockTile(
    app_id: String,
    title: String,
    activated: bool,
    count: usize,
    pinned: bool,
) -> Element {
    let _ = pinned;
    let running = count > 0;
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
            if running {
                div { class: "running-dot" }
            }
            if !running {
                div { class: "running-dot empty" }
            }
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
.running-dot.empty {
  /* Same footprint, invisible — keeps tile heights consistent. */
  background: transparent;
}
";
