import Quickshell
import Quickshell.Io
import QtQuick

Scope {
  id: root

  // add a property in the root
  property string time

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        required property var modelData
        screen: modelData

        anchors {
          top: true
          left: true
          right: true
        }

        implicitHeight: 30

        ClockWidget {
          // remove the id as we don't need it anymore

          anchors.centerIn: parent
        } // Text


      } // PanelWindow
    } // Component
  } // Variants

} // Scope
