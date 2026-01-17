import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrLayerKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.namespace: "bluetooth-menu"

    // Hide hyprland borders
    function setBordersHidden(shouldHide) {
        Quickshell.execDetached(["hyprctl", "keyword", "general:border_size", shouldHide ? "0" : "1"])
    }

    onVisibleChanged: {
        setBordersHidden(visible)
        if (!visible) {
            viewStack.currentIndex = 0
            if (scanRunning) stopScan()
        } else {
            root.forceActiveFocus()
            refreshStatus()
            startScan()
        }
    }

    Component.onDestruction: {
        setBordersHidden(false)
        if (scanRunning) stopScan()
    }
        
    focusable: true
    Shortcut { sequence: "Esc"; onActivated: Qt.quit() }
    
    // -------- Constants --------
    readonly property int processTimeout: 10000

    // -------- Theme --------
    property string themeMode: "auto"
    property string themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"
    readonly property string envTheme: (Quickshell.env("QS_THEME") || "").trim().toLowerCase()

    property bool autoDark: true
    readonly property bool isDarkMode: {
        if (envTheme === "dark") return true
        if (envTheme === "light") return false
        if (themeMode === "dark") return true
        if (themeMode === "light") return false
        return autoDark
    }

    function applyAutoTheme(raw) {
        const m = String(raw || "").trim().toLowerCase()
        autoDark = (m !== "light")
    }

    FileView {
        path: root.themeModePath
        watchChanges: true
        preload: true
        onLoaded: {
            if (root.themeMode !== "auto") return
            if (root.envTheme === "dark" || root.envTheme === "light") return
            root.applyAutoTheme(text())
        }
        onTextChanged: {
            if (root.themeMode !== "auto") return
            if (root.envTheme === "dark" || root.envTheme === "light") return
            root.applyAutoTheme(text())
        }
        onFileChanged: reload()
        onLoadFailed: root.applyAutoTheme("dark")
    }

    // -------- Colors / Fonts --------
    readonly property color cBg:      isDarkMode ? "#6b3f443c" : "#97a382"
    readonly property color cBgAlt:   isDarkMode ? '#6b3f443c' : '#97a382'
    readonly property color cCard:    isDarkMode ? "#282c2d" : "#c1c3ae"
    readonly property color cFg:      isDarkMode ? "#D3C6AA" : "#1e2326"
    readonly property color cMuted:   isDarkMode ? "#859289" : '#4d6049'
    readonly property color cBorder:  isDarkMode ? '#d4708154' : '#d4586a3c'
    readonly property color cGreen:   isDarkMode ? "#A7C080" : "#576830"
    readonly property color cRed:     isDarkMode ? "#E67E80" : '#b13c3a'
    readonly property color cBlue:    isDarkMode ? '#7FBBB3' : '#5c7267'
    readonly property int   cRadius: 14

    readonly property string fontText: "Inter"
    readonly property string fontIcon: "JetBrainsMono Nerd Font"

    // outside click closes
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: (mouse) => {
            const inside =
                mouse.x >= menuCard.x && mouse.x <= (menuCard.x + menuCard.width) &&
                mouse.y >= menuCard.y && mouse.y <= (menuCard.y + menuCard.height)
            if (!inside) Qt.quit()
        }
    }

    // -------- State --------
    property bool isBusy: false
    property bool scanRunning: false
    property bool btEnabled: false
    property string statusLine: ""
    property color statusColor: cMuted

    Timer {
        id: statusTimer
        interval: 3200
        repeat: false
        onTriggered: statusLine = ""
    }

    function setStatus(msg, bad) {
        statusLine = msg
        statusColor = bad ? cRed : cMuted
        statusTimer.restart()
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    // Status Process
    Process {
        id: procStatus
        command: ["bash", "-c", "bluetoothctl show | grep 'Powered: yes'"]
        stdout: StdioCollector {
            onStreamFinished: {
                btEnabled = (String(text || "").trim().length > 0)
                if (!btEnabled) {
                    deviceModel.clear()
                    setStatus("Bluetooth is Off", true)
                } else {
                    refreshDevices()
                }
            }
        }
    }

    function refreshStatus() {
        procStatus.running = true
    }

    // Device Model
    ListModel { id: deviceModel }
    property var devMap: ({})

    function upsertDevice(mac, name, connected) {
        if (!mac) return
        
        let display = name
        if (!display || display === mac.replace(/-/g, ":")) display = "Unknown Device"

        if (devMap[mac] !== undefined) {
            const idx = devMap[mac]
            if (idx < deviceModel.count) {
                deviceModel.setProperty(idx, "name", display)
                deviceModel.setProperty(idx, "connected", connected)
            }
            return
        }

        deviceModel.append({
            mac: mac,
            name: display,
            connected: connected
        })
        devMap[mac] = deviceModel.count - 1
    }

    // Devices Processor
    Process {
        id: procDevices
        // Get paired devices and check connection status
        command: ["bash", "-c", `
            # List paired devices with connection status
            bluetoothctl devices | while read -r line; do
                mac=$(echo "$line" | cut -d' ' -f2)
                name=$(echo "$line" | cut -d' ' -f3-)
                info=$(bluetoothctl info "$mac")
                connected=$(echo "$info" | grep "Connected: yes")
                if [ -n "$connected" ]; then
                    echo "$mac|$name|yes"
                else
                    echo "$mac|$name|no"
                fi
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text || "").split(/\r?\n/)
                // Clear map if we want to remove stale devices, or just update existing
                // Simple approach: clear and rebuild for now to handle removals
                // Ideally we'd merge, but full refresh is safer for sync
                deviceModel.clear()
                devMap = ({})

                for (let line of lines) {
                    if (!line.trim()) continue
                    const parts = line.split("|")
                    if (parts.length < 3) continue
                    upsertDevice(parts[0], parts[1], parts[2] === "yes")
                }
            }
        }
    }
    
    function refreshDevices() {
        if (btEnabled) procDevices.running = true
    }

    // Scanner (Discovery)
    Process {
        id: scannerStart
        command: ["bluetoothctl", "scan", "on"]
    }
    Process {
        id: scannerStop
        command: ["bluetoothctl", "scan", "off"]
    }

    function startScan() {
        if (!btEnabled) return
        scanRunning = true
        scannerStart.running = true
        // Refresh devices list periodically during scan
        scanTimer.restart()
    }

    function stopScan() {
        scanRunning = false
        scanTimer.stop()
        scannerStop.running = true
    }

    Timer {
        id: scanTimer
        interval: 5000
        repeat: true
        onTriggered: refreshDevices()
    }

    // Actions
    Process {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                isBusy = false
                refreshStatus()
                refreshDevices()
            }
        }
    }

    function runCmd(cmd) {
        if (isBusy) return
        isBusy = true
        runner.command = ["bash", "-c", cmd]
        runner.running = true
    }

    function toggleBt() {
        runCmd("bluetoothctl power " + (btEnabled ? "off" : "on"))
    }

    function connectDevice(mac) {
        setStatus("Connecting…", false)
        runCmd("bluetoothctl connect " + shellQuote(mac))
    }

    function disconnectDevice(mac) {
         setStatus("Disconnecting…", false)
         runCmd("bluetoothctl disconnect " + shellQuote(mac))
    }

    function openAdvanced() {
        Quickshell.execDetached(["blueman-manager"])
        Qt.quit()
    }

    // -------- UI --------
    Rectangle {
        id: menuShadow
        anchors.fill: menuCard
        color: cCard
        radius: cRadius
        layer.enabled: true
        layer.effect: DropShadow {
            radius: 44
            samples: 64
            horizontalOffset: 0
            verticalOffset: 18
            color: Qt.rgba(0, 0, 0, root.isDarkMode ? 0.55 : 0.22)
        }
    }

    Rectangle {
        id: menuCard
        width: 390
        height: Math.ceil(mainLayout.implicitHeight + 24)
        x: 1042
        y: 44
        color: cCard
        radius: cRadius
        border.width: 1
        border.color: cBorder
        clip: true

        Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: mainLayout
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 14
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Bluetooth"
                    font.family: fontText
                    font.pixelSize: 18
                    font.weight: 800
                    color: cFg
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 46; height: 24
                    radius: 12
                    color: btEnabled ? Qt.rgba(cBlue.r, cBlue.g, cBlue.b, 0.95) : cBgAlt
                    border.width: 1
                    border.color: btEnabled ? Qt.rgba(cBlue.r, cBlue.g, cBlue.b, 0.55) : cBorder
                    
                    opacity: isBusy ? 0.6 : 1.0

                    Rectangle {
                        width: 18; height: 18
                        radius: 9
                        color: cCard
                        anchors.verticalCenter: parent.verticalCenter
                        x: btEnabled ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: isBusy ? Qt.ArrowCursor : Qt.PointingHandCursor
                        enabled: !isBusy
                        onClicked: toggleBt()
                    }
                }
            }

            // Status Bar
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 14
                color: cBgAlt
                visible: btEnabled

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Label {
                        text: "󰂯"
                        font.pixelSize: 22
                        font.family: fontIcon
                        color: cBlue
                    }
                    
                    Label {
                        text: scanRunning ? "Scanning…" : (statusLine !== "" ? statusLine : "Ready")
                        font.family: fontText
                        font.pixelSize: 14
                        color: statusColor
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                     MouseArea {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        cursorShape: Qt.PointingHandCursor
                        onClicked: openAdvanced()
                        Label {
                            anchors.centerIn: parent
                            text: "󰒓"
                            font.family: fontIcon
                            color: cMuted
                        }
                    }
                }
            }

            // Device List
            StackLayout {
                id: viewStack
                currentIndex: 0
                Layout.fillWidth: true
                Layout.preferredHeight: btEnabled ? (Math.min(deviceModel.count * 50, 400) + 10) : 60

                // 0: List
                ScrollView {
                    id: scrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ListView {
                        model: deviceModel
                        spacing: 4
                        width: parent.width

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 46
                            color: model.connected ? Qt.rgba(cBlue.r, cBlue.g, cBlue.b, 0.15) : "transparent"
                            radius: 8
                            border.width: model.connected ? 1 : 0
                            border.color: Qt.rgba(cBlue.r, cBlue.g, cBlue.b, 0.3)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Label {
                                    text: model.connected ? "󰂱" : "󰂯"
                                    font.family: fontIcon
                                    color: model.connected ? cBlue : cMuted
                                    font.pixelSize: 18
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label {
                                        text: model.name
                                        font.family: fontText
                                        font.weight: 600
                                        color: cFg
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        text: model.mac
                                        font.family: fontText
                                        font.pixelSize: 10
                                        color: cMuted
                                        visible: !model.connected
                                    }
                                }

                                Label {
                                    text: model.connected ? "D/C" : "Connect"
                                    visible: mouseArea.containsMouse || model.connected
                                    font.family: fontText
                                    font.pixelSize: 11
                                    color: model.connected ? cRed : cBlue
                                    padding: 4
                                    background: Rectangle {
                                        color: Qt.rgba(0,0,0,0.1)
                                        radius: 4
                                    }
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (model.connected) disconnectDevice(model.mac)
                                    else connectDevice(model.mac)
                                }
                            }
                        }
                    }

                    Label {
                        visible: !btEnabled
                        anchors.centerIn: parent
                        text: "Bluetooth is disabled"
                        color: cMuted
                        font.family: fontText
                    }
                    
                    Label {
                        visible: btEnabled && deviceModel.count === 0
                        anchors.centerIn: parent
                        text: "No devices found"
                        color: cMuted
                        font.family: fontText
                    }
                }
            }
        }
    }
}
