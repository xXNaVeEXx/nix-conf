{
  config,
  lib,
  pkgs,
  mangowc,
  quickshell,
  ...
}:

let
  # Wallpaper images - theme switcher
  wallpapers = {
    cyberpunk = pkgs.fetchurl {
      url = "https://images.unsplash.com/photo-1517154421773-0529f29ea451?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D";
      sha256 = "0km2dyifda53fwg592z701kf68hwa8fgin1yl2x351vgpmx8g4gn";
      name = "cyberpunk-wallpaper.jpg";
    };
    sunset = pkgs.fetchurl {
      url = "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D";
      sha256 = "14ysd780873dmmbmrprn032lwpj4mx55brdb134fadfjdmdl610f";
      name = "sunset-wallpaper.jpg";
    };
    tokyo = pkgs.fetchurl {
      url = "https://r4.wallpaperflare.com/wallpaper/836/414/353/city-urban-street-asia-wallpaper-424152f0ad06deeb4af8a21540e80962.jpg";
      sha256 = "0nn420z0kbw6zl1rj2ky6412ghh8zn95j8j0mipsvl2xxi260jc7";
    };
    future = pkgs.fetchurl {
      url = "https://r4.wallpaperflare.com/wallpaper/506/679/697/city-futuristic-digital-art-cheng-yu-wallpaper-86257bc769cf2ab70d65ac7d1b5c2384.jpg";
      sha256 = "1qwphcgdj8m39757nj6y3ph7x3b5jbgg4v8yas5piqs2c2scqdim";
    };
  };

  # Current theme (default: cyberpunk)
  currentTheme = "cyberpunk";
  wallpaper = wallpapers.${currentTheme};

  # Theme switcher script
  themeSwitcherScript = pkgs.writeShellScriptBin "quickshell-theme-toggle" ''
    # Toggle theme switcher in quickshell
    # This sends a signal to quickshell to show the theme switcher widget
    echo "toggle-theme-switcher" > /tmp/quickshell-command
  '';

  # Keybindings cheatsheet script
  keybindingsCheatsheetScript = pkgs.writeShellScriptBin "quickshell-keybindings-toggle" ''
    # Toggle keybindings cheatsheet in quickshell
    echo "toggle-keybindings-cheatsheet" > /tmp/quickshell-command
  '';

  # Clipboard history script
  cliphistScript = pkgs.writeShellScriptBin "cliphist-rofi" ''
    #!/usr/bin/env bash
    selected=$(cliphist list | rofi -dmenu -p "Clipboard")
    if [ -n "$selected" ]; then
      cliphist decode <<< "$selected" | wl-copy
      wtype -M ctrl -M shift v -m shift -m ctrl
    fi
  '';

  # Copy script (simulates Ctrl+C)
  copyScript = pkgs.writeShellScriptBin "copy-selection" ''
    #!/usr/bin/env bash
    wtype -M ctrl c -m ctrl
  '';

  # Paste script (simulates Ctrl+V)
  pasteScript = pkgs.writeShellScriptBin "paste-clipboard" ''
    #!/usr/bin/env bash
    wtype -M ctrl v -m ctrl
  '';

  # Wallpaper switcher script
  wallpaperSwitcherScript = pkgs.writeShellScriptBin "quickshell-switch-wallpaper" ''
    #!/usr/bin/env bash
    WALLPAPER_PATH="$1"

    if [ -z "$WALLPAPER_PATH" ]; then
      echo "Usage: $0 <wallpaper-path>"
      exit 1
    fi

    # Kill existing swaybg
    pkill swaybg 2>/dev/null
    sleep 0.2

    # Start new swaybg in background, detached from this script
    setsid swaybg -i "$WALLPAPER_PATH" -m fill >/dev/null 2>&1 &

    echo "Wallpaper switched to: $WALLPAPER_PATH"
  '';

  # MangoWC IPC wrapper (mangoctl) using mmsg
  mangoctlScript = pkgs.writeShellScriptBin "mangoctl" ''
    #!/bin/sh
    # MangoWC IPC wrapper using mmsg

    # Ensure proper environment for mmsg
    if [ -z "$XDG_RUNTIME_DIR" ]; then
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    fi

    # Auto-detect Wayland display socket
    if [ -z "$WAYLAND_DISPLAY" ]; then
      if [ -S "$XDG_RUNTIME_DIR/wayland-0" ]; then
        export WAYLAND_DISPLAY="wayland-0"
      elif [ -S "$XDG_RUNTIME_DIR/wayland-1" ]; then
        export WAYLAND_DISPLAY="wayland-1"
      fi
    fi

    case "$1" in
      get-active-tag)
        # Parse mmsg output to get active tag
        # Format: "Virtual-1 tag <num> <flag1> <flag2> <flag3>"
        # The second flag (field 5) appears to indicate the active/focused tag
        TAG=$(timeout 0.5 mmsg -g 2>/dev/null | grep "^Virtual-1 tag" | awk '$5 == "1" {print $3; exit}')
        if [ -z "$TAG" ]; then
          # Fallback: get first selected tag (field 4)
          TAG=$(timeout 0.5 mmsg -g 2>/dev/null | grep "^Virtual-1 tag" | awk '$4 == "1" {print $3; exit}')
        fi
        echo "''${TAG:-1}"
        ;;
      get-active-window-title)
        # Parse mmsg output to get window title
        # Format: "Virtual-1 title <title text>"
        TITLE=$(timeout 0.5 mmsg -w 2>/dev/null | grep "^Virtual-1 title" | cut -d' ' -f3-)
        echo "''${TITLE:-Desktop}"
        ;;
      *)
        echo "Usage: mangoctl {get-active-tag|get-active-window-title}"
        exit 1
        ;;
    esac
  '';

  quickshellLauncher = pkgs.writeShellScript "quickshell-launcher" ''
    #!${pkgs.bash}/bin/bash
    cd "${config.environment.etc."xdg/quickshell".source}"
    export QML2_IMPORT_PATH="${config.environment.etc."xdg/quickshell".source}/"
    "${quickshell.packages.${pkgs.system}.default}/bin/quickshell"
  '';

  # Determine which bar to use
  barCommand =
    if config.mySystem.desktop.bar == "quickshell" then "''${quickshellLauncher}" else "waybar";

  mangoConfig = pkgs.writeText "mango-config" ''
    output HEADLESS-1 {
        mode 2560x1440@144Hz
        position 0,0
        scale 1.0
        transform normal
    }
    set $kb_layout de
    input type:keyboard {
        xkb_layout de
        repeat_rate 35
        repeat_delay 300
    }
    input type:pointer {
        accel_profile flat
        pointer_accel 0.0
        natural_scroll disabled
    }
    tags 5
    layout scroller
    gappih=10
    gappiv=10
    gappoh=10
    gappov=40
    borderpx=0
    focuscolor=0x00000000
    bordercolor=0x00000000
    focus_follows_mouse yes
    master_ratio 0.6
    master_count 1
    float_types dialog,utility,toolbar,splash,menu,dropdown_menu,popup_menu,tooltip,notification
    center_floating yes
    animations enabled
    animation window_open fade 250
    animation window_close fade 250
    animation window_move smooth 250
    animation window_resize smooth 250
    animation tag_switch fade 250
    animation layout_change smooth 250
    animation workspace fade 250
    fade_in_duration 250
    fade_out_duration 250
    corner_radius 10
    shadows enabled
    shadow_color 0.0 0.85 1.0 0.5
    shadow_blur_sigma 8
    shadow_offset_x 0
    shadow_offset_y 2
    blur enabled
    blur_strength 6
    blur_passes 2
    opacity_active 1.0
    opacity_inactive 0.85
    opacity_floating 0.95
    dim_inactive enabled
    dim_inactive_value 0.15
    bind=ALT,Return,spawn,wezterm
    bind=ALT,D,spawn,rofi -show drun
    bind=ALT,Q,killclient,
    bind=ALT,F,togglefullscreen,
    bind=ALT,Space,togglefloating,
    bind=ALT,Tab,focusstack,next
    bind=ALT+SHIFT,H,exchange_client,left
    bind=ALT+SHIFT,J,exchange_client,down
    bind=ALT+SHIFT,K,exchange_client,up
    bind=ALT+SHIFT,L,exchange_client,right
    bind=ALT,H,focusdir,left
    bind=ALT,J,focusdir,down
    bind=ALT,K,focusdir,up
    bind=ALT,L,focusdir,right
    bind=ALT,1,view,1,0
    bind=ALT,2,view,2,0
    bind=ALT,3,view,3,0
    bind=ALT,4,view,4,0
    bind=ALT,5,view,5,0
    bind=ALT,N,viewtoright,0
    bind=ALT,P,viewtoleft,0
    bind=ALT+SHIFT,1,tag,1,0
    bind=ALT+SHIFT,2,tag,2,0
    bind=ALT+SHIFT,3,tag,3,0
    bind=ALT+SHIFT,4,tag,4,0
    bind=ALT+SHIFT,5,tag,5,0
    bind=ALT,Comma,switch_layout
    bind=ALT,Period,switch_layout
    bind=ALT,S,setlayout,scroller
    bind=ALT,T,setlayout,tile
    bind=ALT,G,setlayout,grid
    bind=ALT,O,setlayout,monocle
    bind=ALT,BracketRight,switch_proportion_preset
    bind=ALT,BracketLeft,switch_proportion_preset
    bind=ALT+SHIFT,BracketRight,incnmaster,1
    bind=ALT+SHIFT,BracketLeft,incnmaster,-1
    bind=ALT,asterisk,spawn,grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
    bind=ALT+SHIFT,asterisk,spawn,grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
    bind=ALT,R,reload_config
    bind=code:133,M,quit
    bind=code:133,L,spawn,swaylock
    bind=ALT,C,spawn,${copyScript}/bin/copy-selection
    bind=ALT,V,spawn,${pasteScript}/bin/paste-clipboard
    bind=ALT+SHIFT,V,spawn,${cliphistScript}/bin/cliphist-rofi
    bind=ALT+SHIFT,T,spawn,${themeSwitcherScript}/bin/quickshell-theme-toggle
    bind=ALT,B,spawn,${keybindingsCheatsheetScript}/bin/quickshell-keybindings-toggle
    bind=,XF86AudioRaiseVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    bind=,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bind=,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bind=,XF86MonBrightnessUp,spawn,brightnessctl set 5%+
    bind=,XF86MonBrightnessDown,spawn,brightnessctl set 5%-
    bind=,XF86AudioPlay,spawn,playerctl play-pause
    bind=,XF86AudioNext,spawn,playerctl next
    bind=,XF86AudioPrev,spawn,playerctl previous
    windowrule float,class:^(gnome-calculator|qalculate-gtk|kcalc|galculator)$
    windowrule center,class:^(gnome-calculator|qalculate-gtk|kcalc|galculator)$
    windowrule size 400 600,class:^(gnome-calculator|qalculate-gtk|kcalc|galculator)$
    windowrule float,class:^(Bitwarden|bitwarden)$
    windowrule center,class:^(Bitwarden|bitwarden)$
    windowrule size 1000 700,class:^(Bitwarden|bitwarden)$
    windowrule float,class:^(notification|notify)$
    windowrule move 100%-400 50,class:^(notification|notify)$
    windowrule size 380 120,class:^(notification|notify)$
    windowrule nofocus,class:^(notification|notify)$
    windowrule float,title:^(Open File|Save File|Select File)$
    windowrule float,title:^(File Upload|Picture-in-Picture)$
    exec-once=dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
    exec-once=systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
    exec-once=${barCommand}
    exec-once=swaybg -i ${wallpaper} -m fill
    exec-once=mako --config /etc/xdg/mako/config
    exec-once=wl-paste --type text --watch cliphist store
    exec-once=wl-paste --type image --watch cliphist store
    exec-once=${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
    exec-once=wlsunset -l 51.5 -L 0.0 -t 4000 -T 6500
    exec-once=swayidle -w \
      timeout 540 'brightnessctl set 30%' resume 'brightnessctl set 100%' \
      timeout 600 'swaylock -f' \
      before-sleep 'swaylock -f'
    exec-once=systemctl --user start wayvnc.service
  '';

  # Quickshell configuration directory
  quickshellConfigDir = ./configs/quickshell;

  # Wallpaper mapping file for runtime theme switching
  wallpaperMapFile = pkgs.writeText "wallpaper-map.json" (
    builtins.toJSON {
      cyberpunk = "${wallpapers.cyberpunk}";
      sunset = "${wallpapers.sunset}";
      tokyo = "${wallpapers.tokyo}";
      future = "${wallpapers.future}";
    }
  );
in

{
  imports = [
    mangowc.nixosModules.mango
  ];

  config = lib.mkIf (config.mySystem.desktop.enable && config.mySystem.desktop.mangowc) {
    # Enable MangoWC compositor with custom config
    programs.mango = {
      enable = true;
      package = pkgs.symlinkJoin {
        name = "mango-with-config";
        paths = [ mangowc.packages.${pkgs.system}.default ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          # Override the session file to use our config
          rm -f $out/share/wayland-sessions/mango.desktop
          cat > $out/share/wayland-sessions/mango.desktop << EOF
          [Desktop Entry]
          Name=Mango
          Comment=Mango Wayland Compositor
          Exec=mango
          Type=Application
          DesktopNames=mango
          EOF

          # Wrap mango binary to always use config
          wrapProgram $out/bin/mango \
            --add-flags "-c /etc/mango/config.conf"
        '';
        passthru.providedSessions = [ "mango" ];
      };
    };

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
        xdg-desktop-portal-gnome # Provides RemoteDesktop interface for RustDesk
      ];
      config = {
        common = lib.mkForce {
          default = [
            "gnome"
            "wlr"
            "gtk"
          ];
        };
        mango = lib.mkForce {
          default = [
            "gnome"
            "wlr"
            "gtk"
          ];
          "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
          "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
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

      # Cursor theme - Cyberpunk dark
      XCURSOR_THEME = "Bibata-Modern-Classic";
      XCURSOR_SIZE = "24";

      # Default applications
      BROWSER = "brave";
      EDITOR = "nvim";
      VISUAL = "nvim";
      TERMINAL = "wezterm";

      # GTK/Qt theming
      GTK_THEME = "Adwaita-dark";
      QT_STYLE_OVERRIDE = "Adwaita-Dark";
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
        libnotify # notify-send command for sending notifications

        # Screenshot tools
        grim
        slurp

        # Wallpaper
        swaybg

        # Media control
        playerctl # Media player control
        brightnessctl # Screen brightness control
        swaylock # Screen locker

        # Cursor theme - Cyberpunk dark
        bibata-cursors # Modern dark cursor theme

        # Clipboard manager
        cliphist # Clipboard history manager
        wl-clipboard # Wayland clipboard utilities
        wtype # Wayland typing tool for pasting

        # Authentication
        polkit_gnome # Polkit authentication agent

        # Screen temperature
        wlsunset # Time-based screen color temperature

        # Idle management
        swayidle # Idle daemon for auto-lock

        # File watching (for theme switcher)
        inotify-tools # For watching file changes

        # Remote desktop (VNC server)
        wayvnc

        # MangoWC IPC wrapper
        mangoctlScript

        # Wallpaper switcher helper
        wallpaperSwitcherScript
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
    environment.etc."xdg/quickshell" = lib.mkIf (config.mySystem.desktop.bar == "quickshell") {
      source = quickshellConfigDir;
    };

    # Wallpaper mapping for theme switcher
    environment.etc."xdg/quickshell-wallpapers.json".source = wallpaperMapFile;

    # Mako notification daemon configuration
    environment.etc."xdg/mako/config".source = ./configs/mako/config;

    # Swaylock configuration
    environment.etc."xdg/swaylock/config".source = ./configs/swaylock/config;

    # Create GDM session file for Mango
    services.displayManager.sessionPackages = [
      (pkgs.writeTextFile rec {
        name = "mango-session";
        destination = "/share/wayland-sessions/mango.desktop";
        text = ''
          [Desktop Entry]
          Name=Mango
          Comment=Mango Wayland Compositor
          Exec=mango -c /etc/mango/config.conf
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

    # Systemd user service for wayvnc (started by exec-once in MangoWC config)
    systemd.user.services.wayvnc = lib.mkIf config.mySystem.desktop.mangowc {
      description = "Wayvnc VNC Server";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.wayvnc}/bin/wayvnc -C /etc/xdg/wayvnc/config 0.0.0.0 5900";
        Restart = "always";
        RestartSec = "5";
      };
    };
  };
}
