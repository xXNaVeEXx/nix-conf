use crate::wayland::Toplevel;
use dioxus::prelude::*;
use tokio::sync::watch;

/// Display the active window's title. Falls back to the short form of the
/// app_id when the title is empty (some apps like wezterm don't set a title
/// at the shell prompt). Sourced from the foreign_toplevel watch channel —
/// no process spawning, just diff-and-set on each broadcast.
#[component]
pub fn WindowTitle() -> Element {
    let rx = use_context::<watch::Receiver<Vec<Toplevel>>>();
    let mut label = use_signal(|| pick_label(&rx.borrow()));

    use_future(move || {
        let mut rx = rx.clone();
        async move {
            while rx.changed().await.is_ok() {
                let new = pick_label(&rx.borrow());
                if *label.read() != new {
                    label.set(new);
                }
            }
        }
    });

    rsx!("{label}")
}

fn pick_label(toplevels: &[Toplevel]) -> String {
    let active = toplevels.iter().find(|t| t.activated);
    match active {
        Some(t) if !t.title.trim().is_empty() => t.title.clone(),
        Some(t) => short_app_id(&t.app_id),
        None => String::from("·"),
    }
}

fn short_app_id(app_id: &str) -> String {
    if app_id.is_empty() {
        return String::from("·");
    }
    app_id.rsplit('.').next().unwrap_or(app_id).to_string()
}
