pragma Singleton

import QtQuick

// Active colors - dynamically bound to current theme
QtObject {
  id: root

  property var theme: Themes.getCurrentTheme()

  // Update when theme changes
  Connections {
    target: Themes
    function onCurrentThemeChanged() {
      root.theme = Themes.getCurrentTheme()
    }
  }

  // Primary colors
  readonly property color bg: theme.bg
  readonly property color bgAlt: theme.bgAlt
  readonly property color bgHighlight: theme.bgHighlight

  // Neon accent colors
  readonly property color neonBlue: theme.neonBlue
  readonly property color neonCyan: theme.neonCyan
  readonly property color neonPurple: theme.neonPurple
  readonly property color neonPink: theme.neonPink
  readonly property color neonYellow: theme.neonYellow

  // Text colors
  readonly property color text: theme.text
  readonly property color textDim: theme.textDim
  readonly property color textBright: theme.textBright

  // Status colors
  readonly property color success: theme.success
  readonly property color warning: theme.warning
  readonly property color error: theme.error
  readonly property color inactive: theme.inactive

  // UI elements
  readonly property color border: theme.border
  readonly property color borderGlow: theme.borderGlow

  // Transparency values
  readonly property real glassAlpha: 0.3
  readonly property real hoverAlpha: 0.5

  // Glow effects
  readonly property color glowColor: theme.glowColor
  readonly property real glowRadius: 12
}
