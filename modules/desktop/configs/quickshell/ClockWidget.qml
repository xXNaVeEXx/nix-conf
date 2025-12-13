import QtQuick

Text {
  text: Qt.formatDateTime(new Date(), "ddd HH:mm")
  font.family: "GohuFont Nerd Font"
  font.pixelSize: 13
  font.bold: true
  color: Colors.neonBlue

  // Update every second
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: parent.text = Qt.formatDateTime(new Date(), "ddd HH:mm")
  }
}
