import QtQuick
import Quickshell

ShellRoot {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }

      height: 30

      color: "#1e1e2e"

      Row {
        anchors.fill: parent
        spacing: 10
        padding: 5

        Text {
          text: "MangoWC"
          color: "#cdd6f4"
          font.pixelSize: 14
          font.bold: true
        }

        Item {
          width: parent.width - 200
        }

        Text {
          text: Qt.formatDateTime(new Date(), "ddd MMM dd hh:mm")
          color: "#cdd6f4"
          font.pixelSize: 12
        }
      }

      Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: parent.update()
      }
    }
  }
}
