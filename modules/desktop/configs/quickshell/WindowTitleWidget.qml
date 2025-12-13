import QtQuick

Text {
  id: root
  text: WindowTitle.title
  font.family: "GohuFont Nerd Font"
  font.pixelSize: 12
  color: Colors.text
  elide: Text.ElideRight
  maximumLineCount: 1

  // Limit width to prevent overflow
  width: Math.min(implicitWidth, 400)
}
