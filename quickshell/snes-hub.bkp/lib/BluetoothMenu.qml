import QtQuick
import QtQuick.Layouts
import Quickshell
import "../lib" as Lib
import "../theme.js" as Theme

ShellRoot {
    PanelWindow {
        id: window
        anchors { top: true; right: true }
        margins { top: 60; right: 20 }
        width: 320
        height: 450
        color: "transparent"

        Lib.Card {
            anchors.fill: parent
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                Text {
                    text: "Bluetooth Settings"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: Qt.rgba(1, 1, 1, 0.05)
                    radius: 10
                    Text {
                        anchors.centerIn: parent
                        text: "󰂯 Connected Devices"
                        color: "white"
                    }
                }

                Item { Layout.fillHeight: true }

                Lib.ExpressiveButton {
                    label: "Open Advanced Settings"
                    Layout.fillWidth: true
                    onClicked: {
                        Quickshell.execDetached(["blueman-manager"])
                        window.close()
                    }
                }
            }
        }
    }
}
