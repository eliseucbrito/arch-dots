import Quickshell
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: btRoot
    width: 300
    height: 400
    color: "#1e1e2e" // Cor base (ex: Catppuccin Mocha)
    radius: 15
    border.color: Qt.rgba(1, 1, 1, 0.1)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // --- CABEÇALHO COM TOGGLE ---
        RowLayout {
            Text {
                text: "Bluetooth"
                color: "white"
                font.pixelSize: 18
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            
            // Switch de Power (Simulado)
            Rectangle {
                width: 45; height: 24; radius: 12
                color: btOn.value ? "#a6e3a1" : "#45475a"
                
                Rectangle {
                    width: 20; height: 20; radius: 10
                    x: btOn.value ? 22 : 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: "white"
                    Behavior on x { NumberAnimation { duration: 200 } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: toggleBt() // Usa a função que você já tem
                }
            }
        }

        // --- STATUS DO DISPOSITIVO ATUAL ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: Qt.rgba(1, 1, 1, 0.05)
            radius: 12

            RowLayout {
                anchors.centerIn: parent
                spacing: 15
                Text {
                    text: "󰂯"
                    font.pixelSize: 40
                    color: btOn.value ? "#89b4fa" : "#585b70"
                }
                Column {
                    Text {
                        text: btDev.value || "Not Connected"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }
                    Text {
                        text: btOn.value ? "Discoverable" : "Bluetooth is Off"
                        color: "#bac2de"
                        font.pixelSize: 12
                    }
                }
            }
        }

        Item { Layout.fillHeight: true } // Espaçador

        // --- BOTÃO DE CONFIGURAÇÕES AVANÇADAS ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 45
            radius: 10
            color: advMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.2)

            RowLayout {
                anchors.centerIn: parent
                spacing: 10
                Text { text: "󰒓"; color: "white"; font.pixelSize: 16 }
                Text { text: "Open Advanced Settings"; color: "white"; font.pixelSize: 14 }
            }

            MouseArea {
                id: advMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    // Executa o Blueman-Manager que você instalou
                    det("blueman-manager") 
                }
            }
        }
    }
}
