{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf (config.mySystem.desktop.enable && config.mySystem.desktop.gnome) {
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.displayManager.gdm.wayland = true;
    services.xserver.desktopManager.gnome.enable = true;

    # Wichtig für Wayland Screen Capture
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    };

    environment.gnome.excludePackages = with pkgs; [
      # Optional: Ungewollte GNOME-Apps ausschließen
      # gnome-tour
      # epiphany
    ];
  };
}
