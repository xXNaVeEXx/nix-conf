pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Theme manager - Central theme registry and switcher
Item {
  id: root

  // Current active theme (persisted via file)
  property string currentTheme: "cyberpunk"  // Default until file is loaded
  property bool ignoreFileWatcher: false
  property bool initialLoadComplete: false

  // Available themes with all their properties
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

  // Load current theme from file on startup
  Process {
    id: themeLoader
    running: true
    command: ["sh", "-c", "if [ -f /tmp/quickshell-current-theme ]; then cat /tmp/quickshell-current-theme; else echo 'cyberpunk'; fi"]

    stdout: SplitParser {
      onRead: data => {
        var savedTheme = data.trim()
        if (savedTheme && themes[savedTheme]) {
          currentTheme = savedTheme
          console.log("Loaded saved theme:", savedTheme)

          // Set wallpaper for loaded theme
          var wallpaperPath = wallpaperPaths[savedTheme]
          if (wallpaperPath) {
            pendingWallpaperPath = wallpaperPath
            pendingThemeName = savedTheme
            wallpaperSwitcher.running = true
            console.log("Setting wallpaper for theme:", savedTheme)
          }
        } else {
          currentTheme = "cyberpunk"
          console.log("No saved theme, defaulting to cyberpunk")

          // Ensure theme file exists with default
          var defaultSaver = Qt.createQmlObject(
            'import Quickshell.Io; import QtQuick; Process { running: true; command: ["sh", "-c", "echo cyberpunk > /tmp/quickshell-current-theme"]; }',
            root
          )
        }
        initialLoadComplete = true
      }
    }
  }

  // Watch for theme changes
  Process {
    id: themeFileWatcher
    running: true
    command: ["sh", "-c", "while true; do if [ -f /tmp/quickshell-current-theme ]; then cat /tmp/quickshell-current-theme; else echo 'cyberpunk'; fi; sleep 1; done"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var newTheme = data.trim()

        if (ignoreFileWatcher) {
          console.log("File watcher: Ignoring theme change to", newTheme, "(watcher disabled)")
          return
        }

        if (newTheme && themes[newTheme]) {
          if (newTheme !== currentTheme) {
            console.log("File watcher: Theme changed from", currentTheme, "to", newTheme)
            currentTheme = newTheme
          }
        } else {
          console.log("File watcher: Invalid theme detected:", newTheme)
        }
      }
    }
  }

  function getTheme(themeName) {
    return themes[themeName] || themes["cyberpunk"]
  }

  function getCurrentTheme() {
    return getTheme(currentTheme)
  }

  // Wallpaper mapping - loaded from JSON file
  property var wallpaperPaths: ({})

  // Load wallpaper paths from system config
  Process {
    id: wallpaperLoader
    running: true
    command: ["cat", "/etc/xdg/quickshell-wallpapers.json"]

    stdout: SplitParser {
      onRead: data => {
        try {
          wallpaperPaths = JSON.parse(data)
          console.log("Loaded wallpaper paths for themes:", Object.keys(wallpaperPaths).join(", "))
        } catch (e) {
          console.log("Failed to parse wallpaper paths:", e)
        }
      }
    }
  }

  // Process for switching wallpaper
  property string pendingWallpaperPath: ""
  property string pendingThemeName: ""
  property string pendingThemeDisplayName: ""

  Process {
    id: wallpaperSwitcher
    running: false
    command: ["quickshell-switch-wallpaper", pendingWallpaperPath]

    onRunningChanged: {
      if (!running && pendingThemeName) {
        console.log("Wallpaper switched to:", pendingWallpaperPath)
        // Send notification after wallpaper switches
        notificationSender.running = true
      }
    }

    stdout: SplitParser {
      onRead: data => {
        console.log("Wallpaper switcher:", data)
      }
    }
  }

  Process {
    id: notificationSender
    running: false
    command: ["notify-send", "Theme Switcher", "Switched to " + pendingThemeDisplayName, "-i", "preferences-desktop-theme"]
  }

  Process {
    id: themeStateSaver
    running: false
    command: ["sh", "-c", "echo '" + pendingThemeName + "' > /tmp/quickshell-current-theme && sleep 0.1 && cat /tmp/quickshell-current-theme"]

    stdout: SplitParser {
      onRead: data => {
        console.log("Theme file now contains:", data.trim())
      }
    }

    onRunningChanged: {
      if (!running && pendingThemeName) {
        console.log("Theme state saved:", pendingThemeName)
        // Update currentTheme AFTER file is written to prevent race
        currentTheme = pendingThemeName
        console.log("currentTheme updated to:", currentTheme)

        // After saving state, switch wallpaper
        if (pendingWallpaperPath) {
          wallpaperSwitcher.running = true
        }
      }
    }
  }

  function getWallpaperPath(themeName) {
    return wallpaperPaths[themeName] || ""
  }

  function switchTheme(newTheme) {
    if (themes[newTheme]) {
      console.log("=== THEME SWITCH START ===")
      console.log("Switching from:", currentTheme, "to:", newTheme)

      // Ignore file watcher temporarily to prevent race condition
      ignoreFileWatcher = true
      console.log("File watcher disabled")

      // Get wallpaper path from loaded mappings
      var wallpaperPath = wallpaperPaths[newTheme]
      if (!wallpaperPath) {
        console.log("Warning: No wallpaper path found for theme:", newTheme)
        wallpaperPath = ""
      }

      console.log("Wallpaper path:", wallpaperPath)

      // Set pending values for the processes
      pendingThemeName = newTheme
      pendingThemeDisplayName = themes[newTheme].name
      pendingWallpaperPath = wallpaperPath

      // Start the chain: save state -> update theme -> switch wallpaper -> send notification
      // NOTE: currentTheme is updated AFTER file is written in themeStateSaver.onRunningChanged
      themeStateSaver.running = true

      // Re-enable file watcher after 3 seconds
      Qt.callLater(function() {
        var timer = Qt.createQmlObject('import QtQuick; Timer { interval: 3000; running: true; repeat: false; }', root)
        timer.triggered.connect(function() {
          ignoreFileWatcher = false
          console.log("File watcher re-enabled")
          timer.destroy()
        })
      })

      console.log("=== THEME SWITCH END ===")
    }
  }
}
