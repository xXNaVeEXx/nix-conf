# Pi Coding Agent: binary + bidirectional sync of ~/.pi/agent config over the
# dotfiles repo (pi/ subtree). Direction: local -> clone -> git -> clone -> local.
{
  config,
  lib,
  pkgs,
  pi,
  ...
}:

let
  cfg = config.myHome.pi;
  cloneDir = "${config.home.homeDirectory}/projects/dotfiles";
  agentDir = "${config.home.homeDirectory}/.pi/agent";

  # The synced slice of ~/.pi/agent. node_modules (extensions) is a regenerable
  # symlink farm; hermes-mind syncs only the three curated files.
  piSync = pkgs.writeShellScriptBin "pi-sync" ''
    set -euo pipefail
    PATH="${lib.makeBinPath (with pkgs; [ rsync git coreutils python3 ])}:$PATH"
    CLONE="${cloneDir}"
    AGENT="${agentDir}"
    SRC="$CLONE/pi"

    mkdir -p "$AGENT/skills" "$AGENT/extensions" "$AGENT/hermes-mind"

    # 1. Clone on first run. FRESH marker forces pull-only mode below so a
    #    pristine machine can never push its empty state over the repo.
    FRESH=0
    if [ ! -d "$CLONE/.git" ]; then
      git clone --depth 1 git@github.com:xXNaVeEXx/dotfiles.git "$CLONE" || exit 0
      FRESH=1
    fi

    # 2. Freshen the clone; if it diverged (e.g. an earlier failed push left
    #    an unpushed commit), realign it hard to origin/main.
    git -C "$CLONE" fetch origin main >/dev/null 2>&1 || true
    if [ "$(git -C "$CLONE" rev-parse HEAD 2>/dev/null)" != "$(git -C "$CLONE" rev-parse origin/main 2>/dev/null)" ]; then
      git -C "$CLONE" reset --hard origin/main >/dev/null 2>&1 || true
    fi

    # 3. Decide direction: pull-only when local has nothing to contribute
    #    (fresh machine) — never let an empty machine wipe the repo.
    LOCAL_SKILLS=$(ls -A "$AGENT/skills" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$FRESH" = 1 ] || [ "$LOCAL_SKILLS" = "0" ]; then
      MODE=pull
    else
      MODE=push
      # Self-heal: clone lost skills/ (broken history) -> recreate from local.
      [ -d "$SRC/skills" ] || mkdir -p "$SRC/skills"
    fi

    if [ "$MODE" = push ]; then
      # 4a. Push local state into the clone (mirror, incl. deletions).
      for f in AGENTS.md settings.json keybindings.json; do
        [ -f "$AGENT/$f" ] && rsync -a "$AGENT/$f" "$SRC/$f"
      done
      rsync -a --delete --exclude '__pycache__' "$AGENT/skills/" "$SRC/skills/"
      rsync -a --delete --exclude node_modules --exclude '*.log' \
        --exclude '__pycache__' "$AGENT/extensions/" "$SRC/extensions/"
      for f in MEMORY.md USER.md config.json; do
        [ -f "$AGENT/hermes-mind/$f" ] && rsync -a "$AGENT/hermes-mind/$f" "$SRC/hermes-mind/$f"
      done

      # 4b. Commit + push (tolerant: next run retries).
      git -C "$CLONE" add pi/
      if ! git -C "$CLONE" diff --cached --quiet; then
        git -C "$CLONE" commit -q -m "chore(pi): auto-sync agent state" || true
      fi
      git -C "$CLONE" push origin main >/dev/null 2>&1 || true
    fi

    # 5. Pull clone state back over local (source of truth after step 4).
    if [ -d "$SRC" ]; then
      for f in AGENTS.md settings.json keybindings.json; do
        [ -f "$SRC/$f" ] && rsync -a "$SRC/$f" "$AGENT/$f"
      done
      if [ -d "$SRC/skills" ]; then
        rsync -a --delete --exclude '__pycache__' "$SRC/skills/" "$AGENT/skills/"
      fi
      if [ -d "$SRC/extensions" ]; then
        rsync -a --delete --exclude node_modules --exclude '*.log' \
          "$SRC/extensions/" "$AGENT/extensions/"
      fi
      for f in MEMORY.md USER.md config.json; do
        [ -f "$SRC/hermes-mind/$f" ] && rsync -a "$SRC/hermes-mind/$f" "$AGENT/hermes-mind/$f"
      done
    fi

    # 6. First-run package install on a fresh machine.
    if [ ! -d "$HOME/.pi/agent/npm/node_modules" ] && [ -f "$AGENT/settings.json" ]; then
      PI_BIN="$(command -v pi || true)"
      if [ -n "$PI_BIN" ]; then
        for pkg in $(python3 -c "import json; print(' '.join(p for p in json.load(open('$AGENT/settings.json')).get('packages', []) if p.startswith('npm:')))" 2>/dev/null); do
          "$PI_BIN" install "$pkg" >/dev/null 2>&1 || true
        done
      fi
    fi
  '';
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      pi.packages.${pkgs.system}.default
      piSync
      pkgs.rsync
    ];

    # First pull on a fresh machine (or after nuking ~/.pi).
    home.activation.piSyncBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${agentDir}/skills" ] || [ -z "$(ls -A "${agentDir}/skills" 2>/dev/null)" ]; then
        $DRY_RUN_CMD ${piSync}/bin/pi-sync || true
      fi
    '';

    systemd.user = lib.mkIf pkgs.stdenv.isLinux {
      services.pi-sync = {
        Unit = {
          Description = "Sync ~/.pi/agent config with dotfiles repo";
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${piSync}/bin/pi-sync";
        };
      };
      timers.pi-sync = {
        Unit = {
          Description = "Run pi-sync every 20 minutes";
        };
        Timer = {
          OnBootSec = "3min";
          OnUnitActiveSec = "20min";
        };
      };
    };

    # macOS: LaunchAgent instead of systemd (same 20-minute cadence).
    launchd.agents.pi-sync = lib.mkIf pkgs.stdenv.isDarwin {
      enable = true;
      config = {
        Label = "com.gamzat.pi-sync";
        ProgramArguments = [ "${piSync}/bin/pi-sync" ];
        RunAtLoad = true;
        StartInterval = 1200;
        StandardErrorPath = "/tmp/pi-sync.err";
      };
    };

    # home-manager's WantedBy shortcut is not available for timers in this
    # version, so enable+start explicitly after the unit files are written.
    home.activation.piSyncTimer = lib.hm.dag.entryAfter [ "piSyncBootstrap" ] ''
      $DRY_RUN_CMD systemctl --user daemon-reload || true
      $DRY_RUN_CMD systemctl --user enable --now pi-sync.timer >/dev/null 2>&1 || true
    '';
  };
}
