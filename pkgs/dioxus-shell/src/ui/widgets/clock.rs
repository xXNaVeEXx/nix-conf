use chrono::Local;
use dioxus::prelude::*;
use std::time::Duration;
use tokio::time::{interval, MissedTickBehavior};

#[component]
pub fn Clock() -> Element {
    let mut clock = use_signal(current_time_string);

    use_future(move || async move {
        let mut interval = interval(Duration::from_secs(1));
        interval.set_missed_tick_behavior(MissedTickBehavior::Delay);
        // First tick fires immediately; skip — the signal already has it.
        interval.tick().await;
        loop {
            interval.tick().await;
            clock.set(current_time_string());
        }
    });

    rsx!("{clock}")
}

fn current_time_string() -> String {
    Local::now().format("%H:%M:%S").to_string()
}
