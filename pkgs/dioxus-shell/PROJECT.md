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

**Next milestone: per-frame redraw loop.** Currently the bar paints once on `configure` and never again — the clock shows the startup time forever. Need to wire `wl_surface::frame` callbacks so the bar repaints once per second (or whenever the Dioxus VDOM diff changes the rendered output). Recipe in [§ The next milestone](#the-next-milestone--per-frame-redraw-loop) below.

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
├── Cargo.toml                  — wgpu=28, sctk=0.19, full Dioxus/Blitz/Vello stack
├── Cargo.lock
├── default.nix                 — buildRustPackage + wrapProgram + python3 (for stylo)
├── PROJECT.md                  — this file
└── src/
    ├── main.rs                 — entry: env_logger init, Shell::new()?.run()
    ├── wayland/
    │   ├── mod.rs              — pub use shell::Shell
    │   ├── shell.rs            — SCTK Shell + State; CompositorHandler, OutputHandler,
    │   │                         LayerShellHandler, ProvidesRegistryState. Hardcodes
    │   │                         BAR_HEIGHT=32, Layer::Top, anchor TOP|LEFT|RIGHT.
    │   │                         OutputHandler::new_output creates one bar per output;
    │   │                         the explicit roundtrip-then-iterate loop was removed
    │   │                         after it caused duplicate bars (every output got two).
    │   └── surface.rs          — BarSurface: owns LayerSurface + Renderer; configure()
    │                             initializes renderer on first call, resizes on later calls.
    │                             output() returns None — TODO: side-table for multi-monitor.
    ├── ui/
    │   └── mod.rs              — Ui struct: holds DioxusDocument + width/height. paint(scene,
    │                             now_secs) calls resolve() then paint_scene(). app() returns
    │                             rsx with embedded <style> for layout. Uses dioxus::prelude
    │                             (umbrella crate, NOT dioxus_core directly — rsx! macro lives
    │                             in dioxus_core_macro re-exported through dioxus).
    └── render/
        ├── mod.rs              — pub use renderer::Renderer
        └── renderer.rs         — wgpu Renderer. Owns vello::Renderer, intermediate Rgba8Unorm
                                  texture (STORAGE_BINDING|TEXTURE_BINDING), TextureBlitter,
                                  and a Ui. render() calls ui.paint(&mut scene, elapsed_secs)
                                  → vello.render_to_texture(intermediate) → blitter.copy
                                  (intermediate → swapchain) → present. Surface format is
                                  non-sRGB (vello applies its own gamma).
                                  RawWaylandTarget bridges SCTK pointers to raw-window-handle 0.6.
```

Roughly 500 lines of Rust now.

## Known gaps

These are intentional debt; address as the relevant feature lands:

1. **No `wl_surface::frame` callbacks (clock is frozen).** Bar paints once on configure with the startup time and never updates. This is the **next milestone** — see below.
2. **`BarSurface::output()` returns `None`.** SCTK 0.19's `LayerSurface` doesn't expose its output. Fix when multi-monitor matters: keep a `Vec<(LayerSurface, WlOutput)>` side-table in `State` instead of relying on `BarSurface::output()`.
3. **One `Ui` per `BarSurface`, but the VirtualDom doesn't share state across bars.** Each output gets an independent Dioxus app instance. For per-output state (e.g. focused window title) this is correct; for global state (clock, theme) it's wasteful. Acceptable for now; revisit when overlays land.
4. **`environment.etc."xdg/dioxus-shell"` not wired.** Plan said to add it; deferred until a widget actually needs config files (theme JSON, keybindings text). Drop in `mangowc.nix` near line 502 when needed.
5. **`xdg/quickshell-wallpapers.json`** still under that path. Generalize to `xdg/desktop-wallpapers.json` when the dioxus shell needs it.
6. **`home/gamzat.nix:45–48`** still symlinks `~/.config/quickshell` redundantly. Plan said to drop it; deferred — non-load-bearing.
7. **wgpu chatter on llvmpipe.** Each frame logs `Device::maintain: waiting for submission index N` at INFO. Add a default `RUST_LOG` filter in `main.rs` (`dioxus_shell=info,wgpu_core=warn,wgpu_hal=warn`).

## The next milestone — per-frame redraw loop

The clock currently shows the startup time. To make it tick we need:

1. **Request frame callbacks.** In `BarSurface::configure()` (after `r.render()?` succeeds), request the next frame via `self.layer.wl_surface().frame(qh, self.layer.wl_surface().clone())`. This needs a `&QueueHandle<State>` threaded down from `Shell` — currently `BarSurface` doesn't have one. Easiest: stash the `QueueHandle` in `State` and pass to `BarSurface::configure(qh, ...)` via a new arg. Or store the qh on `BarSurface` at construction time (cheap to clone).

2. **In `CompositorHandler::frame`,** drive the next render: find the matching bar by `WlSurface` identity (already does this), call `bar.on_frame()` which now does `bar.render()` and requests another frame. Throttle: only re-render if `chrono::Local::now().second()` changed since the last drawn second — store `last_drawn_second: Option<u32>` on `BarSurface`.

3. **Trigger Dioxus to re-render the rsx tree.** The clock value is computed once inside `app()` at `initial_build()` time; subsequent `paint()` calls just re-paint the same DOM. We need to either:
   - **Easiest**: invalidate the signal each tick from outside Dioxus. But signals are inside the VirtualDom's runtime; touching them from `paint()` is awkward.
   - **Better**: store the clock as a `Signal<String>` set inside an effect with a `tokio::time::interval` — but that requires running an async runtime, which we don't have.
   - **Pragmatic**: skip Dioxus state for the clock entirely. Have `Ui::paint(scene, now_secs)` walk the BaseDocument directly to find the `.right` element and update its text via `mutate()`. Or: add `Ui::set_clock(text)` that runs the diff manually before `paint()`. This is hacky but works without an async runtime.
   - **Most correct**: stand up a `tokio::runtime::Builder::new_current_thread()` runtime, run `vdom.wait_for_work()` between frames in a non-blocking way, and let Dioxus drive the diff via `vdom.render_immediate(&mut MutationWriter)`. This is what `dioxus-native`'s `BlitzApplication` does. See `examples/wgpu_texture/src/dioxus_native.rs` for the pattern. Cost: tokio dep (~30 crates) and an event-loop integration story.

   **Recommendation**: start with the pragmatic option (mutate BaseDocument text directly on each tick), prove the redraw loop works, then revisit the architecture when the second widget needs reactive state.

4. **`wl_surface::frame` requires a `QueueHandle`.** SCTK doesn't auto-store one on the surface. Pattern:
   ```rust
   bar.layer.wl_surface().frame(qh, bar.layer.wl_surface().clone());
   bar.layer.commit();  // frame requests need a commit to be sent
   ```
   The user-data passed in (`bar.layer.wl_surface().clone()`) is what arrives in `CompositorHandler::frame`'s `surface` parameter, so we use it to identify which bar to redraw.

5. **Stop animating when we have nothing to do.** If `last_drawn_second == current_second && !dirty_for_other_reasons`, skip the render entirely but still request another frame (otherwise the compositor stops calling us back). On the Proxmox VM (llvmpipe), this matters — naive 60Hz redraws of static text would peg a CPU core.

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
