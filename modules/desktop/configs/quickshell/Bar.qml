import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

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

        RowLayout {
          anchors.fill: parent
          anchors.margins: 5

          // Left side spacer
          Item {
            Layout.fillWidth: true
          }

          // Center - Clock Widget
          ClockWidget {
            Layout.alignment: Qt.AlignCenter
          }

          // Spacer
          Item {
            Layout.fillWidth: true
          }

          // Right side - WLAN Widget
          WlanWidget {
            Layout.alignment: Qt.AlignRight
          }
        }

      } // PanelWindow
    } // Component
  } // Variants

} // Scope
