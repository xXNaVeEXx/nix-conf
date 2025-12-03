{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf (config.mySystem.desktop.enable && config.mySystem.desktop.pantheon) {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.pantheon.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-pantheon ];
    };
  };
}
