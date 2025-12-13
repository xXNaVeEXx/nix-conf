pragma Singleton

import QtQuick

// Cyberpunk Dark Blue Neon Theme
// Inspired by night city aesthetics with electric blue accents
QtObject {
  id: root

  // Primary colors - Dark blue base
  readonly property color bg: "#0a0e27"              // Deep dark blue background
  readonly property color bgAlt: "#151b3d"           // Slightly lighter blue
  readonly property color bgHighlight: "#1e2749"     // Highlighted background

  // Neon accent colors
  readonly property color neonBlue: "#00d9ff"        // Electric blue (primary accent)
  readonly property color neonCyan: "#00ffcc"        // Cyan accent
  readonly property color neonPurple: "#a78bfa"      // Purple accent
  readonly property color neonPink: "#ff00ff"        // Magenta accent
  readonly property color neonYellow: "#ffed4e"      // Warning/highlight

  // Text colors
  readonly property color text: "#e0e7ff"            // Light blue-white text
  readonly property color textDim: "#8b95c9"         // Dimmed text
  readonly property color textBright: "#ffffff"      // Bright white

  // Status colors
  readonly property color success: "#00ffcc"         // Cyan (connected, active)
  readonly property color warning: "#ffed4e"         // Yellow
  readonly property color error: "#ff0055"           // Neon red
  readonly property color inactive: "#4a5580"        // Inactive/disabled

  // UI elements
  readonly property color border: "#2d3a6e"          // Border color
  readonly property color borderGlow: "#00d9ff"      // Glowing border (accent)

  // Transparency values
  readonly property real glassAlpha: 0.3             // For blur backgrounds
  readonly property real hoverAlpha: 0.5             // Hover states

  // Glow effects
  readonly property color glowColor: "#00d9ff"       // Neon glow
  readonly property real glowRadius: 12              // Glow spread
}
