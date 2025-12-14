import Quickshell
import QtQuick
import QtQuick.Layouts

Scope {
  id: root

  Variants {
    model: Quickshell.screens

    delegate: Component {
      Scope {
        required property var modelData

        // Left Island - Tag Name + Window Title
        PanelWindow {
          id: leftIsland
          screen: modelData
          exclusiveZone: 35

          anchors {
            top: true
            left: true
          }

          margins {
            top: 5
            left: 10
          }

          implicitWidth: leftContent.width + 24
          implicitHeight: 30
          color: "transparent"

          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.6)
            border.color: Colors.border
            border.width: 1
            radius: 6
            opacity: 0.95

            RowLayout {
              id: leftContent
              anchors.centerIn: parent
              spacing: 15

              TagNameWidget {}

              Rectangle {
                width: 1
                height: 18
                color: Colors.border
              }

              WindowTitleWidget {}

              Rectangle {
                width: 1
                height: 18
                color: Colors.border
              }

              TagIndicators {}
            }
          }
        }

        // Center Island - Clock (centered using calculated left margin)
        PanelWindow {
          id: centerIsland
          screen: modelData
          exclusiveZone: 35

          anchors {
            top: true
            left: true
          }

          margins {
            top: 5
            left: (modelData.width - implicitWidth) / 2
          }

          implicitWidth: centerContent.width + 24
          implicitHeight: 30
          color: "transparent"

          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.6)
            border.color: Colors.neonBlue
            border.width: 1
            radius: 6
            opacity: 0.95

            RowLayout {
              id: centerContent
              anchors.centerIn: parent
              spacing: 8

              Text {
                text: ""
                font.family: "GohuFont Nerd Font"
                font.pixelSize: 14
                color: Colors.neonBlue
              }

              ClockWidget {}
            }
          }
        }

        // Right Island - System Info + WLAN
        PanelWindow {
          id: rightIsland
          screen: modelData
          exclusiveZone: 35

          anchors {
            top: true
            right: true
          }

          margins {
            top: 5
            right: 10
          }

          implicitWidth: rightContent.width + 24
          implicitHeight: 30
          color: "transparent"

          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.6)
            border.color: Colors.border
            border.width: 1
            radius: 6
            opacity: 0.95

            RowLayout {
              id: rightContent
              anchors.centerIn: parent
              spacing: 15

              SystemInfoWidget {}

              Rectangle {
                visible: SystemInfo.isVisible
                width: 1
                height: 18
                color: Colors.border
              }

              WlanWidget {}

              // System info toggle button
              Rectangle {
                width: 24
                height: 24
                radius: 4
                color: mouseArea.containsMouse ? Colors.bgHighlight : "transparent"
                border.color: SystemInfo.isVisible ? Colors.neonPurple : Colors.border
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: ""
                  font.family: "GohuFont Nerd Font"
                  font.pixelSize: 12
                  color: SystemInfo.isVisible ? Colors.neonPurple : Colors.textDim
                }

                MouseArea {
                  id: mouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: SystemInfo.toggle()
                }
              }
            }
          }
        }
      }
    }
  }
}
