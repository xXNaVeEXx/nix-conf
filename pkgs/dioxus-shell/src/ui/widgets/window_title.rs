use dioxus::prelude::*;
use std::time::Duration;
use tokio::process::Command;
use tokio::time::{interval, MissedTickBehavior};

const POLL_INTERVAL: Duration = Duration::from_millis(500);

#[component]
pub fn WindowTitle() -> Element {
    let mut title = use_signal(|| String::from("·"));

    use_future(move || async move {
        let mut interval = interval(POLL_INTERVAL);
        interval.set_missed_tick_behavior(MissedTickBehavior::Skip);
        loop {
            interval.tick().await;
            let new = fetch_active_title().await.unwrap_or_else(|| String::from("·"));
            if title.read().as_str() != new.as_str() {
                title.set(new);
            }
        }
    });

    rsx!("{title}")
}

/// Run `mangoctl get-active-window-title`. Returns None if the command can't
/// be spawned (mangoctl missing, not running under MangoWC, etc.) or if it
/// fails — the caller treats that as "no active window."
async fn fetch_active_title() -> Option<String> {
    let output = Command::new("mangoctl")
        .arg("get-active-window-title")
        .output()
        .await
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let raw = String::from_utf8_lossy(&output.stdout);
    let trimmed = raw.trim();
    if trimmed.is_empty() || trimmed == "Desktop" {
        None
    } else {
        Some(trimmed.to_string())
    }
}
