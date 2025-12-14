import QtQuick
import QtQuick.Layouts
import Quickshell

// Theme Switcher Widget - Horizontal layout with vim navigation (h/l)
Item {
  id: root

  property bool isVisible: false
  property int selectedIndex: 0
  property var themeKeys: Object.keys(Themes.themes)

  // Floating window for theme switcher
  Variants {
    model: Quickshell.screens

    delegate: Component {
      FloatingWindow {
        id: themeSwitcherWindow
        required property var modelData
        screen: modelData

        visible: root.isVisible

        width: 900
        height: 300

        color: "transparent"
        mask: Region { item: container }

        Rectangle {
          id: container
          anchors.fill: parent
          color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.95)
          border.color: Colors.neonBlue
          border.width: 2
          radius: 12

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            // Title
            RowLayout {
              Layout.fillWidth: true
              spacing: 15

              Text {
                text: "  Theme Switcher"
                font.family: "GohuFont Nerd Font"
                font.pixelSize: 18
                font.bold: true
                color: Colors.neonBlue
              }

              Item { Layout.fillWidth: true }

              // Help text
              Text {
                text: "Navigate: h/l  •  Select: Enter  •  Close: Esc/q"
                font.family: "GohuFont Nerd Font"
                font.pixelSize: 10
                color: Colors.textDim
              }
            }

            Rectangle {
              height: 1
              Layout.fillWidth: true
              color: Colors.border
            }

            // Horizontal theme carousel
            Row {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: 20
              Layout.alignment: Qt.AlignHCenter

              Repeater {
                model: root.themeKeys

                Rectangle {
                  width: 250
                  height: 180
                  radius: 12

                  required property int index
                  required property string modelData

                  property var themeData: Themes.themes[modelData]
                  property bool isSelected: index === root.selectedIndex
                  property bool isCurrent: modelData === Themes.currentTheme

                  color: isSelected ?
                    Qt.rgba(Colors.bgHighlight.r, Colors.bgHighlight.g, Colors.bgHighlight.b, 0.9) :
                    Qt.rgba(Colors.bgAlt.r, Colors.bgAlt.g, Colors.bgAlt.b, 0.6)

                  border.color: isSelected ? Colors.neonCyan : Colors.border
                  border.width: isSelected ? 3 : 1

                  // Scale effect for selected theme
                  scale: isSelected ? 1.05 : 1.0

                  Behavior on scale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                  }

                  Behavior on color {
                    ColorAnimation { duration: 150 }
                  }

                  Behavior on border.color {
                    ColorAnimation { duration: 150 }
                  }

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    // Current theme badge
                    Rectangle {
                      visible: isCurrent
                      Layout.alignment: Qt.AlignRight
                      width: 70
                      height: 20
                      radius: 4
                      color: Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.3)
                      border.color: Colors.success
                      border.width: 1

                      Text {
                        anchors.centerIn: parent
                        text: "● ACTIVE"
                        font.family: "GohuFont Nerd Font"
                        font.pixelSize: 9
                        font.bold: true
                        color: Colors.success
                      }
                    }

                    // Theme name
                    Text {
                      text: themeData.name
                      font.family: "GohuFont Nerd Font"
                      font.pixelSize: 16
                      font.bold: true
                      color: isSelected ? Colors.neonCyan : Colors.text
                      Layout.alignment: Qt.AlignHCenter
                    }

                    // Large color preview (gradient)
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: 70
                      radius: 8

                      gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: themeData.neonBlue }
                        GradientStop { position: 0.33; color: themeData.neonPurple }
                        GradientStop { position: 0.66; color: themeData.neonCyan }
                        GradientStop { position: 1.0; color: themeData.neonYellow }
                      }

                      border.color: themeData.borderGlow
                      border.width: 2

                      // Glow effect
                      layer.enabled: isSelected
                    }

                    // Description
                    Text {
                      text: themeData.description
                      font.family: "GohuFont Nerd Font"
                      font.pixelSize: 10
                      color: Colors.textDim
                      Layout.fillWidth: true
                      horizontalAlignment: Text.AlignHCenter
                      wrapMode: Text.WordWrap
                    }

                    Item { Layout.fillHeight: true }

                    // Selection indicator
                    Text {
                      visible: isSelected
                      text: "▲"
                      font.family: "GohuFont Nerd Font"
                      font.pixelSize: 16
                      color: Colors.neonCyan
                      Layout.alignment: Qt.AlignHCenter
                    }
                  }
                }
              }
            }

            Rectangle {
              height: 1
              Layout.fillWidth: true
              color: Colors.border
            }

            // Footer
            Text {
              text: "Press Enter to apply selected theme"
              font.family: "GohuFont Nerd Font"
              font.pixelSize: 11
              font.bold: true
              color: isSelected ? Colors.neonCyan : Colors.textDim
              Layout.alignment: Qt.AlignHCenter

              property bool isSelected: root.themeKeys[root.selectedIndex] !== Themes.currentTheme
            }
          }
        }

        // Keyboard handling - Horizontal vim navigation
        Keys.onPressed: (event) => {
          if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
            // Move left
            root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
            event.accepted = true
          } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
            // Move right
            root.selectedIndex = Math.min(root.selectedIndex + 1, root.themeKeys.length - 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            Themes.switchTheme(root.themeKeys[root.selectedIndex])
            root.visible = false
            event.accepted = true
          } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
            root.visible = false
            event.accepted = true
          }
        }
      }
    }
  }

  function toggle() {
    isVisible = !isVisible
    if (isVisible) {
      // Reset selection to current theme
      for (var i = 0; i < themeKeys.length; i++) {
        if (themeKeys[i] === Themes.currentTheme) {
          selectedIndex = i
          break
        }
      }
    }
  }

  function show() {
    isVisible = true
  }

  function hide() {
    isVisible = false
  }
}
