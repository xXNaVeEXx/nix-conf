import QtQuick
import QtQuick.Layouts
import Quickshell

// Tag indicators displayed as dots (bottom right corner)
PanelWindow {
  id: root
  required property var modelData
  screen: modelData

  anchors {
    bottom: true
    right: true
  }

  margins {
    bottom: 10
    right: 15
  }

  implicitWidth: tagRow.width + 20
  implicitHeight: tagRow.height + 16

  color: "transparent"

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, Colors.glassAlpha)
    border.color: Colors.border
    border.width: 1
    radius: 8

    // Subtle glow effect
    layer.enabled: true
    layer.effect: ShaderEffect {
      property color glowColor: Colors.neonBlue
    }

    RowLayout {
      id: tagRow
      anchors.centerIn: parent
      spacing: 10

      Repeater {
        model: 5  // 5 tags

        Rectangle {
          id: tagDot
          width: 10
          height: 10
          radius: 5

          property bool isActive: (index + 1) === TagName.currentTag

          color: isActive ? Colors.neonBlue : Colors.inactive
          border.color: isActive ? Colors.borderGlow : Colors.border
          border.width: isActive ? 2 : 1

          // Glow effect for active tag
          layer.enabled: isActive
          layer.effect: ShaderEffect {
            property color glowColor: Colors.glowColor
            property real glowRadius: Colors.glowRadius
          }

          Behavior on color {
            ColorAnimation { duration: 200 }
          }

          Behavior on border.color {
            ColorAnimation { duration: 200 }
          }
        }
      }
    }
  }
}
