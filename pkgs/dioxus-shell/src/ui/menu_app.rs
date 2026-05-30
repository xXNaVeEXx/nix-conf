//! Root component for the right-click context menu popup.

use dioxus::prelude::*;

/// Context passed to the menu via Dioxus context. Captured at popup
/// creation; doesn't change during the menu's lifetime.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MenuContext {
    pub app_id: String,
    pub pinned: bool,
    pub running: bool,
}

#[component]
pub fn MenuApp() -> Element {
    let ctx = use_context::<MenuContext>();
    let pin_label = if ctx.pinned {
        "Unpin from dock"
    } else {
        "Pin to dock"
    };
    let pin_action = format!("toggle-pin:{}", ctx.app_id);
    let close_action = format!("close-all:{}", ctx.app_id);

    rsx! {
        style { {STYLES} }
        div { class: "menu",
            div {
                class: "item",
                "data-menu-action": "{pin_action}",
                "{pin_label}"
            }
            if ctx.running {
                div {
                    class: "item danger",
                    "data-menu-action": "{close_action}",
                    "Close all windows"
                }
            }
        }
    }
}

const STYLES: &str = "
html, body { margin: 0; padding: 0; height: 100%; }
body {
  background: rgb(28, 36, 48);
  color: rgb(220, 230, 240);
  font-family: monospace;
  font-size: 12px;
  height: 100%;
}
.menu {
  display: flex;
  flex-direction: column;
  height: 100%;
}
.item {
  padding: 8px 14px;
  cursor: pointer;
}
.item.danger {
  color: rgb(230, 130, 130);
}
";
