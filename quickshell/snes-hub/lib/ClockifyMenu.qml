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
    WlrLayershell.namespace: "clockify-menu"

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
        onLoaded: { if (root.themeMode === "auto") root.applyAutoTheme(text()) }
        onTextChanged: { if (root.themeMode === "auto") root.applyAutoTheme(text()) }
        onLoadFailed: root.applyAutoTheme("dark")
    }

    // -------- Colors / Fonts --------
    readonly property color cBg:      isDarkMode ? "#6b3f443c" : "#97a382"
    readonly property color cBgAlt:   isDarkMode ? '#6b3f443c' : '#97a382'
    readonly property color cCard:    isDarkMode ? "#282c2d" : "#c1c3ae"
    readonly property color cFg:      isDarkMode ? "#D3C6AA" : "#1e2326"
    readonly property color cMuted:   isDarkMode ? "#859289" : '#4d6049'
    readonly property color cBorder:  isDarkMode ? '#d4708154' : '#d4586a3c'
    
    // Clockify Blue
    readonly property color cAccent:  "#03a9f4"
    readonly property color cRed:     isDarkMode ? "#E67E80" : '#b13c3a'
    readonly property int   cRadius: 14

    readonly property string fontText: "Inter"
    readonly property string fontIcon: "JetBrainsMono Nerd Font"

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

    // Recent list model
    ListModel { id: recentModel }
    ListModel { id: projectModel }
    property var selectedProject: null

    // -------- API Interaction --------
    // 1. User Actions (Start/Stop/Projects/Force Refresh)
    Process {
        id: procClient
        stdout: StdioCollector {
            onStreamFinished: {
                // isBusy reset handled in onExited for safety, but we process data here
                const raw = String(text || "").trim()
                if (!raw) return

                try {
                    const data = JSON.parse(raw)
                    if (data && data.error) {
                         // Only show error in desc if it was an action
                         if (currentDescription === "Stopping..." || timerRunning) {
                             currentDescription = "Error: " + data.error
                         }
                         return
                    }

                    // Handle Project List
                    if (Array.isArray(data)) {
                        projectModel.clear()
                        data.forEach(p => projectModel.append(p))
                        return
                    }

                    // Handle Status Response (from Start/Stop or explicit status)
                    handleStatusData(data)

                } catch (e) {
                    console.error("Action JSON Parse error", e)
                }
            }
        }
        onExited: {
            console.log("procClient exited with code " + exitCode)
            isBusy = false
        }
    }

    // 2. Background Polling (Status only)
    Process {
        id: procPoll
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = String(text || "").trim()
                if (!raw) return
                try {
                    const data = JSON.parse(raw)
                    if (!data || data.error) return
                    handleStatusData(data)
                } catch (e) {}
            }
        }
    }

    function handleStatusData(data) {
        // Handle running entry
        var running = data.running
        if (running && running.id) {
            timerRunning = true
            currentDescription = running.description || "(no description)"
            startTime = new Date(running.timeInterval.start)
            updateDuration()
        } else {
            timerRunning = false
            currentDescription = "No timer running"
            currentDuration = "00:00:00"
            startTime = null
        }

        // Handle recent list
        if (data.recent && Array.isArray(data.recent)) {
             recentModel.clear()
             data.recent.forEach(item => {
                 recentModel.append({
                     desc: item.description || "(no description)",
                     projName: item.projectName || "",
                     projColor: item.projectColor || "#03a9f4",
                     projId: item.projectId
                 })
             })
        }
    }

    function runClient(args) {
        if (isBusy) return
        isBusy = true
        const scriptPath = Quickshell.env("HOME") + "/dotfiles/quickshell/snes-hub/lib/clockify_client.py"
        procClient.command = ["python3", scriptPath].concat(args)
        procClient.running = true
    }
    
    function runPoll() {
        if (procPoll.running) return
        const scriptPath = Quickshell.env("HOME") + "/dotfiles/quickshell/snes-hub/lib/clockify_client.py"
        procPoll.command = ["python3", scriptPath, "status"]
        procPoll.running = true
    }

    Component.onCompleted: {
        // Load cache instantly
        runClient(["status", "--cached"])
        // Then refresh live data
        Qt.callLater(() => refreshStatus())
        Qt.callLater(() => loadProjects(false))
    }

    // Auto-refresh while open
    Timer {
        interval: 5000; running: visible; repeat: true
        onTriggered: refreshStatus()
    }

    function refreshStatus() { runPoll() }
    function loadProjects(refresh) { 
        var args = ["projects"]
        if (refresh) args.push("--refresh")
        runClient(args) 
    }
    
    function startTimer(desc, projId) { 
        if(!desc) return
        
        // Optimistic UI Update
        timerRunning = true
        currentDescription = desc
        startTime = new Date()
        currentDuration = "00:00:00"
        
        var args = ["start", desc]
        if (projId) {
             args = args.concat(["--project", projId])
        } else if (selectedProject) {
             args = args.concat(["--project", selectedProject.id])
        }
        runClient(args) 
    }
    function stopTimer() { 
        // Optimistic UI Update
        timerRunning = false
        currentDescription = "Stopping..."
        startTime = null
        runClient(["stop"]) 
    }

    function updateDuration() {
        if (!startTime || !timerRunning) return
        const now = new Date()
        const diff = now.getTime() - startTime.getTime()
        
        if (diff < 0) {
            // Clock skew or just started
            currentDuration = "00:00:00"
            return
        }

        const seconds = Math.floor((diff / 1000) % 60)
        const minutes = Math.floor((diff / (1000 * 60)) % 60)
        const hours = Math.floor((diff / (1000 * 60 * 60)))
        
        const pad = (n) => n < 10 ? "0" + n : n
        currentDuration = `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`
    }

    Timer {
        interval: 1000; running: timerRunning && visible; repeat: true
        triggeredOnStart: true
        onTriggered: updateDuration()
    }

    // -------- UI --------
    Rectangle {
        id: menuShadow
        anchors.fill: menuCard
        color: cCard; radius: cRadius
        layer.enabled: true
        layer.effect: DropShadow {
            radius: 44; samples: 64; verticalOffset: 18
            color: Qt.rgba(0, 0, 0, root.isDarkMode ? 0.55 : 0.22)
        }
    }

    Rectangle {
        id: menuCard
        width: 340
        // Dynamically size based on content, but max height limit
        height: Math.min(600, mainLayout.implicitHeight + 40)
        
        x: 1450; y: 44
        color: cCard; radius: cRadius
        border.width: 1; border.color: cBorder
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
                    text: "Clockify"
                    font.family: fontText; font.pixelSize: 18; font.weight: 800
                    color: cAccent
                    Layout.fillWidth: true
                }
                Rectangle {
                    width: 24; height: 24; color: "transparent"
                    Label {
                        anchors.centerIn: parent
                        text: ""
                        font.family: fontIcon
                        font.pixelSize: 14
                        color: isBusy ? cMuted : cFg
                        RotationAnimation on rotation {
                            loops: Animation.Infinite; from: 0; to: 360; duration: 1000; running: isBusy
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: refreshStatus() }
                }
            }

            // Status Card
            Rectangle {
                Layout.fillWidth: true; height: 64
                radius: 10; color: cBgAlt
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 12
                    Rectangle {
                        width: 40; height: 40; radius: 20
                        color: timerRunning ? cAccent : cMuted
                        Label {
                            anchors.centerIn: parent
                            text: ""
                            font.family: fontIcon; font.pixelSize: 18; color: cCard
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Label {
                            text: timerRunning ? currentDescription : "Idle"
                            font.family: fontText; font.weight: 600; font.pixelSize: 13
                            color: cFg; elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Label {
                            text: timerRunning ? currentDuration : "Ready to track"
                            font.family: fontText; font.pixelSize: 12; color: timerRunning ? cAccent : cMuted
                        }
                    }
                }
            }

            // Input Area
            property bool selectingProject: false
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                // Project Button
                Item {
                    implicitWidth: 36; implicitHeight: 36
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    z: 10
                    
                    Rectangle {
                        id: projBtnBg
                        anchors.fill: parent; radius: 8
                        color: selectingProject ? cAccent : "transparent"
                        border.width: 1
                        border.color: selectingProject ? "transparent" : "#40808080"
                        
                        // Debug log to ensure this component is alive
                        Component.onCompleted: console.log("Project Button Background Loaded")
                    }

                    Label {
                        anchors.centerIn: parent
                        text: ""
                        font.family: fontIcon; font.pixelSize: 16
                        color: selectingProject ? cCard : (selectedProject ? selectedProject.color : cFg)
                    }

                    MouseArea { 
                        id: maProj; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            console.log("Project Button Clicked. State: " + selectingProject)
                            if (projectModel.count === 0) loadProjects(false)
                            selectingProject = !selectingProject
                        }
                    }
                }

                TextField {
                    id: descInput
                    Layout.fillWidth: true
                    placeholderText: selectedProject ? `[${selectedProject.name}] Description...` : "What are you working on?"
                    font.family: fontText; font.pixelSize: 13; color: cFg
                    background: Rectangle {
                        color: cBg; radius: 8
                        border.width: 1; border.color: descInput.activeFocus ? cAccent : "transparent"
                    }
                    onAccepted: {
                         if (text.length > 0) { startTimer(text); text = ""; descInput.focus = false }
                    }
                }
            }

            // Buttons
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                // Stop
                Rectangle {
                    Layout.fillWidth: true; height: 36; radius: 8
                    color: timerRunning ? Qt.rgba(cRed.r, cRed.g, cRed.b, 0.2) : cBgAlt
                    opacity: timerRunning ? 1 : 0.5; enabled: timerRunning
                    Label {
                        anchors.centerIn: parent
                        text: "Stop"
                        font.family: fontText; font.weight: 600
                        color: timerRunning ? cRed : cMuted
                    }
                    MouseArea { anchors.fill: parent; onClicked: stopTimer(); cursorShape: Qt.PointingHandCursor }
                }
                // Start
                Rectangle {
                    Layout.fillWidth: true; height: 36; radius: 8
                    color: descInput.text.length > 0 ? cAccent : cBgAlt
                    Label {
                        anchors.centerIn: parent
                        text: "Start"
                        font.family: fontText; font.weight: 600
                        color: descInput.text.length > 0 ? cCard : cMuted
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { if (descInput.text.length > 0) { startTimer(descInput.text); descInput.text = "" } }
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            // Divider
            Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; visible: true }

            // Header
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: selectingProject ? "Select Project" : "Recent Tasks"
                    font.family: fontText; font.pixelSize: 11; font.weight: 700; color: cMuted
                    Layout.fillWidth: true
                }
                // Clear selection button
                Label {
                     text: "Clear Project"
                     font.family: fontText; font.pixelSize: 10; color: cRed
                     visible: selectedProject !== null && !selectingProject
                     MouseArea { anchors.fill: parent; onClicked: selectedProject = null; cursorShape: Qt.PointingHandCursor }
                }
                // Refresh Projects
                Label {
                     text: "Refresh"
                     font.family: fontText; font.pixelSize: 10; color: cAccent
                     visible: selectingProject
                     MouseArea { anchors.fill: parent; onClicked: loadProjects(true); cursorShape: Qt.PointingHandCursor }
                }
            }

            // Project List
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: selectingProject ? 200 : 0
                Layout.maximumHeight: 200
                clip: true
                visible: height > 0
                
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                ListView {
                    anchors.fill: parent
                    model: projectModel
                    clip: true
                    
                    delegate: Rectangle {
                        width: ListView.view.width; height: 32; radius: 6
                        color: maPItem.containsMouse ? Qt.rgba(cAccent.r, cAccent.g, cAccent.b, 0.1) : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8
                            Rectangle { width: 8; height: 8; radius: 4; color: model.color }
                            Label { text: model.name; color: cFg; font.family: fontText; font.pixelSize: 12; Layout.fillWidth: true }
                        }
                        MouseArea {
                            id: maPItem
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                selectedProject = { id: model.id, name: model.name, color: model.color }
                                selectingProject = false
                            }
                        }
                    }
                }
                
                // Empty Project State
                Label {
                    visible: projectModel.count === 0
                    anchors.centerIn: parent
                    text: "No projects found."
                    color: cMuted; font.family: fontText; font.pixelSize: 12
                }
            }

            // Recent List
            ListView {
                visible: !selectingProject && recentModel.count > 0
                Layout.fillWidth: true
                Layout.preferredHeight: contentItem.childrenRect.height
                model: recentModel
                clip: true
                interactive: false
                
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 32
                    color: "transparent"
                    radius: 6
                    
                    Rectangle {
                        anchors.fill: parent
                        color: ma.containsMouse ? Qt.rgba(cAccent.r, cAccent.g, cAccent.b, 0.1) : "transparent"
                        radius: 6
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                        Label {
                            text: ""
                            font.family: fontIcon; font.pixelSize: 10; color: cMuted
                        }
                        
                        // Project Pill
                        Rectangle {
                            visible: model.projName !== ""
                            color: model.projColor
                            radius: 4
                            width: pLabel.width + 10; height: 16
                            Label { 
                                id: pLabel
                                anchors.centerIn: parent
                                text: model.projName
                                font.family: fontText; font.pixelSize: 9; font.weight: 700
                                color: "white" // contrast might differ but white usually works on colored bg
                            }
                        }

                        Label {
                            text: model.desc
                            font.family: fontText; font.pixelSize: 12; color: cFg
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Label {
                            text: ""
                            font.family: fontIcon; font.pixelSize: 10; color: ma.containsMouse ? cAccent : "transparent"
                        }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: startTimer(model.desc, model.projId)
                    }
                }
            }
        }
    }
}
