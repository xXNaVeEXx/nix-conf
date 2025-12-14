import QtQuick
import Quickshell

// Invisible hotspot at bottom of screen to trigger dock
PanelWindow {
  id: hotspot
  required property var modelData
  screen: modelData

  anchors {
    bottom: true
    left: true
    right: true
  }

  margins {
    bottom: 0
    left: 0
    right: 0
  }

  implicitWidth: modelData.width
  implicitHeight: 2  // Very thin hotspot area

  color: "transparent"

  // Signal to notify dock to show
  signal showDock()

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true

    onEntered: {
      hotspot.showDock()
    }
  }
}
