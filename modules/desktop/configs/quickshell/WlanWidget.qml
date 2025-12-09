import QtQuick
import QtQuick.Layouts

Item {
  id: root
  implicitWidth: contentRow.width
  implicitHeight: contentRow.height

  RowLayout {
    id: contentRow
    spacing: 8

    // WiFi Icon
    Text {
      id: wifiIcon
      text: Wlan.connectionIcon
      font.family: "Symbols Nerd Font"
      font.pixelSize: 16
      color: Wlan.isConnected ? "#a6e3a1" : "#f38ba8"
    }

    // Current connection or status
    Text {
      id: connectionText
      text: Wlan.currentConnection
      font.pixelSize: 12
      color: "#cdd6f4"
    }
  }

  // Mouse area for hover interaction
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true

    onEntered: {
      if (Wlan.availableNetworks.length > 0) {
        networksPopup.visible = true
      }
    }

    onExited: {
      networksPopup.visible = false
    }
  }

  // Popup showing available networks (positioned outside layout)
  Rectangle {
    id: networksPopup
    visible: false
    color: "#1e1e2e"
    border.color: "#45475a"
    border.width: 1
    radius: 5
    width: 250
    height: Math.min(networksColumn.implicitHeight + 20, 300)

    // Position below the widget, aligned to right
    x: root.width - width
    y: root.height + 5

    z: 1000

    Column {
      id: networksColumn
      anchors.fill: parent
      anchors.margins: 10
      spacing: 5

      Text {
        text: "Available Networks"
        font.bold: true
        font.pixelSize: 12
        color: "#cdd6f4"
      }

      Repeater {
        model: Wlan.availableNetworks

        delegate: Rectangle {
          width: networksPopup.width - 20
          height: networkRow.height + 8
          color: modelData.active ? "#313244" : "transparent"
          radius: 3

          Row {
            id: networkRow
            anchors.centerIn: parent
            spacing: 10
            width: parent.width - 10

            Text {
              text: modelData.active ? "●" : "○"
              color: modelData.active ? "#a6e3a1" : "#6c7086"
              font.pixelSize: 10
            }

            Text {
              text: modelData.ssid
              color: "#cdd6f4"
              font.pixelSize: 11
              width: 140
              elide: Text.ElideRight
            }

            Text {
              text: modelData.signal + "%"
              color: "#94e2d5"
              font.pixelSize: 10
            }

            Text {
              text: modelData.security !== "" ? "🔒" : ""
              font.pixelSize: 10
            }
          }
        }
      }
    }
  }
}
