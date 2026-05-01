# dioxus-shell — project state and decisions

This file is the canonical hand-off doc for whoever (human or model) picks this up next session. Read it before touching code. The plan in `/root/.claude/plans/can-we-change-from-inherited-sun.md` is the original spec; this file records what survived contact with reality.

## Goal

Replace Quickshell (~2,310 lines of QML across 24 files in `modules/desktop/configs/quickshell/`) with a Rust-based desktop shell for MangoWC. Full functional parity: top bar (3 islands), bottom auto-hiding dock, theme switcher overlay, keybindings cheatsheet overlay, IPC via `/tmp/quickshell-command`, multi-monitor.

Roll out as opt-in `mySystem.desktop.bar = "dioxus"` alongside existing `waybar` and `quickshell` enum values. Remove Quickshell wiring only after parity.

## Status (May 2026)

**Skeleton milestone: complete.** Bar surface created via `wlr-layer-shell`, painted via wgpu, anchored top, exclusive zone reserved. Verified visually inside MangoWC on a Proxmox VM (no GPU; falls back to llvmpipe). Currently paints a solid dark-slate rectangle and nothing else.

**Dependency milestone: complete.** Full Dioxus + Blitz + Vello + stylo stack compiles in Nix against the SCTK-owned wgpu surface. wgpu bumped 22 → 28 cleanly.

**Vello milestone: complete.** Vello renders into an intermediate `Rgba8Unorm` storage texture via compute shader, then `wgpu::util::TextureBlitter` blits to the swapchain. Surface format is non-sRGB (`Bgra8Unorm` or `Rgba8Unorm`) — Vello applies its own gamma. Verified visually inside MangoWC.

**Dioxus + Blitz integration milestone: complete.** `src/ui/mod.rs` builds a `VirtualDom` + `DioxusDocument` + `DEFAULT_CSS` + custom flexbox stylesheet, runs `initial_build()`, and per-frame calls `inner.resolve(now_secs)` + `blitz_paint::paint_scene(VelloScenePainter, doc, ...)` to populate a `vello::Scene`. The renderer hands the resulting scene to `vello::Renderer::render_to_texture`. First widget: a 32px bar with "dioxus-shell" on the left and `HH:MM:SS` on the right, both styled via `<style>` block embedded in the rsx. Verified visually.

**Reactive redraw loop milestone: complete.** A `tokio::runtime::Builder::new_current_thread().enable_time().enable_io()` runtime drives `use_future` hooks. `Ui::poll()` enters the runtime, `block_on(yield_now())` to advance pending tasks, then calls `DioxusDocument::poll(cx)` with a `DirtyWaker` that flips an atomic flag when any Dioxus signal fires. The Wayland event loop was rewritten on top of `calloop::EventLoop` with `WaylandSource` + a 100ms `Timer` that drives `Ui::poll()` and re-renders only when the dirty flag was set. Idle CPU on llvmpipe-on-Proxmox is ~4% (down from ~13% in the unconditional 60Hz draft).

**Multi-widget milestone: complete.** Widgets factored out under `src/ui/widgets/`. Five reactive widgets covering the full top bar from the original Quickshell port:
- `widgets::Clock` — `use_signal(String)` updated every second by `tokio::time::interval`.
- `widgets::WindowTitle` — `use_future` polls `mangoctl get-active-window-title` every 500ms via `tokio::process::Command`.
- `widgets::TagIndicators` — polls `mangoctl get-active-tag` every 500ms. Renders five 10px dots with the active one highlighted via class swap.
- `widgets::SystemInfo` — `sysinfo` crate, `/proc`-based, every 2s. CPU% averaged across all cores + RAM%.
- `widgets::Wlan` — polls `nmcli -t` for ethernet and wifi state every 5s. Color-coded by signal strength: strong/medium/weak/poor/offline.

Idle CPU on llvmpipe-on-Proxmox: 3.4% (2 widgets) → 5.6% (3) → 6.1% (4) → 6.9% (5). Per-widget cost is proportional to (poll rate × work per poll). Cheap widgets (sysinfo, slow polls) add ~0.5%; expensive widgets (process-spawning, fast polls) add ~2%. On real GPU hardware these numbers would likely be ~1× their current values. **Adding new widgets is now a matter of writing a `use_future` + an rsx fragment**; no Wayland/wgpu/Vello plumbing involved.

**Dock milestone (Phase A + B): complete.** A second `wlr_layer_shell` surface anchored bottom, separate Renderer + Ui + tokio runtime mirroring the bar's structure. Renders one tile per running app with real icons (PNG via `image` crate, SVG pre-rasterized via `resvg`+`tiny-skia` because vello/blitz produces black squares for some app SVGs). Multiple windows of the same app collapse to a single tile with a count badge ("2", "3"...). Click cycles through windows of that app via `ZwlrForeignToplevelHandleV1::activate(seat)`; clicking with no running window spawns a fresh process via the `.desktop` file's `Exec=` field. Hover doesn't steal keyboard focus (`KeyboardInteractivity::None`) but click events are delivered (mango quirk: layer-shell pointer button events require *some* non-default keyboard interactivity, which we discovered after a long detour — current setting works on mango HEAD; may need re-checking on other compositors).

**Dual-backend renderer.** `VelloBackend::Gpu` uses `vello::Renderer::render_to_texture`; `VelloBackend::Cpu` uses `anyrender_vello_cpu::VelloCpuScenePainter` → `Pixmap` → `Queue::write_texture`. Both blit through `TextureBlitter` to the swapchain. Default is GPU; `DIOXUS_SHELL_RENDER=cpu` env override forces CPU. On GPU init failure we fall back to CPU automatically. CPU path was added because vello's GPU compute shaders had issues on llvmpipe with image draws; we ultimately found that the GPU path *does* work for our use case once SVGs are pre-rasterized, but the CPU path is kept as a fallback and verified working.

**`<img>` integration: solved.** This took several detours but the answer is short: (1) blitz-dom routes *every* image URL through `NetProvider::fetch` including `data:` URLs (no inline shortcut), so our provider must handle data: explicitly using the `data-url` crate, mirroring blitz-net's reference impl. (2) `inner.handle_messages()` must be drained both after `initial_build()` and after each `doc.poll()`; without it, fetched bytes never reach `special_data` on the `<img>` node. (3) SVGs render as black squares through blitz/vello — pre-rasterize to 64×64 PNG via resvg at icon-resolve time. PNG icons render correctly through both GPU and CPU paths.

**Pinning + hot-reload: complete.** Reads `~/.config/dioxus-shell/dock.toml` (or `$XDG_CONFIG_HOME/dioxus-shell/dock.toml`) at startup; `notify`-watcher reloads on file change. Config is `pinned: Vec<String>` for now (more fields like `auto_hide`, `position`, `magnification` will land with Phase C). Tile order: pinned-in-config-order first, then unpinned running apps. Pinned-not-running tiles still launch on click via the `.desktop` file's `Exec=`.

**What's left from the original Quickshell port:**
1. ~~**Bottom dock**~~ — done. Auto-hide + magnification still TODO (Phase C).
2. **Right-click pin/unpin** — small UX polish for managing the dock without manually editing the config.
3. **Theme switcher overlay** (Alt+Shift+T) — Phase D scope.
4. **Keybindings cheatsheet overlay** (Alt+B) — Phase D scope.
5. **IPC** — watch `/tmp/quickshell-command` for `toggle-theme-switcher` / `toggle-keybindings-cheatsheet`. Drives overlays. Phase D.
6. **WayVNC widget** — only if `mySystem.remote.wayvnc = true`.

`mySystem.desktop.bar` defaults to `"waybar"`; the live desktop is unaffected by anything in this crate. Set `bar = "dioxus"` only after parity is reached.

## How to run

```bash
cd /etc/nixos
nix build .#packages.x86_64-linux.dioxus-shell
./result/bin/dioxus-shell           # paints a dark-slate bar at the top of the active session
```

For a clean test inside a kiosk compositor on a free TTY:

```bash
nix shell nixpkgs#cage -c cage -- ./result/bin/dioxus-shell
```

`RUST_LOG=debug` for verbose output. `RUST_LOG=dioxus_shell=info,wgpu_core=warn,wgpu_hal=warn` to silence wgpu chatter.

## Repo wiring (all done, don't redo)

- `pkgs/dioxus-shell/` — the Cargo crate + `default.nix`. `rustPlatform.buildRustPackage`. `wrapProgram` adds `vulkan-loader`/`wayland`/`libxkbcommon` to `LD_LIBRARY_PATH`.
- `flake.nix` (line ~121) — exposes `packages.x86_64-linux.dioxus-shell` via `pkgs.callPackage`.
- `options.nix:11–15` — bar enum is `[ "waybar" "quickshell" "dioxus" ]`.
- `modules/desktop/mangowc.nix`:
  - `dioxusShellPkg` defined in the top `let` block (~line 147)
  - `dioxusShellLauncher` writeShellScript (~line 149)
  - `barCommand` is now a 3-way `if` (~line 155)
  - package list extended with `dioxus-shell` branch (~line 491)

**One incidental fix:** the original `barCommand` for `quickshell` was `"''${quickshellLauncher}"` — `''` is *not* an escape inside a regular `"..."` Nix string (only valid inside `'' ... ''` indented strings), so the literal output was `''/nix/store/.../quickshell-launcher`. mango/sh tolerated the leading `''` (empty-string in shell). The new code emits a clean `${...}` interpolation. If anyone was depending on the literal `''` prefix, they aren't.

## Architecture decisions

### Why "Dioxus + Blitz + Vello" and not "Dioxus + Blitz" alone

The original plan said "Dioxus + Blitz" but didn't specify the rendering plumbing. Research (April 2026) found:

- **Blitz's renderer (`anyrender_vello`) cannot share a foreign `wgpu::Device`.** It always creates its own `wgpu::Instance` + `Device` + `Queue` + `Surface`. There is no "wrap an existing device" constructor (`anyrender/crates/anyrender_vello/src/window_renderer.rs`).
- **`blitz-renderer-vello` crate is deprecated.** Replaced by `anyrender_vello` in `DioxusLabs/anyrender`.
- **`dioxus-native`'s `BlitzApplication` requires `winit`.** `winit` on Linux Wayland does not implement `wlr_layer_shell_v1`. It physically cannot create a layer-shell bar. We must drive the event loop ourselves via `smithay-client-toolkit`.

**Escape hatch (the path we're taking):** use `blitz-dom` + `blitz-paint` for *layout and painting only* (they emit into a `vello::Scene`), then drive `vello::Renderer` directly against our SCTK-owned `wgpu::Device`. Verified API surfaces:

- `BaseDocument::new(DocumentConfig)` — `blitz-dom/src/document.rs:319`
- `paint_scene(scene: &mut impl PaintScene, dom: &BaseDocument, scale, w, h, x_off, y_off)` — `blitz-paint/src/lib.rs:28`
- `VelloScenePainter::new(&mut Scene)` — `anyrender_vello/src/scene.rs:16`. This is the no-renderer-required wrapper that adapts a `vello::Scene` to the `PaintScene` trait.
- `dioxus_native_dom::MutationWriter` (public!) — `dioxus-native-dom/src/mutation_writer.rs:64`. Lets us drive `vdom.rebuild(&mut writer)` and `vdom.render_immediate(&mut writer)` against our `BaseDocument` without touching `BlitzApplication`.
- `vello::Renderer::render_to_texture(&device, &queue, &scene, &texture_view, &RenderParams)` — takes a `wgpu::TextureView` from `surface.get_current_texture().texture.create_view(...)`. This is what we'll call.

### Why we are not using

- **`blitz-renderer-vello`** — deprecated.
- **`dioxus-native` (full crate)** — pulls in `BlitzApplication` + `winit`, can't do layer-shell.
- **`anyrender_vello::VelloWindowRenderer`** — owns its own wgpu device.
- **Pure Vello + parley + Taffy** — we discussed this (option C in the session that established the path); user explicitly chose Dioxus + Blitz because they are standardizing on Dioxus and want `rsx!`. So we pay the integration tax. If the integration ever proves unworkable, this is the principled fallback.

### Critical version pins (current — verified building)

The Dioxus / Blitz / Vello stack is **pinned to git revs of `DioxusLabs/blitz` and `DioxusLabs/anyrender`**, not crates.io. Reason: the latest crates.io `dioxus-native-dom` (0.7.6) pins `blitz-dom ^0.2.4`, which in turn forces `anyrender_vello 0.6.x` → `wgpu 26` → incompatible with everything else. The 0.3-line of Blitz only exists on git HEAD (no published release). Same for `anyrender_vello 0.8` from anyrender's main.

```toml
# blitz: workspace at DioxusLabs/blitz @ 6863eac76c36a64a8926c5a71947f478c3614a64
blitz-dom = { git = "...", rev = "6863eac…" }
blitz-paint = { git = "...", rev = "6863eac…" }
blitz-traits = { git = "...", rev = "6863eac…" }
dioxus-native-dom = { git = "...", rev = "6863eac…" }

# anyrender: workspace at DioxusLabs/anyrender, branch main
anyrender_vello = { git = "...", branch = "main" }

# transitive crates that also need [patch.crates-io] forcing to git, otherwise
# cargo-vendor-dir fails on duplicate (crate, version) entries:
[patch.crates-io]
debug_timer = { git = "https://github.com/DioxusLabs/blitz", rev = "6863eac…" }
anyrender = { git = "https://github.com/DioxusLabs/anyrender", branch = "main" }

# pure crates.io
wgpu = "=28"
vello = { version = "0.8", features = ["wgpu"] }
dioxus-core = "0.7.3"
```

**`pkgs/dioxus-shell/default.nix` ALSO needs `outputHashes` entries** for every git dep that appears in `Cargo.lock` with a `git+...` source. The current set:

- `blitz-dom-0.3.0-alpha.2`, `blitz-paint-0.3.0-alpha.2`, `blitz-traits-0.3.0-alpha.2`, `debug_timer-0.1.3`, `dioxus-native-dom-0.7.0`, `stylo_taffy-0.3.0-alpha.2` — all from `DioxusLabs/blitz @ 6863eac…`, hash `sha256-kwkKWbf/JGdkBX429buFJWelRCkIYdgsqDNwj+/MqtM=`.
- `anyrender-0.8.0`, `anyrender_vello-0.8.0`, `anyrender_vello_cpu-0.10.0`, `wgpu_context-0.4.0` — all from `DioxusLabs/anyrender @ c12e3ff…`, hash `sha256-rNl0YxDdFCgLuF1w0gv+EvHfuz3p/b/M6Nu24FIdPXg=`.

**When bumping the blitz/anyrender SHA**: re-prefetch with `nix shell nixpkgs#nix-prefetch-git -c nix-prefetch-git --quiet <url> --rev <sha>`, replace the SHA in `Cargo.toml`, run `cargo update`, then update the relevant `outputHashes` block in `default.nix`.

**`stylo` (Servo's CSS engine) requires Python at build time.** `default.nix` has `python3` in `nativeBuildInputs` for this — don't remove it.

`dioxus-native-dom` README says **"pre-alpha, not for production."** Expect upstream churn. We pin to a specific SHA; bump deliberately, not via `cargo update`.

`DioxusDocument.inner` is `Rc<RefCell<BaseDocument>>` — **not `Send`**. UI work stays single-threaded.

### Edition / rustc requirement

`blitz-paint` is on edition 2024, requires `rustc ≥ 1.92`. Nixpkgs `rustc` is 1.94 → fine.

## Code structure (current)

```
pkgs/dioxus-shell/
├── Cargo.toml                  — wgpu=28, sctk=0.19, full Dioxus/Blitz/Vello stack,
│                                 anyrender_vello + anyrender_vello_cpu (dual backend),
│                                 vello_cpu, resvg/usvg/tiny-skia (SVG → PNG),
│                                 freedesktop_entry_parser + freedesktop-icons,
│                                 tokio (rt+time+macros+sync+process+io-util),
│                                 calloop, calloop-wayland-source, base64, data-url,
│                                 wayland-protocols-wlr (foreign_toplevel client)
├── Cargo.lock
├── default.nix                 — buildRustPackage + wrapProgram + python3 (for stylo)
├── PROJECT.md                  — this file
├── tests/fixtures/             — embedded real icon files used by integration tests
│   ├── brave-browser.png
│   ├── nautilus.svg
│   └── wezterm.png
└── src/
    ├── main.rs                 — entry: env_logger init, Shell::new()?.run()
    ├── config.rs               — Config struct (serde::Deserialize). watch_config(path)
    │                             spawns a notify watcher on the parent dir (atomic-write
    │                             friendly), debounces 150ms, broadcasts reloads through
    │                             tokio::sync::watch. Failed parses keep the previous value.
    │                             Default path: $XDG_CONFIG_HOME/dioxus-shell/dock.toml.
    ├── wayland/
    │   ├── mod.rs              — pub use shell::Shell, toplevel::Toplevel
    │   ├── shell.rs            — calloop::EventLoop driven shell. WaylandSource handles
    │   │                         all wayland events; a 100ms Timer drives Ui::poll() on
    │   │                         each bar/dock via State::tick(). State holds bars,
    │   │                         docks, foreign_toplevel manager + accumulator hashmap,
    │   │                         the seat (for activate requests), and a per-app
    │   │                         cycle_index for round-robin window cycling. SeatHandler
    │   │                         + PointerHandler implementations dispatch click events
    │   │                         to docks; focus_existing(app_id) advances the cycle
    │   │                         and calls handle.activate(seat). publish_toplevels()
    │   │                         broadcasts via tokio::sync::watch.
    │   ├── surface.rs          — BarSurface (top, exclusive zone) and DockSurface
    │   │                         (bottom, no exclusive zone). Both own LayerSurface +
    │   │                         Renderer + initial toplevel watch::Receiver. configure()
    │   │                         initializes renderer on first call. tick() drives a
    │   │                         render if dirty. DockSurface::hit_test_app_id walks
    │   │                         BaseDocument::hit() upward looking for data-app-id.
    │   │                         output() returns None — TODO: multi-monitor side-table.
    │   └── toplevel.rs         — raw zwlr_foreign_toplevel_management_v1 wiring.
    │                             Dispatch impls accumulate title/app_id/state events
    │                             into PendingToplevel; publish on `done`/`closed`.
    │                             event_created_child! on the manager dispatches the
    │                             toplevel-event-creates-handle child object.
    ├── ui/
    │   ├── mod.rs              — Ui struct: tokio current-thread runtime + DioxusDocument
    │   │                         + DirtyFlag waker. Ui::new(width, height, root_fn,
    │   │                         contexts) is generic over the root component, so the
    │   │                         bar uses App and the dock uses DockApp. Contexts are
    │   │                         insert_any_root_context'd into the VirtualDom — the
    │   │                         dock's toplevel watch::Receiver is delivered this way.
    │   │                         poll() drives tokio + Dioxus + drains
    │   │                         inner.handle_messages() (critical for image loading).
    │   │                         paint(scene, now_secs) GPU path; paint_cpu(now_secs)
    │   │                         returns a Pixmap for the CPU path. app_id_at(x, y)
    │   │                         hit-tests via BaseDocument::hit() then walks parents
    │   │                         looking for data-app-id. launch_app(app_id) spawns
    │   │                         a detached process from the .desktop file's Exec=.
    │   ├── icons.rs             — IconResolver: app_id → desktop file → icon path,
    │   │                         then via XDG icon theme spec to a real PNG/SVG file.
    │   │                         Three-strategy lookup (filename, StartupWMClass,
    │   │                         filename-stem). data_url(app_id) builds a
    │   │                         data:image/<mime>;base64,... URL; SVGs get
    │   │                         pre-rasterized to 64×64 PNG via resvg+tiny-skia
    │   │                         (workaround for blitz/vello SVG paint producing
    │   │                         black squares). exec_for(app_id) reads + cleans the
    │   │                         Exec= field (strips %U/%F/etc field codes).
    │   ├── net_provider.rs      — LocalFileProvider implements blitz_traits::NetProvider
    │   │                         for both data: and file: URLs. data: uses data_url
    │   │                         crate (mirrors blitz-net's reference impl); file:
    │   │                         reads the disk path. Other schemes drop silently.
    │   │                         Critical: blitz routes EVERY image URL through the
    │   │                         NetProvider including data: — there's no inline
    │   │                         shortcut.
    │   ├── dock_app.rs          — Root component for the dock surface. Subscribes to
    │   │                         the toplevel watch::Receiver via use_context; renders
    │   │                         one DockTile per app_id (collapsing multiple windows
    │   │                         into one tile with a count badge). Pre-rasterized
    │   │                         icons via icon_data_url + <img>.
    │   └── widgets/
    │       ├── mod.rs          — pub use Clock, WindowTitle, TagIndicators, SystemInfo, Wlan
    │       ├── clock.rs        — Signal<String> + 1s tokio interval
    │       ├── window_title.rs — Signal<String> sourced from foreign_toplevel watch
    │       │                     (no mangoctl polling). Falls back to short app_id.
    │       ├── tag_indicators.rs — Signal<u8> + 500ms `mangoctl get-active-tag`.
    │       ├── system_info.rs  — Signal<Stats> + 2s sysinfo polling (pure-Rust /proc).
    │       └── wlan.rs         — Signal<NetState> + 5s nmcli polling.
    └── render/
        ├── mod.rs              — pub use renderer::Renderer
        └── renderer.rs         — wgpu Renderer. Dual backend: VelloBackend::Gpu uses
                                  vello::Renderer + render_to_texture into an Rgba8Unorm
                                  storage texture; VelloBackend::Cpu uses Ui::paint_cpu
                                  to get a Pixmap and Queue::write_texture to upload it
                                  into a Rgba8Unorm copy_dst texture. Both end with
                                  TextureBlitter::copy → swapchain → present. Default
                                  GPU; falls back to CPU on init failure or when
                                  DIOXUS_SHELL_RENDER=cpu. Non-sRGB swapchain format
                                  (vello does its own gamma). RawWaylandTarget bridges
                                  SCTK pointers to raw-window-handle 0.6.
```

Roughly 1500 lines of Rust now.

## Known gaps

These are intentional debt; address as the relevant feature lands:

1. **`BarSurface::output()` / `DockSurface::output()` return `None`.** SCTK 0.19's `LayerSurface` doesn't expose its output. Fix when multi-monitor matters: keep a `Vec<(LayerSurface, WlOutput)>` side-table in `State` instead.
2. **Two `Ui`s per output (bar + dock)**, each with its own tokio runtime + Dioxus VirtualDom + wgpu setup. For per-output state (focused window title, dock contents) that's correct; for global state (clock, theme) it duplicates work. Idle cost: ~7% of one core on llvmpipe-VM with all 5 widgets + dock; on real GPU much less. Acceptable.
3. **100ms tick rate is a compromise.** The calloop timer drives `Ui::poll` at 10Hz to advance tokio timers, regardless of activity. Optimization for later: arm the calloop Timer for the next tokio deadline instead of a fixed 100ms.
4. **Segfault on shutdown** (Ctrl+C sometimes crashes during cleanup). wgpu/vello/wayland drop ordering, or a tokio runtime trying to drop while a task is mid-poll. Doesn't affect normal use; should be fixed before flipping `bar = "dioxus"`.
5. **Tile order in dock changes when windows open/close.** `BTreeMap<app_id, _>` sorts alphabetically — stable but not user-controlled. Pinning (next milestone) will address this naturally: pinned apps in user-defined order, unpinned running apps appended.
6. **Dock surface uses `KeyboardInteractivity::None`** — works on mango HEAD, untested on other compositors. If clicks don't register on another compositor, try `OnDemand`.
7. **`environment.etc."xdg/dioxus-shell"` not wired.** Drop in `mangowc.nix` when the shell needs config files.
8. **`xdg/quickshell-wallpapers.json`** still under that path. Generalize to `xdg/desktop-wallpapers.json` when needed.
9. **`home/gamzat.nix:45–48`** still symlinks `~/.config/quickshell` redundantly.
10. **wgpu chatter on llvmpipe.** Each frame logs `Device::maintain: waiting for submission index N` at INFO. Add a default `RUST_LOG` filter (`dioxus_shell=info,wgpu_core=warn,wgpu_hal=warn`).

## Pattern for new widgets

Both existing widgets follow the same shape; copy it.

```rust
// src/ui/widgets/<widget>.rs
use dioxus::prelude::*;
use std::time::Duration;
use tokio::time::{interval, MissedTickBehavior};

#[component]
pub fn YourWidget() -> Element {
    let mut value = use_signal(|| String::new()); // or whatever type

    use_future(move || async move {
        let mut interval = interval(Duration::from_millis(500));
        interval.set_missed_tick_behavior(MissedTickBehavior::Skip);
        loop {
            interval.tick().await;
            let new = fetch().await; // tokio::process::Command, tokio::fs, etc.
            // Diff-and-skip — only setting the signal when the value differs
            // keeps idle CPU low. Without this, every tick wakes the VirtualDom
            // and triggers a full Vello re-render.
            if *value.read() != new {
                value.set(new);
            }
        }
    });

    rsx!("{value}")
}
```

Then in `src/ui/widgets/mod.rs`: `mod your_widget; pub use your_widget::YourWidget;`. In `src/ui/mod.rs`'s `App()` rsx, drop in `widgets::YourWidget {}`.

**Cargo features**: `tokio::process::Command` needs `["process", "io-util"]`. `tokio::fs::*` needs `"fs"`. `tokio::net::*` needs `"net"`. Keep the feature set tight to keep build times reasonable (~30s incremental for a widget change; ~3min cold).

**CSS layout**: edit `STYLES` in `src/ui/mod.rs`. The flexbox row already supports a `flex: 1 1 auto; min-width: 0;` ellipsis-truncating left cell — copy that pattern for any expanding cell. For multi-element widgets, give them their own class and a `.bar > .your-widget` selector.

## Image / icon rendering — quirks

Lessons from the dock work that any future work touching `<img>` or icons should know:

1. **`NetProvider::fetch` is the only fetch path.** blitz-dom routes every `<img>` URL through `net_provider.fetch`, including `data:` URLs. There is no inline shortcut for `data:` in blitz-dom (only in `blitz-net`'s reference impl). Our `LocalFileProvider` handles both `data:` and `file:` explicitly. Anything else returns no bytes silently.
2. **`handle_messages()` must be drained.** Bytes delivered by `NetHandler::bytes()` arrive on the document's tx as `DocumentEvent::ResourceLoad`. Without `inner.handle_messages()` after `initial_build()` and after each `doc.poll()`, fetched bytes never reach `special_data` on the `<img>` node and `paint_scene` emits nothing for it.
3. **SVGs render as black squares.** Blitz/vello's SVG path produces black squares for many real app icons (gnome-icons especially). Workaround: pre-rasterize SVGs to fixed-size PNGs at icon-resolve time using `resvg` + `tiny-skia`. Done in `icons.rs::build_data_url`.
4. **CSS `border-radius` triggers NaN paths in `vello_common::flatten` on the CPU path.** Avoided by removing all `border-radius` from the dock's CSS. Probably worth filing upstream once we have a minimal repro.
5. **Render path picks GPU by default**, falls back to CPU on `vello::Renderer::new` failure or when `DIOXUS_SHELL_RENDER=cpu`. CPU path uses `anyrender_vello_cpu::VelloCpuScenePainter` → `Pixmap` → `Queue::write_texture`. Both paths converge at `TextureBlitter::copy` → swapchain.
6. **Test fixtures live in `tests/fixtures/`.** Real Brave / Wezterm / Nautilus icons are embedded via `include_bytes!` into integration tests so the image pipeline can be exercised in the Nix sandbox without `/run/current-system/...` access.

## Critical files for the next session

- `/etc/nixos/pkgs/dioxus-shell/PROJECT.md` — this file
- `/etc/nixos/pkgs/dioxus-shell/Cargo.toml` — version pins
- `/etc/nixos/pkgs/dioxus-shell/default.nix` — outputHashes for git deps
- `/etc/nixos/pkgs/dioxus-shell/src/wayland/shell.rs` — main State, foreign_toplevel, seat/pointer dispatch, focus_existing
- `/etc/nixos/pkgs/dioxus-shell/src/wayland/surface.rs` — BarSurface + DockSurface lifecycle
- `/etc/nixos/pkgs/dioxus-shell/src/wayland/toplevel.rs` — raw foreign_toplevel protocol
- `/etc/nixos/pkgs/dioxus-shell/src/ui/dock_app.rs` — dock root component, AppGroup grouping
- `/etc/nixos/pkgs/dioxus-shell/src/ui/icons.rs` — icon resolution, exec_for, SVG → PNG rasterizer
- `/etc/nixos/pkgs/dioxus-shell/src/ui/net_provider.rs` — NetProvider (data: + file:)
- `/etc/nixos/pkgs/dioxus-shell/src/ui/mod.rs` — Ui struct (dual GPU/CPU paint), launch_app, app_id_at hit-test
- `/etc/nixos/pkgs/dioxus-shell/src/render/renderer.rs` — VelloBackend GPU/CPU dispatch
- `/root/.claude/plans/can-we-change-from-inherited-sun.md` — original plan

## Verification checklist (after any change)

```bash
cd /etc/nixos
git add pkgs/dioxus-shell                     # flake won't see untracked files
nix build .#packages.x86_64-linux.dioxus-shell
./result/bin/dioxus-shell                     # inside MangoWC: visible bar at top
nix flake check --no-build                    # confirms NixOS configs still evaluate
```

`bar = "waybar"` is the default — never set `bar = "dioxus"` in `hosts/nixos/configuration.nix` until clock+all widgets reach parity.

## Effort estimate

Original plan: **3–6 focused weeks**, ~3,200–4,000 lines of Rust. Through end of dock click-to-launch + cycling we're at roughly 1,500 lines + 350 lines of tests, so somewhere between 30–40% of the original budget consumed. Remaining big items:

- **Dock pinning + config + hot-reload** — small, ~1 day. Next milestone.
- **Auto-hide animation** — needs frame-callback driven slide animation. ~1 day on real GPU; CPU path will be slow.
- **Magnification on hover** — needs per-pointer-motion repaints + scale transform calculation. ~2 days.
- **Right-click context menu via xdg_popup** — separate Blitz document, click-outside dismissal. ~2–3 days.
- **Theme switcher overlay** — third layer-shell surface, theme JSON config. ~3 days.
- **Keybindings cheatsheet overlay** — fourth layer-shell surface, mostly static text. ~1 day.
- **`/tmp/quickshell-command` IPC** — `notify` watcher driving overlay toggle. ~half a day.
- **Multi-monitor side-table** + general polish — ~1 day.

Total remaining: roughly 2 focused weeks. On track with the original estimate.

## Next milestone — right-click pin/unpin

Goal: let the user manage the dock without manually editing `dock.toml`. Right-click a tile → small context menu with "Pin" or "Unpin" + "Quit" (close all windows of that app). Click outside dismisses.

Two implementation paths:

**A. Inline overlay menu** — render the menu *inside* the dock surface, anchored above the clicked tile. Done with rsx + a `use_signal(Option<MenuState>)` showing/hiding it. Pros: zero new Wayland plumbing. Cons: menu can't extend beyond the dock surface (and the dock is only 56px tall — tight). Limited to a single row of buttons but works for "Pin/Unpin" + "Close".

**B. xdg_popup** — proper Wayland popup, can extend off the dock surface, can be larger and styled freely. SCTK 0.19 supports `LayerSurface::get_popup`. We'd need a second `Renderer` + Dioxus instance for the popup's content. Click-outside dismissal is manual (no auto-grab on layer-shell popups; we handle it in pointer events). More work but the polished answer.

**Recommendation: start with A, iterate to B.** Inline overlay gets right-click pin/unpin in front of the user fast; the xdg_popup version becomes Phase D's foundation when we also need it for the theme switcher overlay anyway.

For pin/unpin: read `dock.toml`, mutate `pinned`, write atomically (write to `dock.toml.tmp`, rename). The notify watcher picks it up automatically and reloads. No need for any in-memory state — file is the source of truth.

Code shape:

```rust
// src/config.rs
impl Config {
    pub fn save_to(&self, path: &Path) -> Result<()> {
        let parent = path.parent().context("no parent")?;
        std::fs::create_dir_all(parent).ok();
        let s = toml::to_string_pretty(self)?;
        let tmp = path.with_extension("toml.tmp");
        std::fs::write(&tmp, s)?;
        std::fs::rename(&tmp, path)?;  // atomic on the same fs
        Ok(())
    }
}

// State
pub fn toggle_pinned(&self, app_id: &str) {
    let path = match Config::default_path() { Some(p) => p, None => return };
    let mut cfg = self.config_rx.borrow().clone();
    if let Some(i) = cfg.pinned.iter().position(|a| a == app_id) {
        cfg.pinned.remove(i);
    } else {
        cfg.pinned.push(app_id.to_string());
    }
    let _ = cfg.save_to(&path);  // notify reload picks it up
}
```

Phase ordering after this: C (auto-hide + magnification + animations) → xdg_popup-based overlays for D (theme switcher + keybindings cheatsheet + IPC). Auto-hide + magnification need per-pointer-motion repaints which is its own architectural piece.

## Lessons learned (worth knowing for later sessions)

- **Don't trust crates.io versions for bleeding-edge Dioxus.** `dioxus-native-dom` on crates.io is a release behind blitz HEAD. We pin to git SHAs.
- **`[patch.crates-io]` is required to dedupe transitive crates.** `debug_timer` and `anyrender` were each pulled twice (registry + git) until we patched them. The symptom is `cargo-vendor-dir` builder failing with "permission denied creating symlink" — really a "destination already exists" error.
- **Every git dep needs an `outputHashes` entry**, including transitive ones the lockfile picks up after `cargo update`. The error message tells you the missing crate name. Re-run `nix-prefetch-git` only on rev change; one hash covers all crates from the same workspace SHA.
- **stylo wants python3 at build time.** Discovered the hard way; documented in `default.nix`.
- **wgpu 22 → 28 API breaks**: see commit history of `src/render/renderer.rs`. Big ones: `Instance::new` takes `&InstanceDescriptor`; `request_adapter` returns `Result`, not `Option`; `DeviceDescriptor` has `experimental_features` and `trace`; `RenderPassColorAttachment` has `depth_slice`; `RenderPassDescriptor` has `multiview_mask: Option<NonZero<u32>>`; `request_device` lost the `trace_path` argument; `HandleError` no longer impls `std::error::Error` so `?` doesn't work, must `.map_err(|e| anyhow!("{e}"))`.
