{
  config,
  lib,
  pkgs,
  mangowc,
  quickshell,
  ...
}:

let
  mangoConfig = pkgs.writeText "mango-config" ''
    # MangoWC Configuration

    # Autostart applications
    exec-once=quickshell
    exec-once=swaybg -c "#1e1e2e"
  '';
in

{
  imports = [
    mangowc.nixosModules.mango
  ];

  config = lib.mkIf (config.mySystem.desktop.enable && config.mySystem.desktop.mangowc) {
    # Enable MangoWC compositor (already handles portals, polkit, xwayland)
    programs.mango.enable = true;

    # Additional useful packages for MangoWC
    environment.systemPackages = with pkgs; [
      # Wayland utilities
      wayland-utils
      wl-clipboard

      # Application launcher (has native Wayland support)
      rofi

      # Notification daemon
      mako

      # Screenshot tools
      grim
      slurp

      # Wallpaper
      swaybg

      # Quickshell bar
      quickshell.packages.${pkgs.system}.default
    ];

    # MangoWC configuration with autostart
    environment.etc."mango/config.conf".source = mangoConfig;
  };
}
