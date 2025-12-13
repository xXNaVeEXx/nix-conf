pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property string title: "Desktop"

  // Monitor active window title
  Process {
    id: titleMonitor
    running: true
    // Get active window title using hyprctl-like approach
    // This may need adjustment based on MangoWC's IPC
    command: ["sh", "-c", "while true; do mangoctl get-active-window-title 2>/dev/null || xdotool getactivewindow getwindowname 2>/dev/null || echo 'Desktop'; sleep 0.5; done"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var newTitle = data.trim()
        if (newTitle && newTitle.length > 0) {
          root.title = newTitle
        }
      }
    }
  }
}
