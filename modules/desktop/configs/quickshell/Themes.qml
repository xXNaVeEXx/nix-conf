pragma Singleton

import QtQuick

// Theme manager - Central theme registry and switcher
Singleton {
  id: root

  // Current active theme (persisted via file)
  property string currentTheme: "cyberpunk"

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
    }
  })

  // Load current theme from file
  Component.onCompleted: {
    loadCurrentTheme()
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
        if (newTheme && themes[newTheme] && newTheme !== currentTheme) {
          currentTheme = newTheme
        }
      }
    }
  }

  function loadCurrentTheme() {
    // Read current theme from persistent file
    // Default to cyberpunk
    currentTheme = "cyberpunk"
  }

  function getTheme(themeName) {
    return themes[themeName] || themes["cyberpunk"]
  }

  function getCurrentTheme() {
    return getTheme(currentTheme)
  }

  function switchTheme(newTheme) {
    if (themes[newTheme]) {
      currentTheme = newTheme
      // Trigger theme change script
      Qt.createQmlObject(
        'import Quickshell.Io; Process { running: true; command: ["/etc/nixos/modules/desktop/scripts/switch-theme.sh", "' + newTheme + '"]; }',
        root
      )
    }
  }
}
