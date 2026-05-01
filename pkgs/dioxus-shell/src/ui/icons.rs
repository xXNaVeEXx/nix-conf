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
//! XDG icon theme spec. Cached per-IconResolver — public functions wrap a
//! process-wide singleton; tests can build their own with a custom search path.

use base64::Engine;
use freedesktop_entry_parser::parse_entry;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

/// Resolves app_id → desktop file → icon path. Stateful so the caller can
/// scope caching and inject a fake search path.
pub struct IconResolver {
    applications_dirs: Vec<PathBuf>,
    paths: Mutex<HashMap<String, Option<PathBuf>>>,
    data_urls: Mutex<HashMap<String, Option<String>>>,
}

impl IconResolver {
    /// Build a resolver with the given desktop-file search dirs (in priority
    /// order). Non-existent dirs are filtered out.
    pub fn with_dirs(dirs: Vec<PathBuf>) -> Self {
        Self {
            applications_dirs: dirs.into_iter().filter(|p| p.is_dir()).collect(),
            paths: Mutex::new(HashMap::new()),
            data_urls: Mutex::new(HashMap::new()),
        }
    }

    /// Build a resolver using the standard XDG paths plus NixOS-specific dirs.
    pub fn from_env() -> Self {
        Self::with_dirs(default_applications_dirs())
    }

    /// Resolve `app_id` to an icon file path. Cached per-resolver.
    pub fn resolve(&self, app_id: &str) -> Option<PathBuf> {
        if app_id.is_empty() {
            return None;
        }
        if let Some(cached) = self.paths.lock().unwrap().get(app_id).cloned() {
            return cached;
        }
        let result = self.resolve_inner(app_id);
        log::debug!("icon resolve {app_id} -> {:?}", result);
        self.paths
            .lock()
            .unwrap()
            .insert(app_id.to_string(), result.clone());
        result
    }

    /// `data:image/<mime>;base64,...` URL for the icon associated with
    /// `app_id`. Reads + base64-encodes the file once, then caches the result.
    pub fn data_url(&self, app_id: &str) -> Option<String> {
        if app_id.is_empty() {
            return None;
        }
        if let Some(cached) = self.data_urls.lock().unwrap().get(app_id).cloned() {
            return cached;
        }
        let result = self.build_data_url(app_id);
        self.data_urls
            .lock()
            .unwrap()
            .insert(app_id.to_string(), result.clone());
        result
    }

    fn build_data_url(&self, app_id: &str) -> Option<String> {
        let path = self.resolve(app_id)?;
        let bytes = std::fs::read(&path).ok()?;
        // Rasterize SVGs to PNG up-front. Blitz/vello's SVG path produces
        // black squares for some inputs (gnome-icons, app icons with complex
        // gradients/masks). Rasterizing to a fixed 64x64 PNG sidesteps the
        // SVG renderer entirely.
        let (mime, encoded) = match path.extension().and_then(|s| s.to_str()) {
            Some("svg") => {
                let png = rasterize_svg(&bytes, 64)?;
                ("image/png", png)
            }
            _ => {
                let m = mime_for(&path)?;
                (m, bytes)
            }
        };
        let b64 = base64::engine::general_purpose::STANDARD.encode(&encoded);
        Some(format!("data:{mime};base64,{b64}"))
    }

    fn resolve_inner(&self, app_id: &str) -> Option<PathBuf> {
        let icon_name = self.find_icon_name(app_id)?;
        lookup_icon_path(&icon_name)
    }

    /// Walk the search path, find the desktop file that matches `app_id`,
    /// return its `Icon=` value.
    fn find_icon_name(&self, app_id: &str) -> Option<String> {
        // Strategy 1: direct filename match.
        for dir in &self.applications_dirs {
            let path = dir.join(format!("{app_id}.desktop"));
            if path.is_file() {
                if let Some(icon) = read_icon_field(&path) {
                    return Some(icon);
                }
            }
        }
        // Strategy 2: scan all desktop files for StartupWMClass match.
        // Strategy 3: fall back to filename stem prefix (case-insensitive).
        let lower_app_id = app_id.to_lowercase();
        let mut prefix_fallback: Option<String> = None;
        for dir in &self.applications_dirs {
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

                // Filename stem prefix fallback.
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
}

/// Rasterize an SVG into a square PNG at the given pixel size.
/// Returns the encoded PNG bytes, or None if anything fails.
fn rasterize_svg(svg_bytes: &[u8], size: u32) -> Option<Vec<u8>> {
    let opts = usvg::Options::default();
    let tree = usvg::Tree::from_data(svg_bytes, &opts).ok()?;
    let tree_size = tree.size();
    // Choose a uniform scale to fit the icon in `size x size` while
    // preserving aspect ratio.
    let scale = (size as f32 / tree_size.width()).min(size as f32 / tree_size.height());
    let mut pixmap = tiny_skia::Pixmap::new(size, size)?;
    let transform = tiny_skia::Transform::from_scale(scale, scale);
    resvg::render(&tree, transform, &mut pixmap.as_mut());
    pixmap.encode_png().ok()
}

fn mime_for(path: &Path) -> Option<&'static str> {
    match path.extension().and_then(|s| s.to_str()) {
        Some("png") => Some("image/png"),
        Some("svg") => Some("image/svg+xml"),
        Some("jpg") | Some("jpeg") => Some("image/jpeg"),
        Some("webp") => Some("image/webp"),
        Some("gif") => Some("image/gif"),
        _ => None,
    }
}

/// Default desktop-file search path: $XDG_DATA_HOME/applications + nix-profile
/// + home-manager output + $XDG_DATA_DIRS + Flatpak exports.
fn default_applications_dirs() -> Vec<PathBuf> {
    let mut out = Vec::new();
    if let Some(home) = std::env::var_os("HOME").map(PathBuf::from) {
        out.push(home.join(".local/share/applications"));
        out.push(home.join(".nix-profile/share/applications"));
        if let Ok(user) = std::env::var("USER") {
            out.push(PathBuf::from(format!(
                "/etc/profiles/per-user/{user}/share/applications"
            )));
        }
        out.push(home.join(".local/share/flatpak/exports/share/applications"));
    }
    let xdg_data_dirs = std::env::var("XDG_DATA_DIRS")
        .unwrap_or_else(|_| String::from("/usr/local/share:/usr/share"));
    for dir in xdg_data_dirs.split(':') {
        if !dir.is_empty() {
            out.push(PathBuf::from(dir).join("applications"));
        }
    }
    out.push(PathBuf::from("/var/lib/flatpak/exports/share/applications"));
    out
}

fn first_attr(values: &[String]) -> Option<&str> {
    values.first().map(|s| s.as_str())
}

fn read_icon_field(path: &Path) -> Option<String> {
    let entry = parse_entry(path).ok()?;
    let section = entry.section("Desktop Entry")?;
    first_attr(section.attr("Icon")).map(|s| s.to_string())
}

/// XDG icon theme lookup. Absolute paths in the icon-name field are returned
/// as-is.
fn lookup_icon_path(name: &str) -> Option<PathBuf> {
    let p = Path::new(name);
    if p.is_absolute() && p.is_file() {
        return Some(p.to_path_buf());
    }
    freedesktop_icons::lookup(name)
        .with_size(48)
        .with_scale(1)
        .with_cache()
        .find()
}

// --- process-wide singleton & convenience wrappers --------------------------

fn shared() -> &'static IconResolver {
    static SHARED: OnceLock<IconResolver> = OnceLock::new();
    SHARED.get_or_init(IconResolver::from_env)
}

pub fn resolve(app_id: &str) -> Option<PathBuf> {
    shared().resolve(app_id)
}

pub fn data_url(app_id: &str) -> Option<String> {
    shared().data_url(app_id)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    /// Build a tempdir-backed `applications/` directory with the given desktop
    /// files and return an IconResolver pointing at it.
    fn resolver_with_desktops(entries: &[(&str, &str)]) -> (TempDir, IconResolver) {
        let tmp = TempDir::new().unwrap();
        let apps_dir = tmp.path().join("applications");
        fs::create_dir_all(&apps_dir).unwrap();
        for (filename, contents) in entries {
            fs::write(apps_dir.join(filename), contents).unwrap();
        }
        let resolver = IconResolver::with_dirs(vec![apps_dir]);
        (tmp, resolver)
    }

    #[test]
    fn empty_app_id_returns_none() {
        let resolver = IconResolver::with_dirs(vec![]);
        assert!(resolver.resolve("").is_none());
        assert!(resolver.data_url("").is_none());
    }

    #[test]
    fn missing_app_returns_none() {
        let (_tmp, resolver) = resolver_with_desktops(&[]);
        assert!(resolver.resolve("nonexistent").is_none());
    }

    #[test]
    fn finds_icon_via_filename_match() {
        let (_tmp, resolver) = resolver_with_desktops(&[(
            "firefox.desktop",
            "[Desktop Entry]\nName=Firefox\nIcon=/tmp/test-icon.png\nType=Application\n",
        )]);
        // Create the absolute icon file so lookup_icon_path returns it.
        fs::write("/tmp/test-icon.png", b"fake png").unwrap();
        let resolved = resolver.resolve("firefox");
        assert_eq!(resolved.as_deref(), Some(Path::new("/tmp/test-icon.png")));
        let _ = fs::remove_file("/tmp/test-icon.png");
    }

    #[test]
    fn find_icon_name_filename_strategy() {
        let (_tmp, resolver) = resolver_with_desktops(&[(
            "firefox.desktop",
            "[Desktop Entry]\nName=Firefox\nIcon=firefox-icon\nType=Application\n",
        )]);
        assert_eq!(
            resolver.find_icon_name("firefox").as_deref(),
            Some("firefox-icon")
        );
    }

    #[test]
    fn find_icon_name_startup_wm_class_strategy() {
        // Filename doesn't match app_id, but StartupWMClass does.
        let (_tmp, resolver) = resolver_with_desktops(&[(
            "org.kde.konsole.desktop",
            "[Desktop Entry]\nName=Konsole\nIcon=utilities-terminal\nStartupWMClass=Konsole\nType=Application\n",
        )]);
        assert_eq!(
            resolver.find_icon_name("Konsole").as_deref(),
            Some("utilities-terminal")
        );
        // Case-insensitive WMClass match.
        assert_eq!(
            resolver.find_icon_name("konsole").as_deref(),
            Some("utilities-terminal")
        );
    }

    #[test]
    fn find_icon_name_filename_stem_prefix_fallback() {
        // No filename match (case differs), no StartupWMClass — but filename
        // stem matches case-insensitively.
        let (_tmp, resolver) = resolver_with_desktops(&[(
            "Firefox.desktop",
            "[Desktop Entry]\nName=Firefox\nIcon=ff-fallback\nType=Application\n",
        )]);
        assert_eq!(
            resolver.find_icon_name("firefox").as_deref(),
            Some("ff-fallback")
        );
    }

    #[test]
    fn data_url_for_real_file() {
        // Write a real PNG and a desktop file pointing at its absolute path.
        let tmp = TempDir::new().unwrap();
        let png_path = tmp.path().join("icon.png");
        // Tiny valid PNG header + minimal IHDR/IDAT/IEND. Doesn't have to be
        // semantically meaningful; we're checking encoding only.
        let png_bytes: &[u8] = b"\x89PNG\r\n\x1a\n";
        fs::write(&png_path, png_bytes).unwrap();
        let apps_dir = tmp.path().join("applications");
        fs::create_dir_all(&apps_dir).unwrap();
        fs::write(
            apps_dir.join("myapp.desktop"),
            format!(
                "[Desktop Entry]\nName=MyApp\nIcon={}\nType=Application\n",
                png_path.display()
            ),
        )
        .unwrap();
        let resolver = IconResolver::with_dirs(vec![apps_dir]);

        let url = resolver.data_url("myapp").expect("data url");
        assert!(url.starts_with("data:image/png;base64,"), "got: {url}");
        // Decode the base64 portion and verify it round-trips to the original.
        let b64 = url.strip_prefix("data:image/png;base64,").unwrap();
        let decoded = base64::engine::general_purpose::STANDARD
            .decode(b64)
            .unwrap();
        assert_eq!(decoded, png_bytes);
    }

    #[test]
    fn data_url_caching_is_stable() {
        let tmp = TempDir::new().unwrap();
        let png_path = tmp.path().join("icon.png");
        fs::write(&png_path, b"\x89PNG\r\n\x1a\n").unwrap();
        let apps_dir = tmp.path().join("applications");
        fs::create_dir_all(&apps_dir).unwrap();
        fs::write(
            apps_dir.join("myapp.desktop"),
            format!(
                "[Desktop Entry]\nName=MyApp\nIcon={}\nType=Application\n",
                png_path.display()
            ),
        )
        .unwrap();
        let resolver = IconResolver::with_dirs(vec![apps_dir]);

        let first = resolver.data_url("myapp");
        let second = resolver.data_url("myapp");
        assert_eq!(first, second);
        assert!(first.is_some());
    }

    #[test]
    fn mime_dispatch() {
        assert_eq!(mime_for(Path::new("a.png")), Some("image/png"));
        assert_eq!(mime_for(Path::new("a.svg")), Some("image/svg+xml"));
        assert_eq!(mime_for(Path::new("a.jpg")), Some("image/jpeg"));
        assert_eq!(mime_for(Path::new("a.jpeg")), Some("image/jpeg"));
        assert_eq!(mime_for(Path::new("a.webp")), Some("image/webp"));
        assert_eq!(mime_for(Path::new("a.gif")), Some("image/gif"));
        assert_eq!(mime_for(Path::new("a.unknown")), None);
        assert_eq!(mime_for(Path::new("noext")), None);
    }
}
