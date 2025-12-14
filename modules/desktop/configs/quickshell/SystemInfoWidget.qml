import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root
  visible: SystemInfo.isVisible
  implicitWidth: contentRow.width + 20
  implicitHeight: 24
  color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, Colors.glassAlpha)
  border.color: Colors.neonPurple
  border.width: 1
  radius: 4

  RowLayout {
    id: contentRow
    anchors.centerIn: parent
    spacing: 15

    // CPU Usage
    Row {
      spacing: 6

      Text {
        text: "󰻠"  // CPU icon
        font.family: "GohuFont Nerd Font"
        font.pixelSize: 14
        color: Colors.neonPurple
      }

      Text {
        text: SystemInfo.cpuUsage.toFixed(1) + "%"
        font.family: "GohuFont Nerd Font"
        font.pixelSize: 11
        color: SystemInfo.cpuUsage > 80 ? Colors.error : Colors.text
      }
    }

    // Separator
    Rectangle {
      width: 1
      height: 16
      color: Colors.border
    }

    // Memory Usage
    Row {
      spacing: 6

      Text {
        text: ""  // Memory icon
        font.family: "GohuFont Nerd Font"
        font.pixelSize: 14
        color: Colors.neonCyan
      }

      Text {
        text: SystemInfo.memoryUsage.toFixed(1) + "%"
        font.family: "GohuFont Nerd Font"
        font.pixelSize: 11
        color: SystemInfo.memoryUsage > 80 ? Colors.error : Colors.text
      }
    }
  }

  // Click to hide
  MouseArea {
    anchors.fill: parent
    onClicked: SystemInfo.toggle()
  }
}
