{
  config,
  pkgs,
  lib,
  dotfiles,
  osConfig,
  ...
}:

let
  quickshellConfigDir = ../modules/desktop/configs/quickshell;
in

{
  imports = [ ./modules ];

  home.stateVersion = "25.11";

  home.sessionVariables = {
    XDG_RUNTIME_DIR = "/run/user/1000";
    WAYLAND_DISPLAY = "wayland-0";
  };

  myHome = {
    identity = {
      name = "Gamzat";
      email = "mukailov.g@gmail.com";
      sshKey = "~/.ssh/mydevkey";
    };
    sops = {
      enable = true;
      ageKeyFile = "/home/gamzat/.config/sops/age/key.txt";
    };
    apps = {
      bitwarden = osConfig.mySystem.passwordManager.bitwarden;
      wezterm = osConfig.mySystem.terminal.wezterm;
      moonlight = osConfig.mySystem.streaming.moonlight;
      clipboard = osConfig.mySystem.clipboard.copyq;
    };
    kube.enable = true;
  };

  home.packages = with pkgs; [
    opencloud-desktop
  ];

  # Quickshell config — only when MangoWC compositor is the active session
  home.file.".config/quickshell" = lib.mkIf osConfig.mySystem.desktop.mangowc {
    source = quickshellConfigDir;
    recursive = true;
  };
}
