# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A single Nix flake that configures three classes of machine from one source tree:

- **NixOS** hosts (full system config) — `nixosConfigurations.<hostname>` in `flake.nix`
- **macOS** hosts via nix-darwin — `darwinConfigurations.<hostname>`
- **Standalone Home Manager** on non-NixOS Linux (e.g. CachyOS, generic dev VMs) — `homeConfigurations."<user>@<hostname>"`

The same Home Manager modules are reused across all three; the host layer differs.

## Common commands

`rebuild.sh` (also installed system-wide as the `rebuild` command via `lib/rebuild-script.nix`, included by `modules/common/`) auto-detects the system type and dispatches to the right tool. **Always prefer `./rebuild.sh` over calling `nixos-rebuild` / `darwin-rebuild` / `home-manager` directly** — the script picks the correct flake attribute name (bare hostname for NixOS/darwin, `$USER@$HOSTNAME` for standalone home-manager) and handles sudo only where needed.

```
./rebuild.sh                  # switch (default)
./rebuild.sh full             # nix flake update, then switch
./rebuild.sh update           # nix flake update
./rebuild.sh update-dotfiles  # update only the dotfiles input
./rebuild.sh check            # nix flake check
./rebuild.sh test             # NixOS only — build without activating
./rebuild.sh boot             # NixOS only — stage for next boot
./rebuild.sh clean            # interactive generation pruning + GC
```

`switch`/`test`/`boot`/`full` warn on a dirty git tree and prompt before continuing.

System detection in `rebuild.sh`: `$OSTYPE == darwin*` → darwin; `/etc/os-release` ID=cachyos → home-manager; `/etc/NIXOS` exists → NixOS; otherwise → standalone home-manager. The flake attribute selected is `$HOSTNAME` for NixOS/darwin and `$USER@$HOSTNAME` for the home-manager paths — so when you add a new machine, the entry name in `flake.nix` must match exactly.

## Architecture

The codebase has two parallel option layers and a strict separation of concerns between them:

| Layer | Options namespace | Declared in | Consumed by |
|---|---|---|---|
| System (NixOS/darwin) | `mySystem.*` | `options.nix` | `modules/**/*.nix` |
| Home Manager (any context) | `myHome.*` | `home/options.nix` | `home/modules/**/*.nix` |

Both layers follow the same pattern: hosts/users *set* flags; modules read flags via `lib.mkIf` / interpolation and contribute their config conditionally.

### `mySystem.*` (system layer)

`options.nix` declares enable flags like `mySystem.desktop.mangowc`, `mySystem.gaming.steam`, `mySystem.networking.tailscale`. Modules under `modules/` follow:

```nix
config = lib.mkIf config.mySystem.<area>.<feature> { ... };
```

`hosts/nixos/configuration.nix` and `hosts/macbookpro/configuration.nix` import `options.nix` + the relevant modules and set the flags. **To add a new system-level feature: declare the option in `options.nix`, gate its module with `lib.mkIf`, and turn it on in the host config.** Don't add unconditional config to a feature module — it breaks the multi-host model.

`mySystem.desktop.bar` (`"waybar" | "quickshell" | "dioxus"`) picks which status bar the desktop modules wire up. `"dioxus"` is experimental — see `pkgs/dioxus-shell/PROJECT.md` for the in-progress port that's replacing Quickshell.

### `myHome.*` (home-manager layer)

`home/options.nix` declares `myHome.identity.{name,email,sshKey}`, `myHome.sops.{enable,ageKeyFile}`, `myHome.dev.enable`, `myHome.apps.{bitwarden,wezterm,moonlight,clipboard}`, `myHome.kube.enable`. Modules under `home/modules/` consume these and contribute packages / files / `programs.*` config. Each module is small and focused (~10–25 lines).

`home/modules/default.nix` is **"the default everyone implements"** — it imports the full module stack (`options.nix`, `dotfiles-base`, `tmux`, `shell`, `programs`, `git`, `ssh`, `sops`, `dev`, `apps`, `kube`). Per-host home files do `imports = [ ./modules ];` and just set the flags. The exception is `home/root.nix`, which imports only specific leaf modules — it deliberately skips `programs.nix` because root doesn't enable neovim/fzf/zoxide/bash.

`myHome.*` is a separate namespace from `mySystem.*` because home configs evaluate in *two* contexts:

1. **Embedded in NixOS/darwin** (e.g. `home/gamzat.nix`, `home/gamzat-darwin.nix`, `home/root.nix`). Can read `osConfig.mySystem.*`. The bridge module `home/profiles/from-os-config.nix` translates `osConfig.mySystem.*` toggles into `myHome.apps.*` so the home modules don't need to know which context they're in.
2. **Standalone Home Manager** (e.g. `home/gamzat-shared.nix`, `home/maga-dev.nix`). No `osConfig` exists here.

Because `myHome.*` is declared at the home layer, it works in both contexts. Avoid reading `osConfig.mySystem.*` directly from a home module — go through `myHome.*` instead so the same module compiles in either context.

### Composing per-host home configs

Per-host home files (e.g. `home/maga-dev.nix`) are now thin (~20–40 lines). They import:

- `./modules` — the full home stack (always)
- `./identities/<name>.nix` — name/email/sshKey/sops paths for a known user (if applicable)
- `./profiles/<bundle>.nix` — opinionated `myHome.*` presets

Profiles available:
- `profiles/desktop-apps.nix` — turns on the four user-facing apps (bitwarden/wezterm/moonlight/clipboard)
- `profiles/dev-vm.nix` — extends `desktop-apps` with `dev.enable` + the maga/marv-dev shared package list
- `profiles/from-os-config.nix` — bridges `osConfig.mySystem.*` to `myHome.apps.*` (NixOS/darwin embeds only)

Identities available: `identities/gamzat.nix` (auto-detects darwin path via `config.home.homeDirectory`).

### `modules/common/` (system layer)

`modules/common/default.nix` holds settings that are identical across NixOS and darwin: `nixpkgs.config.allowUnfree`, `nix.settings.experimental-features`, and the `rebuild` script. Both host configs import it.

### Where dev tooling lives

LSPs, compilers, and AI CLIs (`claude-code`, `gemini-cli`, `opencode`) are **user-level** — installed via `myHome.dev.enable = true` in the home config plus inline extras for per-host variants (e.g. `rustup`/`dioxus-cli` on the NixOS host, `bun`/`python3`/`typescript` on darwin). General CLI utilities (git/neovim/ripgrep/fzf/tmux/wget/curl/jq/htop/fd) stay at system level so sudo workflows (e.g. `sudo git pull`, `sudo vim /etc/...`) keep working. Don't add LSPs back to `environment.systemPackages` — they don't help sudo and they bloat the system closure.

### specialArgs / flake inputs as module args

`flake.nix` threads several inputs through `specialArgs` and `home-manager.extraSpecialArgs`:

- `dotfiles` — the `xXNaVeEXx/dotfiles` repo as a non-flake input. Referenced as `${dotfiles}/nvim`, `${dotfiles}/zsh/.zshrc`, etc., via `home.file."...".source = "${dotfiles}/..."`. Update with `./rebuild.sh update-dotfiles`.
- `mangowc`, `quickshell` — consumed by `modules/desktop/mangowc.nix`.
- `sops-nix` — wired in as a darwin system module and as a `home-manager.sharedModules` entry. **Note:** there's no system-level sops-nix on the NixOS host yet (k3s tokenFile is provisioned out-of-band; see the comment block in `hosts/nixos/configuration.nix` for the migration recipe).

When adding a new flake input that a module needs: (a) add to the input set, (b) add to the `outputs` argument list, (c) thread via `specialArgs`/`extraSpecialArgs`.

`flake.nix` defines a `mkHomeLinux` helper that wraps the boilerplate for `homeConfigurations` entries. Multiple host names can alias to the same home file (`gamzat@cachyos` and `gamzat@cachydeck` share `cachyHome`; `gamzat@shared` and `gamzat@gamzat-dev` share `sharedHome`).

### Hosts and root-level symlinks

`configuration.nix` and `hardware-configuration.nix` at the repo root are symlinks into `hosts/nixos/`. Don't replace them with regular files — the symlinks let `/etc/nixos -> this repo` work for the system auto-upgrade path (`system.autoUpgrade.enable = true` in `hosts/nixos/configuration.nix`).

### `pkgs/dioxus-shell/` — in-progress Quickshell replacement

A Rust desktop shell for MangoWC, built with `smithay-client-toolkit` + `wgpu` + Dioxus + Blitz + Vello. Lives inline at `pkgs/dioxus-shell/` and is exposed as `packages.x86_64-linux.dioxus-shell` from `flake.nix`. Wired into `modules/desktop/mangowc.nix` as the third `bar` enum value alongside `waybar`/`quickshell`. Default is still `"waybar"` — nothing on the live desktop changes until someone explicitly opts in.

State (May 2026): top bar with 5 widgets (clock, window title, tag indicators, system info, wlan) is feature-complete. Bottom dock is feature-complete except pinning, animation polish, and right-click menus — it shows real macOS-style icons for every running app, collapses multiple windows of the same app to a single tile with a count badge, and clicks cycle through windows via foreign_toplevel `activate`. 30+ unit/integration tests cover icon resolution, the data-URL pipeline, the SVG → PNG pre-rasterizer, and the end-to-end render path.

**Read `pkgs/dioxus-shell/PROJECT.md` before touching this code.** It's the canonical state doc: what's done, what's next, version pins, the dual GPU/CPU rendering paths, why we're not using `dioxus-native`/`anyrender_vello::VelloWindowRenderer`/`blitz-renderer-vello`, the `<img>` rendering quirks (NetProvider must handle `data:`, `handle_messages()` must drain, SVGs need pre-rasterization), and the next-milestone recipe. The original plan is at `/root/.claude/plans/can-we-change-from-inherited-sun.md`.

### Wallpapers and runtime configs

`modules/desktop/configs/{quickshell,mango,mako,swaylock}` hold runtime configs that get symlinked into `~/.config/...` from the NixOS-embedded home configs (gated on `osConfig.mySystem.desktop.mangowc`). Edits to these files take effect after `rebuild.sh switch`.

`modules/desktop/configs/wallpapers/` holds vendored wallpaper images referenced as path literals from `modules/desktop/mangowc.nix`. They're committed binaries (~3 MB total) — don't replace them with `pkgs.fetchurl` URLs again; the previous Unsplash/wallpaperflare links rotted.

## Secrets

`secrets/` is gitignored. Home-manager-level secrets are managed via sops-nix with an age key at `~/.config/sops/age/key.txt` (path differs on darwin: `/Users/gamzat/.config/sops/age/key.txt`). The `defaultSopsFile` is `secrets/secrets.yaml`. Don't commit anything under `secrets/`, and don't paste decrypted values into Nix files.

The k3s join token (`secrets/k3s-token.key`) is currently provisioned out-of-band — not under sops-nix at the system layer. Migration recipe is documented in `hosts/nixos/configuration.nix` near the `services.k3s` block.

## Adding a new standalone Home Manager target

1. Create `home/<name>.nix` (~20 lines) — set `home.username`, `home.homeDirectory`, `home.stateVersion`, `programs.home-manager.enable`, identity (or import an existing one from `home/identities/`), and pick a profile from `home/profiles/` if one fits. `imports = [ ./modules ];` brings in the full home stack.
2. Add a `homeConfigurations."<user>@<hostname>" = mkHomeLinux ./home/<name>.nix;` entry in `flake.nix`.
3. Run `./rebuild.sh` on the target machine — it derives the flake attribute name from `$USER@$(hostname)`, so the entry name in `flake.nix` must match exactly.

For an existing user on a new host pointing at the same module, just add another `homeConfigurations` entry aliasing the same `mkHomeLinux ./home/<file>.nix` value.
