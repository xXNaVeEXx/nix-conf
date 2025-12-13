import QtQuick
import QtQuick.Layouts
import Quickshell

// Bottom centered dock (Apple-style)
PanelWindow {
  id: root
  required property var modelData
  screen: modelData

  anchors {
    bottom: true
    horizontally: "center"
  }

  margins {
    bottom: 10
  }

  implicitWidth: dockLayout.width + 20
  implicitHeight: 60

  color: "transparent"

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

      // Define your favorite apps here
      Repeater {
        model: [
          { icon: "", name: "Terminal", command: "wezterm" },
          { icon: "", name: "Browser", command: "brave" },
          { icon: "", name: "Files", command: "nautilus" },
          { icon: "", name: "Code", command: "code" },
          { icon: "", name: "Music", command: "spotify" }
        ]

        delegate: Rectangle {
          id: appIcon
          width: 45
          height: 45
          radius: 10
          color: Qt.rgba(Colors.bgHighlight.r, Colors.bgHighlight.g, Colors.bgHighlight.h, 0.5)
          border.color: mouseArea.containsMouse ? Colors.neonCyan : "transparent"
          border.width: 2

          Text {
            anchors.centerIn: parent
            text: modelData.icon
            font.family: "GohuFont Nerd Font"
            font.pixelSize: 24
            color: Colors.neonBlue
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
              text: modelData.name
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
