use dioxus::prelude::*;
use std::cell::RefCell;
use std::time::Duration;
use sysinfo::{CpuRefreshKind, MemoryRefreshKind, RefreshKind, System};
use tokio::time::{interval, MissedTickBehavior};

const POLL_INTERVAL: Duration = Duration::from_secs(2);

#[derive(Clone, PartialEq)]
struct Stats {
    cpu_pct: u8,
    mem_pct: u8,
}

#[component]
pub fn SystemInfo() -> Element {
    let mut stats = use_signal(|| Stats {
        cpu_pct: 0,
        mem_pct: 0,
    });

    use_future(move || async move {
        // sysinfo::System is heavy-ish to construct (parses /proc); build it
        // once per widget instance and reuse.
        let sys = RefCell::new(System::new_with_specifics(
            RefreshKind::new()
                .with_cpu(CpuRefreshKind::new().with_cpu_usage())
                .with_memory(MemoryRefreshKind::new().with_ram()),
        ));

        let mut interval = interval(POLL_INTERVAL);
        interval.set_missed_tick_behavior(MissedTickBehavior::Skip);
        // First tick fires immediately and gives bogus 0% CPU (sysinfo needs
        // two samples to compute usage). Skip it.
        interval.tick().await;
        loop {
            interval.tick().await;
            let new = read_stats(&sys);
            if *stats.read() != new {
                stats.set(new);
            }
        }
    });

    let s = stats.read();
    rsx! {
        div { class: "sysinfo",
            span { class: "metric",
                span { class: "label", "cpu" }
                span { class: "value", "{s.cpu_pct:>2}%" }
            }
            span { class: "metric",
                span { class: "label", "mem" }
                span { class: "value", "{s.mem_pct:>2}%" }
            }
        }
    }
}

fn read_stats(sys: &RefCell<System>) -> Stats {
    let mut s = sys.borrow_mut();
    s.refresh_cpu_usage();
    s.refresh_memory();

    let cpu_pct = s.global_cpu_usage().clamp(0.0, 100.0).round() as u8;
    let used = s.used_memory();
    let total = s.total_memory().max(1);
    let mem_pct = ((used as f64 / total as f64) * 100.0).clamp(0.0, 100.0).round() as u8;

    Stats { cpu_pct, mem_pct }
}
