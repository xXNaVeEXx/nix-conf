{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  quickshellConfigDir = ../modules/desktop/configs/quickshell;
in

{
  imports = [
    ./modules
    ./identities/gamzat.nix
    ./profiles/from-os-config.nix
  ];

  home.stateVersion = "25.11";

  home.sessionVariables = {
    XDG_RUNTIME_DIR = "/run/user/1000";
    WAYLAND_DISPLAY = "wayland-0";
  };

  myHome = {
    kube.enable = true;
    dev.enable = true;
  };

  home.packages = with pkgs; [
    opencloud-desktop

    # AI tooling
    claude-code
    gemini-cli
    opencode

    # Build tools beyond the dev base
    rustup
    dioxus-cli
  ];

  # Quickshell config — only when MangoWC compositor is the active session
  home.file.".config/quickshell" = lib.mkIf osConfig.mySystem.desktop.mangowc {
    source = quickshellConfigDir;
    recursive = true;
  };
}
