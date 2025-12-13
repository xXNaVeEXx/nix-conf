import QtQuick

Rectangle {
  id: root
  implicitWidth: tagText.width + 20
  implicitHeight: 24
  color: Colors.bgHighlight
  border.color: Colors.neonCyan
  border.width: 1
  radius: 4

  Text {
    id: tagText
    anchors.centerIn: parent
    text: "Tag " + TagName.currentTagName
    font.family: "GohuFont Nerd Font"
    font.pixelSize: 12
    font.bold: true
    color: Colors.neonCyan
  }
}
