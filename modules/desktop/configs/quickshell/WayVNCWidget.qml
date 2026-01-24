import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root
  implicitWidth: 24
  implicitHeight: 24
  radius: 4
  color: mouseArea.containsMouse ? Colors.bgHighlight : "transparent"
  border.color: WayVNC.isRunning ? Colors.success : Colors.border
  border.width: 1

  Text {
    anchors.centerIn: parent
    text: WayVNC.statusIcon
    font.family: "GohuFont Nerd Font"
    font.pixelSize: 12
    color: WayVNC.isRunning ? Colors.success : Colors.textDim
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: WayVNC.toggle()
  }

  // Tooltip on hover
  Rectangle {
    id: tooltip
    visible: mouseArea.containsMouse
    color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.95)
    border.color: WayVNC.isRunning ? Colors.success : Colors.border
    border.width: 1
    radius: 4
    width: tooltipText.width + 16
    height: tooltipText.height + 8

    x: (root.width - width) / 2
    y: root.height + 5
    z: 1000

    Text {
      id: tooltipText
      anchors.centerIn: parent
      text: WayVNC.isRunning ? "VNC: Running (click to stop)" : "VNC: Stopped (click to start)"
      font.family: "GohuFont Nerd Font"
      font.pixelSize: 10
      color: Colors.text
    }
  }
}
