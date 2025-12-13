pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property real cpuUsage: 0.0
  property real memoryUsage: 0.0
  property real memoryTotal: 0.0
  property real memoryUsed: 0.0
  property bool visible: false

  // Watch toggle file
  Process {
    id: toggleWatcher
    running: true
    command: ["sh", "-c", "while true; do if [ -f /tmp/quickshell-sysinfo-visible ]; then echo 'true'; else echo 'false'; fi; sleep 0.5; done"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var newState = data.trim() === "true"
        if (root.visible !== newState) {
          root.visible = newState
        }
      }
    }
  }

  // Monitor system resources
  Process {
    id: sysMonitor
    running: true
    command: ["sh", "-c", "while true; do top -bn1 | grep 'Cpu(s)' | awk '{print $2}'; free -m | awk 'NR==2{print $3\" \"$2}'; sleep 2; done"]

    stdout: SplitParser {
      splitMarker: "\n"

      property int lineCount: 0

      onRead: data => {
        var trimmed = data.trim()
        if (trimmed === "") return

        if (lineCount % 2 === 0) {
          // CPU line
          var cpu = parseFloat(trimmed)
          if (!isNaN(cpu)) {
            root.cpuUsage = cpu
          }
        } else {
          // Memory line
          var parts = trimmed.split(' ')
          if (parts.length >= 2) {
            root.memoryUsed = parseFloat(parts[0])
            root.memoryTotal = parseFloat(parts[1])
            if (root.memoryTotal > 0) {
              root.memoryUsage = (root.memoryUsed / root.memoryTotal) * 100
            }
          }
        }

        lineCount++
      }
    }
  }

  function toggle() {
    visible = !visible
  }
}
