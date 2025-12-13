import QtQuick
import QtQuick.Layouts
import Quickshell

// Reusable island component for modular bar
Rectangle {
  id: root

  property alias content: contentLoader.sourceComponent

  implicitWidth: contentLoader.item ? contentLoader.item.implicitWidth + 20 : 50
  implicitHeight: 30

  color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.6)
  border.color: Colors.border
  border.width: 1
  radius: 6

  // Blur effect background
  opacity: 0.95

  Loader {
    id: contentLoader
    anchors.centerIn: parent
  }
}
