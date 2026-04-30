use dioxus::prelude::*;
use std::time::Duration;
use tokio::process::Command;
use tokio::time::{interval, MissedTickBehavior};

const POLL_INTERVAL: Duration = Duration::from_secs(5);

#[derive(Clone, PartialEq)]
enum NetState {
    Lan(String),         // device name
    Wifi(String, u8),    // ssid, signal 0..=100
    Disconnected,
}

#[component]
pub fn Wlan() -> Element {
    let mut state = use_signal(|| NetState::Disconnected);

    use_future(move || async move {
        let mut interval = interval(POLL_INTERVAL);
        interval.set_missed_tick_behavior(MissedTickBehavior::Skip);
        loop {
            interval.tick().await;
            let new = fetch_state().await;
            if *state.read() != new {
                state.set(new);
            }
        }
    });

    let s = state.read();
    let (label, signal_class) = match &*s {
        NetState::Lan(dev) => (format!("lan {dev}"), "wlan strong"),
        NetState::Wifi(ssid, signal) => (
            format!("{ssid} {signal}%"),
            match signal {
                80..=100 => "wlan strong",
                60..=79 => "wlan medium",
                40..=59 => "wlan weak",
                _ => "wlan poor",
            },
        ),
        NetState::Disconnected => (String::from("offline"), "wlan offline"),
    };

    rsx! {
        span { class: "{signal_class}", "{label}" }
    }
}

async fn fetch_state() -> NetState {
    if let Some(lan) = fetch_lan_device().await {
        return NetState::Lan(lan);
    }
    if let Some((ssid, signal)) = fetch_active_wifi().await {
        return NetState::Wifi(ssid, signal);
    }
    NetState::Disconnected
}

/// Returns the first ethernet device that's `connected`, if any.
async fn fetch_lan_device() -> Option<String> {
    let output = Command::new("nmcli")
        .args(["-t", "-f", "DEVICE,TYPE,STATE", "dev"])
        .output()
        .await
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let raw = String::from_utf8_lossy(&output.stdout);
    for line in raw.lines() {
        let mut parts = line.split(':');
        let device = parts.next()?;
        let typ = parts.next()?;
        let state = parts.next()?;
        if typ == "ethernet" && state == "connected" {
            return Some(device.to_string());
        }
    }
    None
}

/// Returns (ssid, signal) of the active WiFi connection, if any.
async fn fetch_active_wifi() -> Option<(String, u8)> {
    let output = Command::new("nmcli")
        .args(["-t", "-f", "active,ssid,signal", "dev", "wifi"])
        .output()
        .await
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let raw = String::from_utf8_lossy(&output.stdout);
    for line in raw.lines() {
        let mut parts = line.split(':');
        let active = parts.next()?;
        let ssid = parts.next()?;
        let signal = parts.next()?;
        if active == "yes" {
            let signal = signal.parse().unwrap_or(0);
            return Some((ssid.to_string(), signal));
        }
    }
    None
}
