{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf (config.mySystem.desktop.enable && config.mySystem.desktop.gnome) {
    services.enable = true;
    services.displayManager.gdm.enable = true;
    services.displayManager.gdm.wayland = true;
    services.desktopManager.gnome.enable = true;

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
