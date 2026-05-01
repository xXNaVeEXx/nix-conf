use anyhow::Result;
use log::info;

mod config;
mod render;
mod ui;
mod wayland;

fn main() -> Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    info!("dioxus-shell starting");

    let mut shell = wayland::Shell::new()?;
    shell.run()
}
