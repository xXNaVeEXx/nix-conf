pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  property string currentConnection: "Disconnected"
  property string connectionIcon: "󰤮"
  property var availableNetworks: []
  property bool isConnected: false
  property bool isLanConnected: false
  property string lanInterface: ""

  // Combined network status check
  Process {
    id: networkStatus
    running: true
    command: ["sh", "-c", "while true; do nmcli -t -f DEVICE,TYPE,STATE dev; echo '---'; nmcli -t -f active,ssid,signal,security dev wifi 2>/dev/null || echo ''; echo '==='; sleep 5; done"]

    stdout: SplitParser {
      splitMarker: "==="

      onRead: data => {
        var sections = data.split('---');
        if (sections.length < 2) return;

        var devLines = sections[0].trim().split('\n').filter(line => line.trim() !== '');
        var wifiLines = sections[1].trim().split('\n').filter(line => line.trim() !== '');

        // Parse device status for LAN
        var lanConnected = false;
        var lanDevice = "";

        for (var i = 0; i < devLines.length; i++) {
          var parts = devLines[i].split(':');
          if (parts.length >= 3) {
            var device = parts[0];
            var type = parts[1];
            var state = parts[2];

            if (type === 'ethernet' && state === 'connected') {
              lanConnected = true;
              lanDevice = device;
              break;
            }
          }
        }

        root.isLanConnected = lanConnected;
        root.lanInterface = lanDevice;

        // Parse WiFi networks
        var networks = [];
        var wifiConnected = false;
        var wifiName = "";
        var wifiSignal = 0;

        for (var j = 0; j < wifiLines.length; j++) {
          var wifiParts = wifiLines[j].split(':');
          if (wifiParts.length >= 4) {
            var network = {
              active: wifiParts[0] === 'yes',
              ssid: wifiParts[1],
              signal: wifiParts[2],
              security: wifiParts[3]
            };

            if (network.active) {
              wifiConnected = true;
              wifiName = network.ssid;
              wifiSignal = parseInt(network.signal);
            }

            networks.push(network);
          }
        }

        root.availableNetworks = networks;

        // Update connection status
        if (lanConnected) {
          root.currentConnection = "LAN (" + lanDevice + ")";
          root.connectionIcon = "󰈀";
          root.isConnected = true;
        } else if (wifiConnected) {
          root.currentConnection = wifiName;
          root.isConnected = true;

          if (wifiSignal >= 80) {
            root.connectionIcon = "󰤨";
          } else if (wifiSignal >= 60) {
            root.connectionIcon = "󰤥";
          } else if (wifiSignal >= 40) {
            root.connectionIcon = "󰤢";
          } else if (wifiSignal >= 20) {
            root.connectionIcon = "󰤟";
          } else {
            root.connectionIcon = "󰤯";
          }
        } else {
          root.currentConnection = "Disconnected";
          root.isConnected = false;
          root.connectionIcon = "󰤮";
        }
      }
    }
  }
}
