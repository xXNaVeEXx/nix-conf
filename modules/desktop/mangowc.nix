{
  config,
  lib,
  pkgs,
  mangowc,
  quickshell,
  ...
}:

let
  # Wallpaper image
  wallpaper = pkgs.fetchurl {
    url = "https://images.unsplash.com/photo-1517154421773-0529f29ea451?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D";
    sha256 = "0km2dyifda53fwg592z701kf68hwa8fgin1yl2x351vgpmx8g4gn";
  };

  # Determine which bar to use
  barCommand = if config.mySystem.desktop.bar == "quickshell" then "quickshell" else "waybar";

  mangoConfig = pkgs.writeText "mango-config" ''
    # MangoWC Configuration

    # Keyboard layout
    set $kb_layout de

    input type:keyboard {
        xkb_layout de
    }

    # Keybindings (using Alt for Proxmox compatibility)
    bind=ALT,Return,spawn,wezterm
    bind=ALT,D,spawn,rofi -show drun
    bind=ALT,Q,killclient
    bind=ALT,F,togglefullscreen
    bind=ALT,Space,togglefloating
    bind=ALT,R,reload_config

    # Autostart applications (runs once at startup)
    exec-once=${barCommand}
    exec-once=swaybg -i ${wallpaper} -m fill
    exec-once=mako
  '';

  # Quickshell configuration directory
  quickshellConfigDir = ./configs/quickshell;
in

{
  imports = [
    mangowc.nixosModules.mango
  ];

  config = lib.mkIf (config.mySystem.desktop.enable && config.mySystem.desktop.mangowc) {
    # Enable MangoWC compositor (already handles portals, polkit, xwayland)
    programs.mango.enable = true;

    # Enable GDM as display manager
    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;
    services.displayManager.gdm.wayland = true;

    # Configure XDG Desktop Portal for screen sharing (required for RustDesk)
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome  # Provides RemoteDesktop interface for RustDesk
      ];
      config = {
        common = lib.mkForce {
          default = [ "gnome" "wlr" "gtk" ];
        };
        mango = lib.mkForce {
          default = [ "gnome" "wlr" "gtk" ];
          "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
          "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
          "org.freedesktop.impl.portal.RemoteDesktop" = [ "gnome" ];
        };
      };
    };

    # Autostart xdg-desktop-portal-gnome for RemoteDesktop support
    systemd.user.services.xdg-desktop-portal-gnome = lib.mkIf config.mySystem.desktop.mangowc {
      description = "GNOME Desktop Portal for RemoteDesktop";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "dbus";
        BusName = "org.freedesktop.impl.portal.desktop.gnome";
        ExecStart = "${pkgs.xdg-desktop-portal-gnome}/libexec/xdg-desktop-portal-gnome";
        Restart = "on-failure";
      };
    };

    # Set keyboard layout and Wayland environment variables
    environment.sessionVariables = {
      XKB_DEFAULT_LAYOUT = "de";
      # Force Qt applications to use Wayland
      QT_QPA_PLATFORM = "wayland";
      # Additional Wayland variables
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      CLUTTER_BACKEND = "wayland";
      GDK_BACKEND = "wayland";
    };

    # Additional useful packages for MangoWC
    environment.systemPackages =
      with pkgs;
      [
        # Terminal (REQUIRED - keybindings depend on this!)
        wezterm

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
      ]
      ++ (
        # Conditionally add bar based on user preference
        if config.mySystem.desktop.bar == "quickshell" then
          [ quickshell.packages.${pkgs.system}.default ]
        else
          [ waybar ]
      );

    # MangoWC configuration with autostart
    environment.etc."mango/config.conf".source = mangoConfig;

    # Quickshell configuration (if using quickshell)
    environment.etc."xdg/quickshell" =
      lib.mkIf (config.mySystem.desktop.bar == "quickshell")
        {
          source = quickshellConfigDir;
        };

    # Create GDM session file for Mango
    services.displayManager.sessionPackages = [
      (pkgs.writeTextFile rec {
        name = "mango-session";
        destination = "/share/wayland-sessions/mango.desktop";
        text = ''
          [Desktop Entry]
          Name=Mango
          Comment=Mango Wayland Compositor
          Exec=mango
          Type=Application
          DesktopNames=mango
        '';
        passthru.providedSessions = [ "mango" ];
      })
    ];

    # Wayvnc configuration for remote desktop (RustDesk alternative)
    environment.etc."xdg/wayvnc/config".text = ''
      address=0.0.0.0
      port=5900
      enable_auth=true
      username=remote
      password=CHANGE_THIS_PASSWORD
    '';

    # Systemd user service to autostart wayvnc
    systemd.user.services.wayvnc = lib.mkIf config.mySystem.desktop.mangowc {
      description = "Wayvnc VNC Server";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      environment = {
        WAYLAND_DISPLAY = "wayland-0";
      };
      serviceConfig = {
        ExecStart = "${pkgs.wayvnc}/bin/wayvnc -C /etc/xdg/wayvnc/config";
        Restart = "on-failure";
      };
    };
  };
}
