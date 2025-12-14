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
    };
    sunset = pkgs.fetchurl {
      url = "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D";
      sha256 = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcd";  # Run nix-prefetch-url to get real hash
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

  quickshellLauncher = pkgs.writeShellScript "quickshell-launcher" ''
    #!${pkgs.bash}/bin/bash
    cd "${config.environment.etc."xdg/quickshell".source}"
    export QML2_IMPORT_PATH="${config.environment.etc."xdg/quickshell".source}/"
    "${quickshell.packages.${pkgs.system}.default}/bin/quickshell"
  '';

  # Determine which bar to use
  barCommand = if config.mySystem.desktop.bar == "quickshell" then "''${quickshellLauncher}" else "waybar";

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
    gaps_inner 10
    gaps_outer 10
    border_width 0
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
    bind=ALT,Print,spawn,grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
    bind=ALT+SHIFT,Print,spawn,grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
    bind=ALT,R,reload_config
    bind=SUPER,M,quit
    bind=SUPER,L,spawn,swaylock
    bind=ALT+SHIFT,V,spawn,cliphist list | rofi -dmenu -p "Clipboard" | cliphist decode | wl-copy
    bind=ALT,T,spawn,${themeSwitcherScript}/bin/quickshell-theme-toggle
    bind=SUPER,W,spawn,${keybindingsCheatsheetScript}/bin/quickshell-keybindings-toggle
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
  '';


  # Quickshell configuration directory
  quickshellConfigDir = ./configs/quickshell;
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

        # Screenshot tools
        grim
        slurp

        # Wallpaper
        swaybg

        # Media control
        playerctl     # Media player control
        brightnessctl # Screen brightness control
        swaylock      # Screen locker

        # Cursor theme - Cyberpunk dark
        bibata-cursors  # Modern dark cursor theme

        # Clipboard manager
        cliphist      # Clipboard history manager
        wl-clipboard  # Wayland clipboard utilities

        # Authentication
        polkit_gnome  # Polkit authentication agent

        # Screen temperature
        wlsunset      # Time-based screen color temperature

        # Idle management
        swayidle      # Idle daemon for auto-lock

        # File watching (for theme switcher)
        inotify-tools # For watching file changes

        # Remote desktop (VNC server)
        wayvnc
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

    # Systemd user service to autostart wayvnc
    systemd.user.services.wayvnc = lib.mkIf config.mySystem.desktop.mangowc {
      description = "Wayvnc VNC Server";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
        ExecStart = "${pkgs.wayvnc}/bin/wayvnc -C /etc/xdg/wayvnc/config";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };
  };
}
