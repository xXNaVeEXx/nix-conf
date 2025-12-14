pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  property int currentTag: 1
  property var tagNames: ["1", "2", "3", "4", "5"]

  // Monitor MangoWC for current tag (via IPC or wmctrl)
  Process {
    id: tagMonitor
    running: true
    command: ["sh", "-c", "while true; do mangoctl get-active-tag 2>/dev/null || echo '1'; sleep 0.5; done"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var tag = parseInt(data.trim())
        if (tag >= 1 && tag <= 5) {
          root.currentTag = tag
        }
      }
    }
  }

  readonly property string currentTagName: tagNames[currentTag - 1] || "1"
}
