import QtQuick
import QtQuick.Layouts

// Tag indicators widget - displays tag dots
RowLayout {
  spacing: 8

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
