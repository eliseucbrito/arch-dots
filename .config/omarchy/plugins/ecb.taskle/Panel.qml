import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "ecb.taskle"
  ipcTarget: "ecb.taskle"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property var tasks: []
  property string todayDate: Qt.formatDate(new Date(), "yyyy-MM-dd")

  function open() {
    refresh()
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function openFromHotkey() {
    open()
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    todayDate = Qt.formatDate(new Date(), "yyyy-MM-dd")
    if (!fetchTasksProc.running) fetchTasksProc.running = true
  }

  function formatEstimate(min) {
    if (min === undefined || min === null) return ""
    var h = Math.floor(min / 60)
    var m = min % 60
    if (h > 0 && m > 0) return "~" + h + "h" + m + "m"
    if (h > 0) return "~" + h + "h"
    return "~" + m + "m"
  }

  function getStatusIcon(status) {
    if (status === "done") return "✓"
    if (status === "in_progress") return "◐"
    if (status === "archived") return "⊘"
    return "○"
  }

  function getStatusColor(status) {
    if (status === "done") return "#50fa7b"
    if (status === "in_progress") return "#f1fa8c"
    return root.bar ? root.bar.foreground : "#f8f8f2"
  }

  function getDueColor(dueStr) {
    if (!dueStr) return "#8be9fd"
    if (dueStr < todayDate) return "#ff5555"
    if (dueStr === todayDate) return "#f1fa8c"
    return "#8be9fd"
  }

  function toggleTaskStatus(id, currentStatus) {
    var nextCmd = "done"
    if (currentStatus === "pending") nextCmd = "start"
    else if (currentStatus === "in_progress") nextCmd = "done"
    else if (currentStatus === "done") nextCmd = "undone"

    var proc = taskActionComponent.createObject(root, {
      command: ["/home/ecb/projects/personal/taskle/bin/taskle", nextCmd, id]
    })
    proc.running = true
  }

  Component {
    id: taskActionComponent
    Process {
      onExited: function(exitCode) {
        root.refresh()
        if (root.hostWidget && root.hostWidget.refresh) root.hostWidget.refresh()
      }
    }
  }

  Process {
    id: fetchTasksProc
    command: ["/home/ecb/projects/personal/taskle/bin/taskle", "list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) {
          root.tasks = []
          return
        }
        try {
          root.tasks = JSON.parse(raw)
        } catch(e) {
          root.tasks = []
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(Math.min(Style.space(420), contentCol.implicitHeight))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(12)
        spacing: Style.space(10)

        // Header Row
        Item {
          width: parent.width
          height: Style.space(26)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Text {
              text: "TASKLE"
              color: root.bar ? root.bar.foreground : "#f8f8f2"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: "(" + root.tasks.length + " active)"
              color: Qt.darker(root.bar ? root.bar.foreground : "#f8f8f2", 1.5)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Open Full TUI button
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: tuiLabel.implicitWidth + Style.space(14)
            height: Style.space(24)
            radius: 4
            color: tuiMouse.containsMouse ? Style.hoverFillFor(root.bar ? root.bar.foreground : "#f8f8f2", Color.accent) : "transparent"
            border.width: 1
            border.color: Qt.darker(root.bar ? root.bar.foreground : "#f8f8f2", 1.8)

            Text {
              id: tuiLabel
              anchors.centerIn: parent
              text: "Open TUI ↗"
              color: root.bar ? root.bar.foreground : "#f8f8f2"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: tuiMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.close()
                if (root.bar) root.bar.run("footclient --title taskle -e /home/ecb/projects/personal/taskle/bin/taskle tui")
              }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: Style.spacing.hairline
          color: root.bar ? root.bar.foreground : "#f8f8f2"
          opacity: 0.15
        }

        // Tasks List
        Flickable {
          width: parent.width
          height: Math.min(Style.space(340), tasksColumn.implicitHeight)
          contentWidth: width
          contentHeight: tasksColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          Column {
            id: tasksColumn
            width: parent.width
            spacing: Style.space(4)

            Text {
              visible: root.tasks.length === 0
              text: "  (No active tasks)"
              color: Qt.darker(root.bar ? root.bar.foreground : "#f8f8f2", 1.5)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.italic: true
              topPadding: Style.space(8)
            }

            Repeater {
              model: root.tasks

              Rectangle {
                id: taskItemRow
                required property var modelData
                required property int index
                width: parent.width
                height: taskRowLayout.implicitHeight + Style.space(8)
                radius: 4
                color: itemMouse.containsMouse ? Style.hoverFillFor(root.bar ? root.bar.foreground : "#f8f8f2", Color.accent) : "transparent"

                Row {
                  id: taskRowLayout
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(6)
                  anchors.rightMargin: Style.space(6)
                  spacing: Style.space(8)

                  // Status Icon (clickable to advance status)
                  Text {
                    text: root.getStatusIcon(modelData.Status)
                    color: root.getStatusColor(modelData.Status)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  // Task Description
                  Text {
                    text: modelData.Text
                    color: modelData.Status === "done" ? Qt.darker(root.bar ? root.bar.foreground : "#f8f8f2", 1.8) : (root.bar ? root.bar.foreground : "#f8f8f2")
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    font.strikeout: modelData.Status === "done"
                    elide: Text.ElideRight
                    width: Math.max(Style.space(120), parent.width - metaFlow.implicitWidth - Style.space(40))
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  // Metadata Badges (tags, project, urgent, due, etc)
                  Flow {
                    id: metaFlow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)

                    // !u
                    Text {
                      visible: !!modelData.Urgent
                      text: "!u"
                      color: "#ff5555"
                      font.bold: true
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.bodySmall
                    }

                    // !i
                    Text {
                      visible: !!modelData.Important
                      text: "!i"
                      color: "#f1fa8c"
                      font.bold: true
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.bodySmall
                    }

                    // @project
                    Text {
                      visible: !!modelData.Project
                      text: "@" + (modelData.Project || "")
                      color: "#8be9fd"
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.bodySmall
                    }

                    // #tags
                    Repeater {
                      model: modelData.Tags || []
                      Text {
                        required property string modelData
                        text: "#" + modelData
                        color: "#bd93f9"
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.bodySmall
                      }
                    }

                    // ~estimate
                    Text {
                      visible: modelData.EstimateMin !== null && modelData.EstimateMin !== undefined
                      text: root.formatEstimate(modelData.EstimateMin)
                      color: Qt.darker(root.bar ? root.bar.foreground : "#f8f8f2", 1.4)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.bodySmall
                    }

                    // ^due
                    Text {
                      visible: !!modelData.Due
                      text: "^" + (modelData.Due || "")
                      color: root.getDueColor(modelData.Due)
                      font.bold: modelData.Due <= root.todayDate
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.bodySmall
                    }
                  }
                }

                MouseArea {
                  id: itemMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleTaskStatus(modelData.ID, modelData.Status)
                }
              }
            }
          }
        }
      }
    }
  }
}
