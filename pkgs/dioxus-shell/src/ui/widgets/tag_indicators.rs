use dioxus::prelude::*;
use std::time::Duration;
use tokio::process::Command;
use tokio::time::{interval, MissedTickBehavior};

const POLL_INTERVAL: Duration = Duration::from_millis(500);
const TAG_COUNT: u8 = 5;

#[component]
pub fn TagIndicators() -> Element {
    let mut active = use_signal(|| 1u8);

    use_future(move || async move {
        let mut interval = interval(POLL_INTERVAL);
        interval.set_missed_tick_behavior(MissedTickBehavior::Skip);
        loop {
            interval.tick().await;
            if let Some(tag) = fetch_active_tag().await {
                if *active.read() != tag {
                    active.set(tag);
                }
            }
        }
    });

    rsx! {
        div { class: "tag-indicators",
            for i in 1..=TAG_COUNT {
                {
                    let class = if i == active() { "tag-dot active" } else { "tag-dot" };
                    rsx!(div { class: "{class}", key: "{i}" })
                }
            }
        }
    }
}

async fn fetch_active_tag() -> Option<u8> {
    let output = Command::new("mangoctl")
        .arg("get-active-tag")
        .output()
        .await
        .ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8_lossy(&output.stdout)
        .trim()
        .parse::<u8>()
        .ok()
}
