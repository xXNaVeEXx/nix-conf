pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  property bool isRunning: false
  property string statusIcon: "󰢹"  // VNC/remote desktop icon

  // Check if wayvnc is running on port 5900
  Process {
    id: statusChecker
    running: true
    command: ["sh", "-c", "while true; do ss -tlnp 2>/dev/null | grep -q ':5900 ' && echo 'running' || echo 'stopped'; sleep 3; done"]

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: data => {
        var status = data.trim()
        if (status === "running") {
          root.isRunning = true
          root.statusIcon = "󰢹"
        } else {
          root.isRunning = false
          root.statusIcon = "󰢹"
        }
      }
    }
  }

  // Start wayvnc process
  Process {
    id: startProcess
    command: ["sh", "-c", "wayvnc -C /etc/xdg/wayvnc/config 0.0.0.0 5900 &"]
  }

  // Stop wayvnc process
  Process {
    id: stopProcess
    command: ["pkill", "-f", "wayvnc"]
  }

  function toggle() {
    if (isRunning) {
      stopProcess.running = true
    } else {
      startProcess.running = true
    }
  }

  function start() {
    if (!isRunning) {
      startProcess.running = true
    }
  }

  function stop() {
    if (isRunning) {
      stopProcess.running = true
    }
  }
}
