import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls 2.15
import QtQuick.Controls 2.15

// Keybindings Cheatsheet Widget - Shows all configured keybindings
Item {
  id: root

  property bool isVisible: false
  property int currentPage: 0
  property int totalPages: 3

  // Keybinding categories
  property var keybindings: ({
    "Applications": [
      { key: "ALT + Return", desc: "Launch terminal (wezterm)" },
      { key: "ALT + D", desc: "Application launcher (rofi)" }
    ],
    "Window Management": [
      { key: "ALT + Q", desc: "Kill focused window" },
      { key: "ALT + F", desc: "Toggle fullscreen" },
      { key: "ALT + Space", desc: "Toggle floating" },
      { key: "ALT + M", desc: "Minimize window" },
      { key: "ALT + X", desc: "Maximize window" },
      { key: "ALT + Tab", desc: "Cycle through windows" },
      { key: "ALT + Shift + H/J/K/L", desc: "Swap windows (vim keys)" }
    ],
    "Focus & Navigation": [
      { key: "ALT + H", desc: "Focus left" },
      { key: "ALT + J", desc: "Focus down" },
      { key: "ALT + K", desc: "Focus up" },
      { key: "ALT + L", desc: "Focus right" }
    ],
    "Tags (Workspaces)": [
      { key: "ALT + 1-5", desc: "Switch to tag 1-5" },
      { key: "ALT + N", desc: "Next tag" },
      { key: "ALT + P", desc: "Previous tag" },
      { key: "ALT + Shift + 1-5", desc: "Move window to tag 1-5" }
    ],
    "Layouts": [
      { key: "ALT + S", desc: "Scroller layout" },
      { key: "ALT + T", desc: "Master-stack (tiling)" },
      { key: "ALT + G", desc: "Grid layout" },
      { key: "ALT + O", desc: "Monocle (one window)" },
      { key: "ALT + , / .", desc: "Cycle layouts (prev/next)" }
    ],
    "Master-Stack Controls": [
      { key: "ALT + ]", desc: "Increase master size (+5%)" },
      { key: "ALT + [", desc: "Decrease master size (-5%)" },
      { key: "ALT + Shift + ]", desc: "Increase master count" },
      { key: "ALT + Shift + [", desc: "Decrease master count" }
    ],
    "System": [
      { key: "ALT + I", desc: "Toggle CPU/Memory widget" },
      { key: "ALT + R", desc: "Reload MangoWC config" },
      { key: "ALT + Shift + T", desc: "Theme switcher" },
      { key: "ALT + B", desc: "Keybindings cheatsheet (this)" },
      { key: "SUPER + M", desc: "Quit MangoWC (local only)" },
      { key: "SUPER + L", desc: "Lock screen (local only)" }
    ],
    "Clipboard & Screenshots": [
      { key: "ALT + Shift + V", desc: "Clipboard history" },
      { key: "ALT + Print", desc: "Full screenshot" },
      { key: "ALT + Shift + Print", desc: "Selection screenshot" }
    ],
    "Media Keys": [
      { key: "XF86AudioRaiseVolume", desc: "Volume up (+5%)" },
      { key: "XF86AudioLowerVolume", desc: "Volume down (-5%)" },
      { key: "XF86AudioMute", desc: "Mute toggle" },
      { key: "XF86MonBrightnessUp", desc: "Brightness up (+5%)" },
      { key: "XF86MonBrightnessDown", desc: "Brightness down (-5%)" },
      { key: "XF86AudioPlay", desc: "Play/Pause" },
      { key: "XF86AudioNext", desc: "Next track" },
      { key: "XF86AudioPrev", desc: "Previous track" }
    ]
  })

  property var categoryKeys: Object.keys(keybindings)
  property int itemsPerPage: 3

  // Floating window for cheatsheet
  Variants {
    model: Quickshell.screens

    delegate: Component {
      Scope {
        required property var modelData

        PanelWindow {
          id: cheatsheetWindow
          screen: modelData
          visible: root.isVisible
          focusable: true

          anchors {
            top: true
            left: true
          }

          margins {
            top: 50
            left: (modelData.width - 1000) / 2
          }

          implicitWidth: 1000
          implicitHeight: 600

        color: "transparent"
        mask: Region { item: container }

        Rectangle {
          id: container
          anchors.fill: parent
          color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.95)
          border.color: Colors.neonBlue
          border.width: 2
          radius: 12
          focus: true

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            // Header
            RowLayout {
              Layout.fillWidth: true
              spacing: 15

              Text {
                text: "  Keybindings Cheatsheet"
                font.family: "GohuFont Nerd Font"
                font.pixelSize: 20
                font.bold: true
                color: Colors.neonBlue
              }

              Item { Layout.fillWidth: true }

              Text {
                text: "Navigate: j/k  •  Close: Esc/q"
                font.family: "GohuFont Nerd Font"
                font.pixelSize: 10
                color: Colors.textDim
              }
            }

            Rectangle {
              height: 2
              Layout.fillWidth: true
              color: Colors.border
            }

            // Scrollable content
            Flickable {
              id: flickable
              Layout.fillWidth: true
              Layout.fillHeight: true
              contentHeight: contentColumn.height
              clip: true

              ScrollBar.vertical: ScrollBar {
                active: true
                policy: ScrollBar.AlwaysOn
              }

              Column {
                id: contentColumn
                width: parent.width
                spacing: 20

                Repeater {
                  model: root.categoryKeys

                  Column {
                    width: parent.width
                    spacing: 10

                    required property int index
                    required property string modelData

                    // Category header
                    Rectangle {
                      width: parent.width
                      height: 35
                      radius: 6
                      color: Qt.rgba(Colors.bgHighlight.r, Colors.bgHighlight.g, Colors.bgHighlight.b, 0.6)
                      border.color: Colors.neonCyan
                      border.width: 1

                      Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        font.family: "GohuFont Nerd Font"
                        font.pixelSize: 14
                        font.bold: true
                        color: Colors.neonCyan
                      }
                    }

                    // Keybindings in this category
                    Column {
                      width: parent.width
                      spacing: 5
                      leftPadding: 10

                      Repeater {
                        model: root.keybindings[modelData]

                        Rectangle {
                          width: parent.width - 10
                          height: 30
                          radius: 4
                          color: "transparent"

                          RowLayout {
                            anchors.fill: parent
                            anchors.margins: 5
                            spacing: 20

                            // Keybinding
                            Rectangle {
                              Layout.preferredWidth: 280
                              Layout.fillHeight: true
                              radius: 4
                              color: Qt.rgba(Colors.bgAlt.r, Colors.bgAlt.g, Colors.bgAlt.b, 0.8)
                              border.color: Colors.border
                              border.width: 1

                              Text {
                                anchors.centerIn: parent
                                text: modelData.key
                                font.family: "GohuFont Nerd Font Mono"
                                font.pixelSize: 11
                                font.bold: true
                                color: Colors.neonYellow
                              }
                            }

                            // Arrow
                            Text {
                              text: ""
                              font.family: "GohuFont Nerd Font"
                              font.pixelSize: 12
                              color: Colors.textDim
                            }

                            // Description
                            Text {
                              Layout.fillWidth: true
                              text: modelData.desc
                              font.family: "GohuFont Nerd Font"
                              font.pixelSize: 11
                              color: Colors.text
                              elide: Text.ElideRight
                            }
                          }
                        }
                      }
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
            RowLayout {
              Layout.fillWidth: true
              spacing: 15

              Text {
                text: "MangoWC + Quickshell  •  Cyberpunk Theme"
                font.family: "GohuFont Nerd Font"
                font.pixelSize: 10
                color: Colors.textDim
              }

              Item { Layout.fillWidth: true }

              Text {
                text: "Total: " + getTotalKeybindings() + " keybindings"
                font.family: "GohuFont Nerd Font"
                font.pixelSize: 10
                font.bold: true
                color: Colors.neonCyan
              }
            }
          }

          // Keyboard handling
          Keys.onPressed: (event) => {
            if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
              flickable.contentY = Math.min(flickable.contentY + 50, flickable.contentHeight - flickable.height)
              event.accepted = true
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
              flickable.contentY = Math.max(flickable.contentY - 50, 0)
              event.accepted = true
            } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
              root.isVisible = false
              event.accepted = true
            }
          }

          // Grab focus when container becomes visible
          Component.onCompleted: {
            if (root.isVisible) {
              forceActiveFocus()
            }
          }
        }

        // Grab focus on visibility change
        onVisibleChanged: {
          if (visible) {
            container.forceActiveFocus()
          }
        }
      }
    }
    }
  }

  function getTotalKeybindings() {
    var total = 0
    for (var category in keybindings) {
      total += keybindings[category].length
    }
    return total
  }

  function toggle() {
    isVisible = !isVisible
    if (isVisible) {
      currentPage = 0
    }
  }

  function show() {
    isVisible = true
  }

  function hide() {
    isVisible = false
  }
}
