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
      font.family: "GohuFont Nerd Font"
      font.pixelSize: 16
      color: Wlan.isConnected ? Colors.success : Colors.error
    }

    // Current connection or status
    Text {
      id: connectionText
      text: Wlan.currentConnection
      font.family: "GohuFont Nerd Font"
      font.pixelSize: 12
      color: Colors.text
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
    color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.95)
    border.color: Colors.neonBlue
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
        font.family: "GohuFont Nerd Font"
        font.bold: true
        font.pixelSize: 12
        color: Colors.neonBlue
      }

      Repeater {
        model: Wlan.availableNetworks

        delegate: Rectangle {
          width: networksPopup.width - 20
          height: networkRow.height + 8
          color: modelData.active ? Colors.bgHighlight : "transparent"
          radius: 3

          Row {
            id: networkRow
            anchors.centerIn: parent
            spacing: 10
            width: parent.width - 10

            Text {
              text: modelData.active ? "●" : "○"
              font.family: "GohuFont Nerd Font"
              color: modelData.active ? Colors.success : Colors.inactive
              font.pixelSize: 10
            }

            Text {
              text: modelData.ssid
              font.family: "GohuFont Nerd Font"
              color: Colors.text
              font.pixelSize: 11
              width: 140
              elide: Text.ElideRight
            }

            Text {
              text: modelData.signal + "%"
              font.family: "GohuFont Nerd Font"
              color: Colors.neonCyan
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
