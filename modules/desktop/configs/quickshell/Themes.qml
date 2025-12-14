pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Theme Manager - Singleton for theme management
 *
 * Architecture:
 * - Themes stored in memory for instant switching
 * - Current theme saved to file for persistence
 * - File read ONCE on startup (no continuous watching)
 * - Wallpapers loaded from system config
 *
 * Usage:
 *   Themes.switchTheme("tokyo")
 *   Themes.currentTheme
 *   Themes.getCurrentTheme()
 */
Item {
  id: root

  //=============================================================================
  // PROPERTIES
  //=============================================================================

  property string currentTheme: "cyberpunk"  // Current active theme
  property bool initialLoadComplete: false   // Startup load status

  //=============================================================================
  // THEME DEFINITIONS
  //=============================================================================

  property var themes: ({
    "cyberpunk": {
      name: "Cyberpunk",
      description: "Dark blue neon night city aesthetic",

      // Colors
      bg: "#0a0e27",
      bgAlt: "#151b3d",
      bgHighlight: "#1e2749",
      neonBlue: "#00d9ff",
      neonCyan: "#00ffcc",
      neonPurple: "#a78bfa",
      neonPink: "#ff00ff",
      neonYellow: "#ffed4e",
      text: "#e0e7ff",
      textDim: "#8b95c9",
      textBright: "#ffffff",
      success: "#00ffcc",
      warning: "#ffed4e",
      error: "#ff0055",
      inactive: "#4a5580",
      border: "#2d3a6e",
      borderGlow: "#00d9ff",
      glowColor: "#00d9ff",

      // Wallpaper
      wallpaper: "cyberpunk",

      // Mako colors (for notifications)
      makoBackground: "#0a0e27dd",
      makoBorder: "#00d9ff",
      makoText: "#e0e7ff",
      makoProgress: "#00ffcc",

      // Swaylock colors
      swaylockBg: "0a0e27",
      swaylockRing: "2d3a6e",
      swaylockKey: "00d9ff",
      swaylockLine: "00d9ff",

      // MangoWC shadow color (for config generation)
      shadowColor: "0.0 0.85 1.0 0.5"  // Neon blue RGBA
    },

    "sunset": {
      name: "Sunset Vaporwave",
      description: "Warm pink purple retro aesthetic",

      // Colors
      bg: "#1a0a1f",
      bgAlt: "#2d1b3d",
      bgHighlight: "#3d2749",
      neonBlue: "#ff6ec7",  // Hot pink
      neonCyan: "#ff88cc",  // Light pink
      neonPurple: "#b388ff",  // Purple
      neonPink: "#ff79c6",  // Magenta
      neonYellow: "#ffb86c",  // Orange
      text: "#f8f8f2",
      textDim: "#a896c9",
      textBright: "#ffffff",
      success: "#ff88cc",
      warning: "#ffb86c",
      error: "#ff5555",
      inactive: "#6a5580",
      border: "#6d3a7e",
      borderGlow: "#ff6ec7",
      glowColor: "#ff6ec7",

      // Wallpaper
      wallpaper: "sunset",

      // Mako colors
      makoBackground: "#1a0a1fdd",
      makoBorder: "#ff6ec7",
      makoText: "#f8f8f2",
      makoProgress: "#ff88cc",

      // Swaylock colors
      swaylockBg: "1a0a1f",
      swaylockRing: "6d3a7e",
      swaylockKey: "ff6ec7",
      swaylockLine: "ff6ec7",

      // MangoWC shadow color
      shadowColor: "1.0 0.43 0.78 0.5"  // Hot pink RGBA
    },

    "tokyo": {
      name: "Tokyo Nights",
      description: "Warm neon Asian street vibes",

      // Colors - Red, pink, orange neon aesthetic
      bg: "#1a0a14",
      bgAlt: "#2d1424",
      bgHighlight: "#3d1e34",
      neonBlue: "#ff3366",  // Neon red-pink
      neonCyan: "#ff6b9d",  // Bright pink
      neonPurple: "#d946ef",  // Magenta-purple
      neonPink: "#ff1f7d",  // Hot pink
      neonYellow: "#ffa347",  // Warm orange
      text: "#ffe9f5",
      textDim: "#d99ec9",
      textBright: "#ffffff",
      success: "#ff6b9d",
      warning: "#ffa347",
      error: "#ff1744",
      inactive: "#8a4580",
      border: "#8d2e6e",
      borderGlow: "#ff3366",
      glowColor: "#ff3366",

      // Wallpaper
      wallpaper: "tokyo",

      // Mako colors
      makoBackground: "#1a0a14dd",
      makoBorder: "#ff3366",
      makoText: "#ffe9f5",
      makoProgress: "#ff6b9d",

      // Swaylock colors
      swaylockBg: "1a0a14",
      swaylockRing: "8d2e6e",
      swaylockKey: "ff3366",
      swaylockLine: "ff3366",

      // MangoWC shadow color
      shadowColor: "1.0 0.2 0.4 0.5"  // Neon red RGBA
    },

    "future": {
      name: "Future City",
      description: "Sleek futuristic blue cityscape",

      // Colors - Cool blue/cyan with orange accents
      bg: "#0a0f1e",
      bgAlt: "#141d33",
      bgHighlight: "#1e2949",
      neonBlue: "#00ccff",  // Bright cyan
      neonCyan: "#00ffff",  // Electric cyan
      neonPurple: "#6366f1",  // Indigo
      neonPink: "#8b5cf6",  // Purple accent
      neonYellow: "#ff9500",  // Bright orange
      text: "#e0f2fe",
      textDim: "#94a3b8",
      textBright: "#ffffff",
      success: "#00ffff",
      warning: "#ff9500",
      error: "#ff3b30",
      inactive: "#475569",
      border: "#1e40af",
      borderGlow: "#00ccff",
      glowColor: "#00ccff",

      // Wallpaper
      wallpaper: "future",

      // Mako colors
      makoBackground: "#0a0f1edd",
      makoBorder: "#00ccff",
      makoText: "#e0f2fe",
      makoProgress: "#00ffff",

      // Swaylock colors
      swaylockBg: "0a0f1e",
      swaylockRing: "1e40af",
      swaylockKey: "00ccff",
      swaylockLine: "00ccff",

      // MangoWC shadow color
      shadowColor: "0.0 0.8 1.0 0.5"  // Bright cyan RGBA
    }
  })

  //=============================================================================
  // STARTUP - Load saved theme
  //=============================================================================

  Process {
    id: initialThemeLoader
    running: true
    command: ["sh", "-c", "if [ -f /tmp/quickshell-current-theme ]; then cat /tmp/quickshell-current-theme; else echo cyberpunk; fi"]

    stdout: SplitParser {
      onRead: data => {
        var savedTheme = data.trim()

        // Validate and apply saved theme
        if (savedTheme && themes[savedTheme]) {
          currentTheme = savedTheme
          console.log("Loaded theme:", savedTheme)

          // Set wallpaper after wallpaperPaths loads
          Qt.callLater(function() {
            var wallpaperPath = wallpaperPaths[savedTheme]
            if (wallpaperPath) {
              pendingWallpaperPath = wallpaperPath
              pendingThemeName = savedTheme
              wallpaperSwitcher.running = true
            }
          })
        } else {
          // Use default theme if no valid saved theme
          currentTheme = "cyberpunk"
          console.log("Using default theme: cyberpunk")

          // Persist default theme
          Qt.createQmlObject(
            'import Quickshell.Io; import QtQuick; Process { running: true; command: ["sh", "-c", "echo cyberpunk > /tmp/quickshell-current-theme"]; }',
            root
          )
        }

        initialLoadComplete = true
      }
    }
  }

  //=============================================================================
  // WALLPAPER MANAGEMENT
  //=============================================================================

  property var wallpaperPaths: ({})  // Loaded from system config

  Process {
    id: wallpaperLoader
    running: true
    command: ["cat", "/etc/xdg/quickshell-wallpapers.json"]

    stdout: SplitParser {
      onRead: data => {
        try {
          wallpaperPaths = JSON.parse(data)
          console.log("Loaded wallpapers for:", Object.keys(wallpaperPaths).join(", "))
        } catch (e) {
          console.log("ERROR loading wallpapers:", e)
        }
      }
    }
  }

  //=============================================================================
  // THEME SWITCHING - Internal processes
  //=============================================================================

  property string pendingWallpaperPath: ""  // Pending wallpaper to apply
  property string pendingThemeName: ""      // Pending theme to save

  Process {
    id: wallpaperSwitcher
    running: false
    command: ["quickshell-switch-wallpaper", pendingWallpaperPath]

    stdout: SplitParser {
      onRead: data => console.log("Wallpaper switched:", data.trim())
    }
  }

  Process {
    id: themeStateSaver
    running: false
    command: ["sh", "-c", "echo '" + pendingThemeName + "' > /tmp/quickshell-current-theme"]

    stderr: SplitParser {
      onRead: data => console.log("ERROR saving theme:", data.trim())
    }
  }

  //=============================================================================
  // PUBLIC API
  //=============================================================================

  function getTheme(themeName) {
    return themes[themeName] || themes["cyberpunk"]
  }

  function getCurrentTheme() {
    return getTheme(currentTheme)
  }

  function getWallpaperPath(themeName) {
    return wallpaperPaths[themeName] || ""
  }

  function switchTheme(newTheme) {
    if (!themes[newTheme]) {
      console.log("ERROR: Unknown theme:", newTheme)
      return
    }

    console.log("Switching theme:", currentTheme, "→", newTheme)

    // Update theme immediately in memory (triggers color changes)
    currentTheme = newTheme

    // Prepare wallpaper and persistence
    var wallpaperPath = wallpaperPaths[newTheme] || ""
    pendingThemeName = newTheme
    pendingWallpaperPath = wallpaperPath

    // Save theme to file for persistence
    themeStateSaver.running = true

    // Switch wallpaper if available
    if (wallpaperPath) {
      wallpaperSwitcher.running = true
    }

    // Show notification
    Qt.createQmlObject(
      'import Quickshell.Io; import QtQuick; Process { running: true; command: ["notify-send", "Theme Switcher", "Switched to ' + themes[newTheme].name + '", "-i", "preferences-desktop-theme", "-t", "3000"]; }',
      root
    )
  }
}
