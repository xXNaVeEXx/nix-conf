import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Bottom centered dock (macOS-style) with persistent apps and auto-hide
PanelWindow {
  id: root
  required property var modelData
  screen: modelData

  anchors {
    bottom: true
    left: true
  }

  margins {
    bottom: dockVisible ? 10 : -55
    left: (modelData.width - implicitWidth) / 2
  }

  implicitWidth: dockLayout.width + 20
  implicitHeight: 60

  color: "transparent"

  // Auto-hide state - starts hidden
  property bool dockVisible: false
  property bool mouseInDock: false

  // Timer to hide dock after 3 seconds
  Timer {
    id: hideTimer
    interval: 3000
    running: false
    repeat: false
    onTriggered: {
      if (!mouseInDock) {
        dockVisible = false
      }
    }
  }

  // Mouse area for dock interaction
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    propagateComposedEvents: true

    onEntered: {
      mouseInDock = true
      dockVisible = true
      hideTimer.stop()
    }

    onExited: {
      mouseInDock = false
      hideTimer.restart()
    }
  }

  // Smooth animation for showing/hiding
  Behavior on margins.bottom {
    NumberAnimation {
      duration: 250
      easing.type: Easing.OutCubic
    }
  }

  // List of pinned apps that always appear in the dock
  property var pinnedApps: [
    { icon: "utilities-terminal", label: "Term", name: "Terminal", command: "wezterm", class: "wezterm" },
    { icon: "brave-browser", label: "Brave", name: "Browser", command: "brave", class: "Brave-browser" },
    { icon: "system-file-manager", label: "Files", name: "Files", command: "nautilus", class: "Org.gnome.Nautilus" },
    { icon: "code", label: "Code", name: "VS Code", command: "code", class: "Code" },
    { icon: "spotify", label: "Music", name: "Spotify", command: "spotify", class: "Spotify" }
  ]

  // Track running applications
  property var runningApps: []

  // Monitor running windows
  Process {
    id: windowMonitor
    running: true
    command: ["sh", "-c", "while true; do mmsg -w 2>/dev/null | grep -o 'class:[^,]*' | cut -d: -f2; sleep 1; done"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var appClass = data.trim()
        if (appClass && appClass.length > 0) {
          // Update running apps list
          if (root.runningApps.indexOf(appClass) === -1) {
            root.runningApps = root.runningApps.concat([appClass])
          }
        }
      }
    }
  }

  Rectangle {
    id: dockContainer
    anchors.fill: parent
    color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.7)
    border.color: Colors.neonBlue
    border.width: 2
    radius: 15

    // Glass/blur effect
    opacity: 0.9

    RowLayout {
      id: dockLayout
      anchors.centerIn: parent
      spacing: 15

      // Pinned apps
      Repeater {
        model: root.pinnedApps

        delegate: Rectangle {
          id: appIcon
          width: 45
          height: 45
          radius: 10
          color: Qt.rgba(Colors.bgHighlight.r, Colors.bgHighlight.g, Colors.bgHighlight.b, 0.5)
          border.color: mouseArea.containsMouse ? Colors.neonCyan : (isRunning ? Colors.neonBlue : "transparent")
          border.width: isRunning ? 2 : (mouseArea.containsMouse ? 2 : 0)

          property bool isRunning: root.runningApps.indexOf(modelData.class) !== -1

          // Show icon using system icon theme
          Column {
            anchors.centerIn: parent
            spacing: 4

            Image {
              anchors.horizontalCenter: parent.horizontalCenter
              source: "image://icon/" + modelData.icon
              width: 32
              height: 32
              smooth: true
              fillMode: Image.PreserveAspectFit

              // Colorize icon based on running state
              layer.enabled: true
              layer.effect: ShaderEffect {
                property color tintColor: isRunning ? Colors.neonCyan : Colors.neonBlue
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.label
              font.family: "GohuFont Nerd Font"
              font.pixelSize: 9
              color: isRunning ? Colors.neonCyan : Colors.text
            }
          }

          // Running indicator (dot below icon)
          Rectangle {
            visible: isRunning
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: -6
            width: 4
            height: 4
            radius: 2
            color: Colors.neonCyan

            // Pulsing animation for running apps
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              running: isRunning
              NumberAnimation { from: 1.0; to: 0.3; duration: 1000 }
              NumberAnimation { from: 0.3; to: 1.0; duration: 1000 }
            }
          }

          MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
              // Launch application
              Qt.createQmlObject(
                'import Quickshell.Io; Process { running: true; command: ["' + modelData.command + '"]; }',
                root
              )
            }
          }

          // Hover animation
          scale: mouseArea.containsMouse ? 1.2 : 1.0
          Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
          }

          // Tooltip
          Rectangle {
            visible: mouseArea.containsMouse
            anchors.bottom: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 8
            width: tooltipText.width + 16
            height: 24
            color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.9)
            border.color: Colors.neonBlue
            border.width: 1
            radius: 4
            z: 100

            Text {
              id: tooltipText
              anchors.centerIn: parent
              text: modelData.name + (isRunning ? " (Running)" : "")
              font.family: "GohuFont Nerd Font"
              font.pixelSize: 11
              color: Colors.text
            }
          }
        }
      }
    }
  }
}
