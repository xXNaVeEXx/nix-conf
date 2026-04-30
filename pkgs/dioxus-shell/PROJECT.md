# dioxus-shell — project state and decisions

This file is the canonical hand-off doc for whoever (human or model) picks this up next session. Read it before touching code. The plan in `/root/.claude/plans/can-we-change-from-inherited-sun.md` is the original spec; this file records what survived contact with reality.

## Goal

Replace Quickshell (~2,310 lines of QML across 24 files in `modules/desktop/configs/quickshell/`) with a Rust-based desktop shell for MangoWC. Full functional parity: top bar (3 islands), bottom auto-hiding dock, theme switcher overlay, keybindings cheatsheet overlay, IPC via `/tmp/quickshell-command`, multi-monitor.

Roll out as opt-in `mySystem.desktop.bar = "dioxus"` alongside existing `waybar` and `quickshell` enum values. Remove Quickshell wiring only after parity.

## Status (April 2026)

**Skeleton milestone: complete.** Bar surface created via `wlr-layer-shell`, painted via wgpu, anchored top, exclusive zone reserved. Verified visually inside MangoWC on a Proxmox VM (no GPU; falls back to llvmpipe). Currently paints a solid dark-slate rectangle and nothing else.

**Dependency milestone: complete.** Full Dioxus + Blitz + Vello + stylo stack compiles in Nix against the SCTK-owned wgpu surface. wgpu bumped 22 → 28 cleanly.

**Vello milestone: complete.** Vello renders into an intermediate `Rgba8Unorm` storage texture via compute shader, then `wgpu::util::TextureBlitter` blits to the swapchain. Surface format is non-sRGB (`Bgra8Unorm` or `Rgba8Unorm`) — Vello applies its own gamma. Verified visually inside MangoWC.

**Dioxus + Blitz integration milestone: complete.** `src/ui/mod.rs` builds a `VirtualDom` + `DioxusDocument` + `DEFAULT_CSS` + custom flexbox stylesheet, runs `initial_build()`, and per-frame calls `inner.resolve(now_secs)` + `blitz_paint::paint_scene(VelloScenePainter, doc, ...)` to populate a `vello::Scene`. The renderer hands the resulting scene to `vello::Renderer::render_to_texture`. First widget: a 32px bar with "dioxus-shell" on the left and `HH:MM:SS` on the right, both styled via `<style>` block embedded in the rsx. Verified visually.

**Reactive redraw loop milestone: complete.** A `tokio::runtime::Builder::new_current_thread().enable_time()` runtime drives `use_future` hooks. `Ui::poll()` enters the runtime, `block_on(yield_now())` to advance pending tasks, then calls `DioxusDocument::poll(cx)` with a `DirtyWaker` that flips an atomic flag when any Dioxus signal fires. The clock is implemented as a `Signal<String>` updated every second by a `tokio::time::interval`. The Wayland event loop was rewritten on top of `calloop::EventLoop` with `WaylandSource` + a 100ms `Timer` that drives `Ui::poll()` and re-renders only when the dirty flag was set. Idle CPU on llvmpipe-on-Proxmox is ~4% (down from ~13% in the unconditional 60Hz draft). Verified visually: the clock ticks every second.

**Next milestone: a real second widget.** The clock proves the integration; now we need something with non-trivial state to validate the architecture under load. Candidates from the Quickshell port-table in this file: tag indicators (poll `mangoctl get-active-tag`), window title (poll `mangoctl get-active-window-title`), or wlan status (parse `nmcli -t`). All three exercise the same shape — a `use_future` running an external command on an interval, setting a signal, Dioxus diffing the rsx output, Blitz re-laying out, Vello re-painting only the changed regions (well — the whole bar; per-rect damage is later).

`mySystem.desktop.bar` defaults to `"waybar"`; the live desktop is unaffected by anything in this crate.

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
- `anyrender-0.8.0`, `anyrender_vello-0.8.0`, `wgpu_context-0.4.0` — all from `DioxusLabs/anyrender @ c12e3ff…`, hash `sha256-rNl0YxDdFCgLuF1w0gv+EvHfuz3p/b/M6Nu24FIdPXg=`.

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
│                                 tokio (rt+time+macros+sync), calloop, calloop-wayland-source
├── Cargo.lock
├── default.nix                 — buildRustPackage + wrapProgram + python3 (for stylo)
├── PROJECT.md                  — this file
└── src/
    ├── main.rs                 — entry: env_logger init, Shell::new()?.run()
    ├── wayland/
    │   ├── mod.rs              — pub use shell::Shell
    │   ├── shell.rs            — calloop::EventLoop driven shell. WaylandSource handles
    │   │                         all wayland events; a 100ms Timer drives Ui::poll() on
    │   │                         each bar via State::tick(). frame() callback is now a
    │   │                         no-op — calloop is the heartbeat. State holds qh so
    │   │                         tick can pass it through.
    │   └── surface.rs          — BarSurface: owns LayerSurface + Renderer. configure()
    │                             initializes renderer on first call, resizes on later
    │                             calls, paints once. tick() called from calloop timer:
    │                             renderer.tick() → if it painted, commit. output()
    │                             returns None — TODO: side-table for multi-monitor.
    ├── ui/
    │   └── mod.rs              — Ui struct: tokio current-thread runtime + DioxusDocument
    │                             + DirtyFlag waker. Ui::new() enters runtime to build
    │                             the VirtualDom (so use_future can spawn). poll() enters
    │                             runtime, runs block_on(yield_now()) to advance tokio
    │                             timers, then doc.poll(cx) to drive Dioxus. paint(scene,
    │                             now_secs) emits the painted document into a vello::Scene
    │                             via VelloScenePainter. app() uses use_future to update a
    │                             clock Signal every second. Uses dioxus::prelude (umbrella
    │                             crate; rsx! lives in dioxus-core-macro, re-exported).
    └── render/
        ├── mod.rs              — pub use renderer::Renderer
        └── renderer.rs         — wgpu Renderer. Owns vello::Renderer, intermediate
                                  Rgba8Unorm texture (STORAGE_BINDING|TEXTURE_BINDING),
                                  TextureBlitter, and a Ui. tick() returns bool: polls
                                  Dioxus, returns false fast if neither dirty flag nor
                                  DOM mutation; otherwise renders + presents.  render()
                                  calls ui.paint(&mut scene, elapsed_secs) → vello
                                  render_to_texture(intermediate) → blitter.copy(intermediate
                                  → swapchain) → present. Non-sRGB swapchain format
                                  (vello does its own gamma). RawWaylandTarget bridges
                                  SCTK pointers to raw-window-handle 0.6.
```

Roughly 700 lines of Rust now.

## Known gaps

These are intentional debt; address as the relevant feature lands:

1. **`BarSurface::output()` returns `None`.** SCTK 0.19's `LayerSurface` doesn't expose its output. Fix when multi-monitor matters: keep a `Vec<(LayerSurface, WlOutput)>` side-table in `State` instead of relying on `BarSurface::output()`.
2. **One `Ui` per `BarSurface`, with one tokio runtime each.** Each output gets an independent Dioxus app instance + tokio runtime. For per-output state (focused window title) that's correct; for global state (clock, theme) it duplicates work. Idle cost: ~4% of one core per bar on llvmpipe; on a real GPU likely <1%. Acceptable for now; consider a shared runtime if it becomes a problem.
3. **100ms tick rate is a compromise.** The calloop timer drives `Ui::poll` at 10Hz to advance tokio timers, regardless of whether anything actually changed. For the clock-only UI this is overkill — we only need to wake when the second-boundary fires. Optimization for later: query `tokio::time::Instant` for the next deadline and arm the calloop Timer for that instant instead of a fixed 100ms. Saves the polling-when-idle cost.
4. **`environment.etc."xdg/dioxus-shell"` not wired.** Plan said to add it; deferred until a widget actually needs config files (theme JSON, keybindings text). Drop in `mangowc.nix` near line 502 when needed.
5. **`xdg/quickshell-wallpapers.json`** still under that path. Generalize to `xdg/desktop-wallpapers.json` when the dioxus shell needs it.
6. **`home/gamzat.nix:45–48`** still symlinks `~/.config/quickshell` redundantly. Plan said to drop it; deferred — non-load-bearing.
7. **wgpu chatter on llvmpipe.** Each frame logs `Device::maintain: waiting for submission index N` at INFO. Add a default `RUST_LOG` filter in `main.rs` (`dioxus_shell=info,wgpu_core=warn,wgpu_hal=warn`).

## The next milestone — second real widget

The clock proved the architecture. Pick one of the Quickshell port-table widgets to validate it under non-toy load. All three follow the same shape:

```rust
// src/ui/widgets/window_title.rs
fn window_title() -> Element {
    let title = use_signal(|| String::new());
    use_future(move || {
        let mut title = title;
        async move {
            let mut interval = tokio::time::interval(Duration::from_millis(500));
            interval.set_missed_tick_behavior(MissedTickBehavior::Skip);
            loop {
                interval.tick().await;
                if let Ok(out) = tokio::process::Command::new("mangoctl")
                    .arg("get-active-window-title")
                    .output().await
                {
                    let new = String::from_utf8_lossy(&out.stdout).trim().to_string();
                    if title.read().as_str() != new.as_str() {
                        title.set(new);
                    }
                }
            }
        }
    });
    rsx!(div { class: "window-title", "{title}" })
}
```

Order: window-title is the cheapest validation (single string, low update rate, no parsing). After that the natural sequence is system info (`/proc/stat` parsing, sysinfo crate), wlan (`nmcli -t` parsing), tag indicators (5 little squares with active-state styling). Each one stresses a slightly different part: process-spawning, file-reading, parsing, multi-element rsx with conditional classes.

**Watch for**: `tokio::process::Command` requires the `process` feature. `tokio::fs` requires `fs`. Add to `Cargo.toml` only when actually used. Keep the feature set tight to keep build times reasonable (current build is ~3min cold).

## Critical files for the next session

- `/etc/nixos/pkgs/dioxus-shell/PROJECT.md` — this file
- `/etc/nixos/pkgs/dioxus-shell/Cargo.toml` — version pins live here
- `/etc/nixos/pkgs/dioxus-shell/src/render/renderer.rs` — wgpu setup; will need wgpu 28 port
- `/etc/nixos/pkgs/dioxus-shell/src/wayland/surface.rs` — where the redraw loop lives
- `/root/.claude/plans/can-we-change-from-inherited-sun.md` — original plan; see "Honest fit assessment" + "Migration / rollout order"

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

Per the original plan: **3–6 focused weeks** of work, ~3,200–4,000 lines of Rust. Skeleton + dep milestone (~250 lines + a *lot* of Cargo.toml/default.nix iteration) burned roughly the cheapest 10% of the budget. The Blitz/Vello *call-site* integration in milestone 2 is the highest-risk remaining piece — budget at least a week for it before declaring the architecture proven.

## Lessons learned (worth knowing for later sessions)

- **Don't trust crates.io versions for bleeding-edge Dioxus.** `dioxus-native-dom` on crates.io is a release behind blitz HEAD. We pin to git SHAs.
- **`[patch.crates-io]` is required to dedupe transitive crates.** `debug_timer` and `anyrender` were each pulled twice (registry + git) until we patched them. The symptom is `cargo-vendor-dir` builder failing with "permission denied creating symlink" — really a "destination already exists" error.
- **Every git dep needs an `outputHashes` entry**, including transitive ones the lockfile picks up after `cargo update`. The error message tells you the missing crate name. Re-run `nix-prefetch-git` only on rev change; one hash covers all crates from the same workspace SHA.
- **stylo wants python3 at build time.** Discovered the hard way; documented in `default.nix`.
- **wgpu 22 → 28 API breaks**: see commit history of `src/render/renderer.rs`. Big ones: `Instance::new` takes `&InstanceDescriptor`; `request_adapter` returns `Result`, not `Option`; `DeviceDescriptor` has `experimental_features` and `trace`; `RenderPassColorAttachment` has `depth_slice`; `RenderPassDescriptor` has `multiview_mask: Option<NonZero<u32>>`; `request_device` lost the `trace_path` argument; `HandleError` no longer impls `std::error::Error` so `?` doesn't work, must `.map_err(|e| anyhow!("{e}"))`.
