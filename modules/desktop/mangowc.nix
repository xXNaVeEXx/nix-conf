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

  # Basic quickshell configuration
  quickshellConfig = pkgs.writeText "shell.qml" ''
    import Quickshell
    import Quickshell.Wayland

    ShellRoot {
      WlSessionLock {}

      Variants {
        model: Quickshell.screens

        PanelWindow {
          property var modelData
          screen: modelData

          anchors {
            top: true
            left: true
            right: true
          }

          height: 30

          color: "#1e1e2e"

          Text {
            anchors.centerIn: parent
            text: "MangoWC - " + new Date().toLocaleString(Qt.locale(), "ddd MMM d HH:mm")
            color: "#cdd6f4"

            Timer {
              interval: 1000
              running: true
              repeat: true
              onTriggered: parent.text = "MangoWC - " + new Date().toLocaleString(Qt.locale(), "ddd MMM d HH:mm")
            }
          }
        }
      }
    }
  '';

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
in

{
  imports = [
    mangowc.nixosModules.mango
  ];

  config = lib.mkIf (config.mySystem.desktop.enable && config.mySystem.desktop.mangowc) {
    # Enable MangoWC compositor (already handles portals, polkit, xwayland)
    programs.mango.enable = true;

    # Set keyboard layout environment variables
    environment.sessionVariables = {
      XKB_DEFAULT_LAYOUT = "de";
    };

    # Additional useful packages for MangoWC
    environment.systemPackages = with pkgs; [
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
    ] ++ (
      # Conditionally add bar based on user preference
      if config.mySystem.desktop.bar == "quickshell"
      then [ quickshell.packages.${pkgs.system}.default ]
      else [ waybar ]
    );

    # MangoWC configuration with autostart
    environment.etc."mango/config.conf".source = mangoConfig;

    # Quickshell configuration (if using quickshell)
    environment.etc."xdg/quickshell/shell.qml" = lib.mkIf (config.mySystem.desktop.bar == "quickshell") {
      source = quickshellConfig;
    };
  };
}
