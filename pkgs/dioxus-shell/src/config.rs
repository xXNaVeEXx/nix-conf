//! User configuration loaded from `~/.config/dioxus-shell/dock.toml`.
//!
//! Hot-reloaded via the `notify` crate: a watcher thread sends parsed
//! `Config` values through a `tokio::sync::watch` channel that the dock
//! UI subscribes to.
//!
//! Example config:
//! ```toml
//! pinned = [
//!   "org.wezfurlong.wezterm",
//!   "org.gnome.Nautilus",
//!   "brave-browser",
//! ]
//! ```

use anyhow::{Context, Result};
use notify::Watcher;
use serde::Deserialize;
use std::path::{Path, PathBuf};
use std::time::Duration;
use tokio::sync::watch;

#[derive(Debug, Default, Clone, PartialEq, Eq, Deserialize)]
#[serde(default)]
pub struct Config {
    /// App ids to pin to the dock, in display order. Pinned apps appear
    /// even when not running and remain in their configured slot when
    /// running.
    pub pinned: Vec<String>,
}

impl Config {
    /// Standard path: `$XDG_CONFIG_HOME/dioxus-shell/dock.toml` (defaulting
    /// to `~/.config/...`).
    pub fn default_path() -> Option<PathBuf> {
        let base = std::env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .or_else(|| {
                std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config"))
            })?;
        Some(base.join("dioxus-shell").join("dock.toml"))
    }

    /// Read + parse the config from `path`. Returns `Ok(default)` if the
    /// file doesn't exist; only returns Err on a parse failure or
    /// permission error so callers can distinguish "no config" from
    /// "broken config".
    pub fn load_from(path: &Path) -> Result<Self> {
        match std::fs::read_to_string(path) {
            Ok(s) => toml::from_str(&s)
                .with_context(|| format!("parse {}", path.display())),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(Self::default()),
            Err(e) => Err(e).with_context(|| format!("read {}", path.display())),
        }
    }
}

/// Spawn a notify watcher for `path` that sends each successfully-parsed
/// Config through the returned watch channel. Returns the receiver
/// (subscribers should clone it) and keeps the watcher alive in a
/// detached background thread.
///
/// The initial value sent through the channel is the result of an
/// immediate `Config::load_from` (so subscribers always see the current
/// config, even before any FS event).
pub fn watch_config(
    path: PathBuf,
) -> Result<watch::Receiver<Config>> {
    let initial = Config::load_from(&path).unwrap_or_else(|e| {
        log::warn!("failed to load {} ({e:#}); using defaults", path.display());
        Config::default()
    });
    log::info!("dock config: {} (pinned: {:?})", path.display(), initial.pinned);
    let (tx, rx) = watch::channel(initial);

    // The notify watcher needs a thread because it's blocking. We use a
    // mpsc channel to bridge notify's events into our thread.
    let (raw_tx, raw_rx) = std::sync::mpsc::channel::<notify::Result<notify::Event>>();

    // Watch the *parent directory*, not the file itself — many editors
    // atomic-write (write to temp + rename) which reduces the watched
    // path to non-existent and invalidates the watch. Watching the
    // parent dir + filtering events by filename is the standard fix.
    let parent = path
        .parent()
        .map(|p| p.to_path_buf())
        .unwrap_or_else(|| PathBuf::from("."));
    let target_filename = path
        .file_name()
        .map(|s| s.to_os_string())
        .unwrap_or_default();

    let mut watcher = notify::recommended_watcher(move |res| {
        let _ = raw_tx.send(res);
    })
    .context("create notify watcher")?;

    // Try to ensure the parent dir exists so we can watch it. Missing
    // dir is non-fatal — the user can create it later, but we won't
    // hot-reload until then.
    let _ = std::fs::create_dir_all(&parent);
    if let Err(e) = watcher.watch(&parent, notify::RecursiveMode::NonRecursive) {
        log::warn!("notify watch {} failed: {e}", parent.display());
    }

    let watch_path = path.clone();
    std::thread::Builder::new()
        .name("dioxus-shell-config-watcher".into())
        .spawn(move || {
            // Keep the watcher alive for the thread's lifetime.
            let _watcher = watcher;
            // Debounce: many editors fire several Modify events per save.
            // Coalesce events arriving within DEBOUNCE_WINDOW into one reload.
            const DEBOUNCE_WINDOW: Duration = Duration::from_millis(150);
            let mut pending = false;
            loop {
                let recv_timeout = if pending {
                    DEBOUNCE_WINDOW
                } else {
                    Duration::from_secs(60 * 60)
                };
                match raw_rx.recv_timeout(recv_timeout) {
                    Ok(Ok(event)) => {
                        // Filter to events about our target file.
                        let interesting = event
                            .paths
                            .iter()
                            .any(|p| p.file_name() == Some(&target_filename));
                        if interesting {
                            pending = true;
                        }
                    }
                    Ok(Err(e)) => {
                        log::debug!("notify error: {e}");
                    }
                    Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {
                        if pending {
                            pending = false;
                            match Config::load_from(&watch_path) {
                                Ok(cfg) => {
                                    log::info!(
                                        "dock config reloaded: pinned={:?}",
                                        cfg.pinned
                                    );
                                    let _ = tx.send_if_modified(|current| {
                                        if *current == cfg {
                                            false
                                        } else {
                                            *current = cfg;
                                            true
                                        }
                                    });
                                }
                                Err(e) => {
                                    log::warn!(
                                        "config reload failed: {e:#}; keeping previous"
                                    );
                                }
                            }
                        }
                    }
                    Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => {
                        log::debug!("notify channel disconnected; watcher exiting");
                        break;
                    }
                }
            }
        })
        .context("spawn config watcher thread")?;

    Ok(rx)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn empty_pinned_by_default() {
        let cfg = Config::default();
        assert!(cfg.pinned.is_empty());
    }

    #[test]
    fn missing_file_returns_default() {
        let tmp = TempDir::new().unwrap();
        let path = tmp.path().join("nonexistent.toml");
        let cfg = Config::load_from(&path).unwrap();
        assert!(cfg.pinned.is_empty());
    }

    #[test]
    fn parses_valid_toml() {
        let tmp = TempDir::new().unwrap();
        let path = tmp.path().join("dock.toml");
        fs::write(
            &path,
            r#"
            pinned = ["firefox", "org.kde.konsole", "brave-browser"]
            "#,
        )
        .unwrap();
        let cfg = Config::load_from(&path).unwrap();
        assert_eq!(
            cfg.pinned,
            vec!["firefox", "org.kde.konsole", "brave-browser"]
        );
    }

    #[test]
    fn rejects_malformed_toml() {
        let tmp = TempDir::new().unwrap();
        let path = tmp.path().join("dock.toml");
        fs::write(&path, "pinned = not-a-list\n").unwrap();
        assert!(Config::load_from(&path).is_err());
    }

    #[test]
    fn ignores_unknown_fields() {
        // Forward-compat: extra fields don't break parsing.
        let tmp = TempDir::new().unwrap();
        let path = tmp.path().join("dock.toml");
        fs::write(
            &path,
            "pinned = [\"a\"]\nfuture_field = 42\n",
        )
        .unwrap();
        // serde(default) doesn't deny unknown by default.
        let cfg = Config::load_from(&path).unwrap();
        assert_eq!(cfg.pinned, vec!["a"]);
    }

    #[test]
    fn empty_file_is_default() {
        let tmp = TempDir::new().unwrap();
        let path = tmp.path().join("dock.toml");
        fs::write(&path, "").unwrap();
        let cfg = Config::load_from(&path).unwrap();
        assert!(cfg.pinned.is_empty());
    }
}
