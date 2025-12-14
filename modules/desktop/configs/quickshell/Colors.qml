pragma Singleton

import QtQuick

// Exposes active theme colors
QtObject {
  id: root

  // Active colors object
  readonly property var active: ActiveColors

  // Primary colors
  readonly property color bg: active.bg
  readonly property color bgAlt: active.bgAlt
  readonly property color bgHighlight: active.bgHighlight

  // Neon accent colors
  readonly property color neonBlue: active.neonBlue
  readonly property color neonCyan: active.neonCyan
  readonly property color neonPurple: active.neonPurple
  readonly property color neonPink: active.neonPink
  readonly property color neonYellow: active.neonYellow

  // Text colors
  readonly property color text: active.text
  readonly property color textDim: active.textDim
  readonly property color textBright: active.textBright

  // Status colors
  readonly property color success: active.success
  readonly property color warning: active.warning
  readonly property color error: active.error
  readonly property color inactive: active.inactive

  // UI elements
  readonly property color border: active.border
  readonly property color borderGlow: active.borderGlow

  // Transparency values
  readonly property real glassAlpha: active.glassAlpha
  readonly property real hoverAlpha: active.hoverAlpha

  // Glow effects
  readonly property color glowColor: active.glowColor
  readonly property real glowRadius: active.glowRadius
}


