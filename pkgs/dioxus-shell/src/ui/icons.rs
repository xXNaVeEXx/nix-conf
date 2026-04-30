//! App-icon resolution.
//!
//! Maps a Wayland `app_id` to a path to a PNG/SVG icon file via the XDG
//! desktop-entry + icon-theme specs.
//!
//! Resolution strategy (cheapest-first):
//!   1. Direct filename match: `${app_id}.desktop` in the search path.
//!   2. Scan desktop files for matching `StartupWMClass` (case-insensitive).
//!   3. Filename stem prefix match (last resort).
//!
//! Once a desktop file is found, read its `Icon=` and resolve through the
//! XDG icon theme spec. Results are cached in-process — `app_id` is stable
//! while the app is running, so a per-shell-lifetime cache is fine.

use base64::Engine;
use freedesktop_entry_parser::parse_entry;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;

/// Search path for `.desktop` files, in priority order. Computed once and
/// cached. NixOS-flavored: per-user profile + system profile + flatpak.
fn applications_dirs() -> &'static [PathBuf] {
    static DIRS: OnceLock<Vec<PathBuf>> = OnceLock::new();
    DIRS.get_or_init(|| {
        let mut out = Vec::new();
        // $XDG_DATA_HOME/applications, defaulting to ~/.local/share
        if let Some(home) = dirs_home() {
            out.push(home.join(".local/share/applications"));
            out.push(home.join(".nix-profile/share/applications"));
        }
        // home-manager output
        if let Ok(user) = std::env::var("USER") {
            out.push(PathBuf::from(format!(
                "/etc/profiles/per-user/{user}/share/applications"
            )));
        }
        // $XDG_DATA_DIRS, defaulting to /usr/local/share:/usr/share. On NixOS
        // this typically expands to /run/current-system/sw/share + others.
        let xdg_data_dirs = std::env::var("XDG_DATA_DIRS")
            .unwrap_or_else(|_| String::from("/usr/local/share:/usr/share"));
        for dir in xdg_data_dirs.split(':') {
            if !dir.is_empty() {
                out.push(PathBuf::from(dir).join("applications"));
            }
        }
        // Flatpak exports.
        out.push(PathBuf::from("/var/lib/flatpak/exports/share/applications"));
        if let Some(home) = dirs_home() {
            out.push(home.join(".local/share/flatpak/exports/share/applications"));
        }
        out.into_iter().filter(|p| p.is_dir()).collect()
    })
}

fn dirs_home() -> Option<PathBuf> {
    std::env::var_os("HOME").map(PathBuf::from)
}

/// In-process cache: app_id → resolved icon path (or None if no match).
struct IconCache {
    paths: std::sync::Mutex<HashMap<String, Option<PathBuf>>>,
    /// app_id → fully-formed `data:image/<mime>;base64,...` URL. Built lazily
    /// once per app_id from the resolved path. Avoids re-reading + re-encoding
    /// the icon file on every render.
    data_urls: std::sync::Mutex<HashMap<String, Option<String>>>,
}

impl IconCache {
    fn new() -> Self {
        Self {
            paths: std::sync::Mutex::new(HashMap::new()),
            data_urls: std::sync::Mutex::new(HashMap::new()),
        }
    }
}

fn cache() -> &'static IconCache {
    static CACHE: OnceLock<IconCache> = OnceLock::new();
    CACHE.get_or_init(IconCache::new)
}

/// Resolve `app_id` to an icon file path. Returns None if nothing matches.
/// Cached after the first call for each app_id.
pub fn resolve(app_id: &str) -> Option<PathBuf> {
    if app_id.is_empty() {
        return None;
    }
    let cache = cache();
    {
        let map = cache.paths.lock().unwrap();
        if let Some(cached) = map.get(app_id) {
            return cached.clone();
        }
    }
    let result = resolve_inner(app_id);
    log::debug!("icon resolve {app_id} -> {:?}", result);
    cache
        .paths
        .lock()
        .unwrap()
        .insert(app_id.to_string(), result.clone());
    result
}

/// Build a `data:image/<mime>;base64,...` URL for the icon associated with
/// `app_id`. Reads + base64-encodes the file once, then caches the result.
///
/// We use data URLs instead of `file://` URLs because Blitz's `<img>` element
/// fires the data URL handler synchronously inside `load_image` (no
/// NetProvider message round-trip needed), which avoids the deferred-load
/// machinery that wasn't kicking in for our case.
pub fn data_url(app_id: &str) -> Option<String> {
    if app_id.is_empty() {
        return None;
    }
    let cache = cache();
    {
        let map = cache.data_urls.lock().unwrap();
        if let Some(cached) = map.get(app_id) {
            return cached.clone();
        }
    }
    let result = build_data_url(app_id);
    cache
        .data_urls
        .lock()
        .unwrap()
        .insert(app_id.to_string(), result.clone());
    result
}

fn build_data_url(app_id: &str) -> Option<String> {
    let path = resolve(app_id)?;
    let bytes = std::fs::read(&path).ok()?;
    let mime = match path.extension().and_then(|s| s.to_str()) {
        Some("png") => "image/png",
        Some("svg") => "image/svg+xml",
        Some("jpg") | Some("jpeg") => "image/jpeg",
        Some("webp") => "image/webp",
        Some("gif") => "image/gif",
        _ => return None,
    };
    let b64 = base64::engine::general_purpose::STANDARD.encode(&bytes);
    Some(format!("data:{mime};base64,{b64}"))
}

fn resolve_inner(app_id: &str) -> Option<PathBuf> {
    let icon_name = find_icon_name(app_id)?;
    lookup_icon_path(&icon_name)
}

/// Walk the search path, find the desktop file that matches `app_id`, return
/// its `Icon=` value.
fn find_icon_name(app_id: &str) -> Option<String> {
    // Strategy 1: direct filename match.
    for dir in applications_dirs() {
        let path = dir.join(format!("{app_id}.desktop"));
        if path.is_file() {
            if let Some(icon) = read_icon_field(&path) {
                return Some(icon);
            }
        }
    }
    // Strategy 2: scan all desktop files for StartupWMClass match (case-insensitive).
    // Strategy 3: fall back to filename stem prefix.
    let lower_app_id = app_id.to_lowercase();
    let mut prefix_fallback: Option<String> = None;
    for dir in applications_dirs() {
        let entries = match std::fs::read_dir(dir) {
            Ok(e) => e,
            Err(_) => continue,
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("desktop") {
                continue;
            }
            let entry_data = match parse_entry(&path) {
                Ok(e) => e,
                Err(_) => continue,
            };
            let section = match entry_data.section("Desktop Entry") {
                Some(s) => s,
                None => continue,
            };

            // StartupWMClass match (preferred).
            if let Some(wm_class) = first_attr(section.attr("StartupWMClass")) {
                if wm_class.eq_ignore_ascii_case(app_id) {
                    if let Some(icon) = first_attr(section.attr("Icon")) {
                        return Some(icon.to_string());
                    }
                }
            }

            // Filename stem prefix fallback — only used if nothing better is found.
            if prefix_fallback.is_none() {
                if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                    if stem.to_lowercase() == lower_app_id {
                        if let Some(icon) = first_attr(section.attr("Icon")) {
                            prefix_fallback = Some(icon.to_string());
                        }
                    }
                }
            }
        }
    }
    prefix_fallback
}

/// freedesktop_entry_parser 2.0 returns `&[String]` for any attribute (desktop
/// entries can be multi-valued). For most fields we want the first value.
fn first_attr(values: &[String]) -> Option<&str> {
    values.first().map(|s| s.as_str())
}

fn read_icon_field(path: &Path) -> Option<String> {
    let entry = parse_entry(path).ok()?;
    let section = entry.section("Desktop Entry")?;
    first_attr(section.attr("Icon")).map(|s| s.to_string())
}

/// Resolve an icon name through the XDG icon theme spec. Returns the first
/// match across configured themes; falls back to hicolor.
fn lookup_icon_path(name: &str) -> Option<PathBuf> {
    // If the icon field is already an absolute path, use it directly.
    let p = Path::new(name);
    if p.is_absolute() && p.is_file() {
        return Some(p.to_path_buf());
    }
    // Try the active theme (env-derived) at common dock sizes; SVGs win
    // because they scale cleanly.
    freedesktop_icons::lookup(name)
        .with_size(48)
        .with_scale(1)
        .with_cache()
        .find()
}
