{ config, lib, ... }:

{
  options.mySystem = {
    desktop = {
      enable = lib.mkEnableOption "desktop environment";
      gnome = lib.mkEnableOption "GNOME desktop";
      pantheon = lib.mkEnableOption "Pantheon desktop";
      mangowc = lib.mkEnableOption "MangoWC Wayland compositor with Quickshell";
    };
    gaming = {
      steam = lib.mkEnableOption "Steam";
    };
    streaming = {
      sunshine = lib.mkEnableOption "Sunshine streaming server";
      moonlight = lib.mkEnableOption "Moonlight streaming client";
    };
    browser = {
      brave = lib.mkEnableOption "Brave Browser";
    };
    passwordManager = {
      bitwarden = lib.mkEnableOption "Bitwarden password manager";
    };
    terminal = {
      wezterm = lib.mkEnableOption "WezTerm terminal emulator";
    };
    clipboard = {
      copyq = lib.mkEnableOption "Clipboard manager (CopyQ on Linux, Maccy on macOS)";
    };
    networking = {
      tailscale = lib.mkEnableOption "Tailscale";
    };
  };
}
