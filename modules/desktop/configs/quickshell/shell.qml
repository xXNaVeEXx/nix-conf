import Quickshell
import Quickshell.Io
import QtQuick

Scope {
  // Dynamic-themed Quickshell configuration
  // Modular island bars + centered dock + tag indicators + theme switcher

  // Theme switcher widget (toggleable)
  ThemeSwitcher {
    id: themeSwitcher
  }

  // Keybindings cheatsheet widget (toggleable)
  KeybindingsCheatsheet {
    id: keybindingsCheatsheet
  }

  // Watch for widget toggle commands
  Process {
    id: commandWatcher
    running: true
    command: ["sh", "-c", "while true; do inotifywait -e modify /tmp/quickshell-command 2>/dev/null && cat /tmp/quickshell-command; sleep 0.1; done"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var cmd = data.trim()
        if (cmd === "toggle-theme-switcher") {
          themeSwitcher.toggle()
        } else if (cmd === "toggle-keybindings-cheatsheet") {
          keybindingsCheatsheet.toggle()
        }
      }
    }
  }

  // Top bar with modular islands (left, center, right)
  Bar {}

  // Bottom centered dock (Apple-style app launcher)
  Variants {
    model: Quickshell.screens
    delegate: Dock {}
  }

  // Tag indicators (bottom right corner dots)
  Variants {
    model: Quickshell.screens
    delegate: TagIndicators {}
  }
}