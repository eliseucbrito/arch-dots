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
    WlrLayershell.namespace: "toggl-menu"

    // Hide hyprland borders
    function setBordersHidden(shouldHide) {
        Quickshell.execDetached(["hyprctl", "keyword", "general:border_size", shouldHide ? "0" : "1"])
    }

    onVisibleChanged: {
        setBordersHidden(visible)
        if (visible) {
            root.forceActiveFocus()
            refreshStatus()
            descInput.forceActiveFocus()
        }
    }

    Component.onDestruction: {
        setBordersHidden(false)
    }
        
    focusable: true
    Shortcut { sequence: "Esc"; onActivated: Qt.quit() }

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
    readonly property color cBlue:    isDarkMode ? '#7FBBB3' : '#45707a'
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
    property bool timerRunning: false
    property string currentDescription: ""
    property string currentDuration: "00:00:00"
    property var startTime: null

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    // -------- API Interaction --------
    Process {
        id: procClient
        stdout: StdioCollector {
            onStreamFinished: {
                isBusy = false
                const raw = String(text || "").trim()
                if (!raw) return // Parsing error or empty

                try {
                    const data = JSON.parse(raw)
                    if (data && data.error) {
                        currentDescription = "Error: " + data.error
                        return
                    }

                    if (data && data.id) {
                        // Timer is running
                        timerRunning = true
                        currentDescription = data.description || "(no description)"
                        startTime = new Date(data.start)
                        updateDuration()
                    } else {
                        // Timer is stopped
                        timerRunning = false
                        currentDescription = "No timer running"
                        currentDuration = "00:00:00"
                        startTime = null
                    }
                } catch (e) {
                    console.error("JSON Parse error", e)
                }
            }
        }
    }

    function runClient(args) {
        if (isBusy) return
        isBusy = true
        // Assuming toggl_client.py is in the same dir as this QML file (lib/)
        // We need absolute path usually, or rely on CWD being correct?
        // Let's rely on absolute path construction if possible or relative
        const scriptPath = Quickshell.env("HOME") + "/dotfiles/quickshell/snes-hub/lib/toggl_client.py"
        procClient.command = ["python3", scriptPath].concat(args)
        procClient.running = true
    }

    function refreshStatus() {
        runClient(["status"])
    }

    function startTimer(desc) {
        if (!desc) return
        runClient(["start", desc])
    }

    function stopTimer() {
        runClient(["stop"])
    }

    // Duration Updater
    function updateDuration() {
        if (!startTime || !timerRunning) return
        const now = new Date()
        const diff = now - startTime
        
        const seconds = Math.floor((diff / 1000) % 60)
        const minutes = Math.floor((diff / (1000 * 60)) % 60)
        const hours = Math.floor((diff / (1000 * 60 * 60)))

        const pad = (n) => n < 10 ? "0" + n : n
        currentDuration = `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`
    }

    Timer {
        interval: 1000
        running: timerRunning && visible
        repeat: true
        onTriggered: updateDuration()
    }

    // -------- UI --------
    // Shadows
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
        width: 320
        height: Math.ceil(mainLayout.implicitHeight + 24)

        x: 1450 // Approximate position for right-side bar item
        y: 44

        color: cCard
        radius: cRadius
        border.width: 1
        border.color: cBorder
        clip: true

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Toggl Track"
                    font.family: fontText
                    font.pixelSize: 18
                    font.weight: 800
                    color: cFg
                    Layout.fillWidth: true
                }
                
                Rectangle {
                    width: 24; height: 24
                    color: "transparent"
                    Label {
                        anchors.centerIn: parent
                        text: ""
                        font.family: fontIcon
                        font.pixelSize: 14
                        color: isBusy ? cMuted : cFg
                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0; to: 360
                            duration: 1000
                            running: isBusy
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: refreshStatus()
                    }
                }
            }

            // Current Status
            Rectangle {
                Layout.fillWidth: true
                height: 60
                radius: 10
                color: cBgAlt
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    
                    Rectangle {
                        width: 36; height: 36
                        radius: 18
                        color: timerRunning ? cRed : cMuted
                        Label {
                            anchors.centerIn: parent
                            text: ""
                            font.family: fontIcon
                            font.pixelSize: 16
                            color: cCard
                        }
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: timerRunning ? currentDescription : "Idle"
                            font.family: fontText
                            font.weight: 600
                            font.pixelSize: 13
                            color: cFg
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: timerRunning ? currentDuration : "Ready to track"
                            font.family: fontText
                            font.pixelSize: 12
                            color: cMuted
                        }
                    }
                }
            }

            // Controls
            TextField {
                id: descInput
                Layout.fillWidth: true
                placeholderText: "What are you working on?"
                font.family: fontText
                font.pixelSize: 13
                color: cFg
                background: Rectangle {
                    color: cBg
                    radius: 8
                    border.width: 1
                    border.color: descInput.activeFocus ? cBlue : "transparent"
                }
                onAccepted: {
                     if (text.length > 0) {
                        startTimer(text)
                        text = ""
                        descInput.focus = false
                     }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                // Stop Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: timerRunning ? Qt.rgba(cRed.r, cRed.g, cRed.b, 0.2) : cBgAlt
                    opacity: timerRunning ? 1 : 0.5
                    enabled: timerRunning
                    
                    Label {
                        anchors.centerIn: parent
                        text: "Stop"
                        font.family: fontText
                        font.weight: 600
                        color: timerRunning ? cRed : cMuted
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: stopTimer()
                    }
                }

                // Start Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: descInput.text.length > 0 ? cBlue : cBgAlt
                    
                    Label {
                        anchors.centerIn: parent
                        text: "Start"
                        font.family: fontText
                        font.weight: 600
                        color: descInput.text.length > 0 ? cCard : cMuted
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (descInput.text.length > 0) {
                                startTimer(descInput.text)
                                descInput.text = ""
                            }
                        }
                    }
                }
            }
        }
    }
}
