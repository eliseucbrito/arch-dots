import QtQuick
import Quickshell
import "panels/network"
import "panels/bluetooth"

// Standalone quickshell instance hosting only the Network and Bluetooth
// panels ported from Omarchy's shell. Waybar stays the visible bar; this
// shell has no drawn widgets of its own — it exists so the two panels have
// somewhere to live and can be opened via IPC from waybar's on-click.
ShellRoot {
  id: shellRoot

  Variants {
    model: Quickshell.screens

    MiniBar {
      id: miniBar

      required property var modelData
      screen: modelData

      NetworkPanel {
        id: networkPanel
        bar: miniBar
      }

      BluetoothPanel {
        id: bluetoothPanel
        bar: miniBar
      }

      Component.onCompleted: {
        var widgets = {}
        widgets["omarchy.network"] = [networkPanel]
        widgets["omarchy.bluetooth"] = [bluetoothPanel]
        miniBar.widgetsByModule = widgets
      }
    }
  }
}
