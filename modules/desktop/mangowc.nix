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

  # Determine which bar to use
  barCommand = if config.mySystem.desktop.bar == "quickshell" then "quickshell" else "waybar";

  # Script to toggle system info widget
  toggleSystemInfo = pkgs.writeShellScript "toggle-sysinfo" ''
    # Toggle file location
    TOGGLE_FILE="/tmp/quickshell-sysinfo-visible"

    if [ -f "$TOGGLE_FILE" ]; then
      rm "$TOGGLE_FILE"
      echo "false" > "$TOGGLE_FILE.state"
    else
      touch "$TOGGLE_FILE"
      echo "true" > "$TOGGLE_FILE.state"
    fi
  '';

  mangoConfig = pkgs.writeText "mango-config" ''
    # MangoWC Configuration

    # ============================================================================
    # DISPLAY & OUTPUT SETTINGS
    # ============================================================================
    # Virtual display configuration for Proxmox VM via wayvnc
    # Viewed through RealVNC client on MacBook M1 Pro Max

    # Monitor configuration for virtual display
    # Note: Output name is typically HEADLESS-1 for wayvnc
    # Use 'wlr-randr' to verify actual output name if needed
    output HEADLESS-1 {
        mode 2560x1440@144Hz
        position 0,0
        scale 1.0
        transform normal
    }

    # Fallback for alternative output names
    # Uncomment if HEADLESS-1 doesn't work
    # output WL-1 mode 2560x1440@144Hz position 0,0 scale 1.0

    # ============================================================================
    # INPUT DEVICE SETTINGS
    # ============================================================================

    # Keyboard configuration
    set $kb_layout de

    input type:keyboard {
        xkb_layout de
        # Basic behavior - default repeat rate and delay
        repeat_rate 35
        repeat_delay 300
    }

    # Mouse configuration
    input type:pointer {
        # Disable acceleration for consistent 1:1 movement
        accel_profile flat
        # Default pointer speed (0.0 = no adjustment)
        pointer_accel 0.0
        # Standard scroll direction
        natural_scroll disabled
    }

    # ============================================================================
    # WINDOW MANAGEMENT SETTINGS
    # ============================================================================

    # Tag configuration (5 tags numbered 1-5)
    # Note: Tag indicators will be displayed as dots in quickshell (bottom right)
    tags 5

    # Default layout: Scroller (horizontal)
    # Windows arranged side by side, scroll through them
    layout scroller

    # Window gaps
    gaps_inner 10    # Medium gaps between windows
    gaps_outer 10    # Medium gaps from screen edges

    # Window borders
    border_width 0   # No borders

    # Focus behavior
    # Focus follows mouse (window gets focus on hover)
    focus_follows_mouse yes
    # Also allow keyboard focus control (configured in keybindings)

    # Master-stack layout settings (for when switching to master-stack layout)
    master_ratio 0.6      # 60% of screen for master window (dwm default)
    master_count 1        # Number of windows in master area

    # Floating window behavior
    # Automatically float certain window types (dialogs, popups, splash screens)
    float_types dialog,utility,toolbar,splash,menu,dropdown_menu,popup_menu,tooltip,notification
    # Center floating windows when opened
    center_floating yes

    # ============================================================================
    # APPEARANCE & VISUAL EFFECTS
    # ============================================================================
    # Cyberpunk aesthetic with smooth animations and neon glow effects

    # ──────────────────────────────────────────────────────────────────────────
    # ANIMATIONS
    # ──────────────────────────────────────────────────────────────────────────
    # Enable smooth animations
    animations enabled

    # Window animations - Fade style with medium speed (250ms)
    animation window_open fade 250         # Window open animation
    animation window_close fade 250        # Window close animation
    animation window_move smooth 250       # Window move animation
    animation window_resize smooth 250     # Window resize animation

    # Tag switch animations - Fade between tags
    animation tag_switch fade 250          # Tag switching animation

    # Layout change animations - Smooth transitions
    animation layout_change smooth 250     # Layout change animation

    # Workspace animations
    animation workspace fade 250           # Workspace transition

    # Fade in/out duration for window lifecycle
    fade_in_duration 250                   # Fade in when opening (medium)
    fade_out_duration 250                  # Fade out when closing (medium)

    # ──────────────────────────────────────────────────────────────────────────
    # WINDOW EFFECTS (scenefx)
    # ──────────────────────────────────────────────────────────────────────────
    # Corner radius - Medium rounded corners (10px)
    corner_radius 10

    # Window shadows - Neon blue glow effect
    shadows enabled
    shadow_color 0.0 0.85 1.0 0.5          # Neon blue (#00d9ff) with 50% opacity
    shadow_blur_sigma 8                     # Small shadow size with blur
    shadow_offset_x 0                       # Centered shadow (glow effect)
    shadow_offset_y 2                       # Slight vertical offset

    # Blur effects - Medium strength
    blur enabled
    blur_strength 6                         # Medium blur for transparent windows
    blur_passes 2                           # Quality passes

    # Window opacity
    opacity_active 1.0                      # Active windows fully opaque
    opacity_inactive 0.85                   # Inactive windows dimmed (85%)
    opacity_floating 0.95                   # Floating windows slightly transparent

    # Dim inactive windows
    dim_inactive enabled
    dim_inactive_value 0.15                 # Dim by 15%

    # ──────────────────────────────────────────────────────────────────────────
    # ACTIVE/INACTIVE WINDOW DISTINCTION
    # ──────────────────────────────────────────────────────────────────────────
    # No borders (as requested), distinction through opacity and dim only
    # Active window: Full brightness, 100% opacity, neon blue shadow glow
    # Inactive window: Dimmed 15%, 85% opacity, subtle shadow

    # ──────────────────────────────────────────────────────────────────────────
    # CURSOR THEME
    # ──────────────────────────────────────────────────────────────────────────
    # Cyberpunk dark cursor theme will be set via environment variables
    # (configured in environment section below)

    # ============================================================================
    # KEYBINDINGS
    # ============================================================================
    # Using ALT (for Proxmox compatibility) and SUPER modifiers
    # Vim-style navigation (H/J/K/L)

    # ──────────────────────────────────────────────────────────────────────────
    # APPLICATION LAUNCHERS
    # ──────────────────────────────────────────────────────────────────────────
    bind=ALT,Return,spawn,wezterm                    # Launch terminal
    bind=ALT,D,spawn,rofi -show drun                 # Application launcher

    # ──────────────────────────────────────────────────────────────────────────
    # WINDOW MANAGEMENT
    # ──────────────────────────────────────────────────────────────────────────
    bind=ALT,Q,killclient                            # Kill focused window
    bind=ALT,F,togglefullscreen                      # Toggle fullscreen
    bind=ALT,Space,togglefloating                    # Toggle floating
    bind=ALT,M,minimize                              # Minimize window
    bind=ALT,X,togglemaximize                        # Maximize window
    bind=ALT,Tab,cyclewindow                         # Cycle through windows

    # Swap windows (vim keys)
    bind=ALT_SHIFT,H,swapwindow,left                 # Swap window left
    bind=ALT_SHIFT,J,swapwindow,down                 # Swap window down
    bind=ALT_SHIFT,K,swapwindow,up                   # Swap window up
    bind=ALT_SHIFT,L,swapwindow,right                # Swap window right

    # ──────────────────────────────────────────────────────────────────────────
    # FOCUS MANAGEMENT (Vim keys)
    # ──────────────────────────────────────────────────────────────────────────
    bind=ALT,H,focuswindow,left                      # Focus left
    bind=ALT,J,focuswindow,down                      # Focus down
    bind=ALT,K,focuswindow,up                        # Focus up
    bind=ALT,L,focuswindow,right                     # Focus right

    # ──────────────────────────────────────────────────────────────────────────
    # TAG SWITCHING (Tags 1-5)
    # ──────────────────────────────────────────────────────────────────────────
    bind=ALT,1,viewtag,1                             # Switch to tag 1
    bind=ALT,2,viewtag,2                             # Switch to tag 2
    bind=ALT,3,viewtag,3                             # Switch to tag 3
    bind=ALT,4,viewtag,4                             # Switch to tag 4
    bind=ALT,5,viewtag,5                             # Switch to tag 5

    # Cycle through tags (vim-style)
    bind=ALT,N,viewtag,next                          # Next tag
    bind=ALT,P,viewtag,prev                          # Previous tag

    # ──────────────────────────────────────────────────────────────────────────
    # MOVE WINDOWS TO TAGS
    # ──────────────────────────────────────────────────────────────────────────
    bind=ALT_SHIFT,1,movetotag,1                     # Move to tag 1
    bind=ALT_SHIFT,2,movetotag,2                     # Move to tag 2
    bind=ALT_SHIFT,3,movetotag,3                     # Move to tag 3
    bind=ALT_SHIFT,4,movetotag,4                     # Move to tag 4
    bind=ALT_SHIFT,5,movetotag,5                     # Move to tag 5

    # ──────────────────────────────────────────────────────────────────────────
    # LAYOUT MANAGEMENT
    # ──────────────────────────────────────────────────────────────────────────
    # Cycle layouts
    bind=ALT,Comma,cyclelayout,prev                  # Previous layout
    bind=ALT,Period,cyclelayout,next                 # Next layout

    # Specific layouts
    bind=ALT,S,setlayout,scroller                    # Scroller layout
    bind=ALT,T,setlayout,master-stack                # Master-stack (tiling)
    bind=ALT,G,setlayout,grid                        # Grid layout
    bind=ALT,O,setlayout,monocle                     # Monocle (one window)

    # ──────────────────────────────────────────────────────────────────────────
    # MASTER-STACK CONTROLS
    # ──────────────────────────────────────────────────────────────────────────
    bind=ALT,BracketRight,resizemaster,+0.05         # Increase master size (+5%)
    bind=ALT,BracketLeft,resizemaster,-0.05          # Decrease master size (-5%)
    bind=ALT_SHIFT,BracketRight,incmaster,1          # Increase master count
    bind=ALT_SHIFT,BracketLeft,incmaster,-1          # Decrease master count

    # ──────────────────────────────────────────────────────────────────────────
    # SCREENSHOTS
    # ──────────────────────────────────────────────────────────────────────────
    bind=ALT,Print,spawn,grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png                    # Full screenshot
    bind=ALT_SHIFT,Print,spawn,grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png  # Selection screenshot

    # ──────────────────────────────────────────────────────────────────────────
    # SYSTEM CONTROLS
    # ──────────────────────────────────────────────────────────────────────────
    bind=ALT,I,spawn,${toggleSystemInfo}                 # Toggle system info widget
    bind=ALT,R,reload_config                         # Reload MangoWC config
    bind=SUPER,M,quit                                # Quit MangoWC
    bind=SUPER,L,spawn,swaylock                      # Lock screen

    # ──────────────────────────────────────────────────────────────────────────
    # CLIPBOARD MANAGER
    # ──────────────────────────────────────────────────────────────────────────
    bind=ALT_SHIFT,V,spawn,cliphist list | rofi -dmenu -p "Clipboard" | cliphist decode | wl-copy  # Clipboard history

    # ──────────────────────────────────────────────────────────────────────────
    # THEME SWITCHER
    # ──────────────────────────────────────────────────────────────────────────
    bind=ALT,T,spawn,${themeSwitcherScript}/bin/quickshell-theme-toggle  # Toggle theme switcher

    # ──────────────────────────────────────────────────────────────────────────
    # KEYBINDINGS CHEATSHEET
    # ──────────────────────────────────────────────────────────────────────────
    bind=SUPER,W,spawn,${keybindingsCheatsheetScript}/bin/quickshell-keybindings-toggle  # Keybindings cheatsheet

    # ──────────────────────────────────────────────────────────────────────────
    # MEDIA KEYS (Function keys)
    # ──────────────────────────────────────────────────────────────────────────
    bind=,XF86AudioRaiseVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+     # Volume up
    bind=,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-     # Volume down
    bind=,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle           # Mute toggle
    bind=,XF86MonBrightnessUp,spawn,brightnessctl set 5%+                           # Brightness up
    bind=,XF86MonBrightnessDown,spawn,brightnessctl set 5%-                         # Brightness down
    bind=,XF86AudioPlay,spawn,playerctl play-pause                                  # Play/Pause
    bind=,XF86AudioNext,spawn,playerctl next                                        # Next track
    bind=,XF86AudioPrev,spawn,playerctl previous                                    # Previous track

    # ============================================================================
    # WINDOW RULES
    # ============================================================================
    # Specific application behaviors

    # ──────────────────────────────────────────────────────────────────────────
    # FLOATING WINDOWS
    # ──────────────────────────────────────────────────────────────────────────
    # Calculator apps - float and center
    windowrule float,class:^(gnome-calculator|qalculate-gtk|kcalc|galculator)$
    windowrule center,class:^(gnome-calculator|qalculate-gtk|kcalc|galculator)$
    windowrule size 400 600,class:^(gnome-calculator|qalculate-gtk|kcalc|galculator)$

    # Bitwarden - float and center (password manager)
    windowrule float,class:^(Bitwarden|bitwarden)$
    windowrule center,class:^(Bitwarden|bitwarden)$
    windowrule size 1000 700,class:^(Bitwarden|bitwarden)$

    # Notifications - appear like mobile (top-right, small floating)
    # Note: Mako handles notification positioning, but this covers notification windows
    windowrule float,class:^(notification|notify)$
    windowrule move 100%-400 50,class:^(notification|notify)$  # Top-right corner
    windowrule size 380 120,class:^(notification|notify)$
    windowrule nofocus,class:^(notification|notify)$           # Don't steal focus

    # Additional floating rules for common dialog types (already covered by float_types above)
    # These are redundant but explicit for clarity
    windowrule float,title:^(Open File|Save File|Select File)$
    windowrule float,title:^(File Upload|Picture-in-Picture)$

    # ──────────────────────────────────────────────────────────────────────────
    # NO SPECIAL APP BEHAVIORS
    # ──────────────────────────────────────────────────────────────────────────
    # All other applications use default tiling behavior
    # No tag assignments - apps open on current tag
    # No opacity overrides - use global opacity rules
    # No size/position rules - apps follow layout

    # ============================================================================
    # AUTOSTART APPLICATIONS
    # ============================================================================

    # Status bar (quickshell with cyberpunk theme)
    exec-once=${barCommand}

    # Wallpaper (theme-based)
    exec-once=swaybg -i ${wallpaper} -m fill

    # Notification daemon (mako with cyberpunk theme)
    exec-once=mako --config /etc/xdg/mako/config

    # Clipboard manager (cliphist)
    exec-once=wl-paste --type text --watch cliphist store
    exec-once=wl-paste --type image --watch cliphist store

    # Authentication agent (polkit)
    exec-once=${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1

    # Night light (wlsunset - time-based screen temperature)
    # Adjust transition times for your timezone
    exec-once=wlsunset -l 51.5 -L 0.0 -t 4000 -T 6500

    # Idle management (swayidle - auto-lock after 10min, dim before lock)
    # Ensures background services continue running (no suspend on VM)
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
