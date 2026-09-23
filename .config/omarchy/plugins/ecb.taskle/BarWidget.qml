import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "ecb.taskle"

  property var currentTask: null
  property var candidateTasks: []
  property int currentTaskIndex: 0
  property string todayDate: Qt.formatDate(new Date(), "yyyy-MM-dd")

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    todayDate = Qt.formatDate(new Date(), "yyyy-MM-dd")
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
    if (!fetchTasksProc.running) fetchTasksProc.running = true
  }

  function rotateTask() {
    if (candidateTasks.length === 0) {
      currentTask = null
      return
    }
    currentTaskIndex = (currentTaskIndex + 1) % candidateTasks.length
    currentTask = candidateTasks[currentTaskIndex]
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
    else if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
  }

  function formatRelativeDays(dueStr) {
    if (!dueStr) return ""
    var parts = dueStr.split("-")
    if (parts.length !== 3) return "^" + dueStr
    var dueDate = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10))
    var now = new Date()
    var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    var diffMs = dueDate.getTime() - today.getTime()
    var diffDays = Math.round(diffMs / (1000 * 60 * 60 * 24))

    if (diffDays === 0) return "hoje"
    if (diffDays === 1) return "amanhã"
    if (diffDays === -1) return "ontem"
    if (diffDays < 0) return Math.abs(diffDays) + "d atrás"
    return "em " + diffDays + "d"
  }

  function getDueColor(dueStr) {
    if (!dueStr) return root.bar ? root.bar.foreground : "#f8f8f2"
    if (dueStr < todayDate) return "#ff5555"
    if (dueStr === todayDate) return "#f1fa8c"
    return "#8be9fd"
  }

  function buildTaskRichText() {
    if (!root.currentTask) return ""
    var baseColor = root.bar ? root.bar.barForeground : "#f8f8f2"
    var res = "<font color='" + baseColor + "'> " + root.currentTask.Text + "</font>"

    if (root.currentTask.Urgent) {
      res += " <font color='#ff5555'><b>!u</b></font>"
    }
    if (root.currentTask.Important) {
      res += " <font color='#f1fa8c'><b>!i</b></font>"
    }
    if (root.currentTask.Due) {
      var dueCol = getDueColor(root.currentTask.Due)
      var rel = formatRelativeDays(root.currentTask.Due)
      res += " <font color='" + dueCol + "'><b>^" + rel + "</b></font>"
    }
    return res
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  visible: currentTask !== null

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
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
          root.candidateTasks = []
          root.currentTask = null
          return
        }
        try {
          var parsed = JSON.parse(raw)
          var q1Tasks = [] // !u + !i
          var q3Tasks = [] // !u (apenas)
          var q2Tasks = [] // !i (apenas)

          for (var i = 0; i < parsed.length; i++) {
            var t = parsed[i]
            if (t.Urgent && t.Important) {
              q1Tasks.push(t)
            } else if (t.Urgent && !t.Important) {
              q3Tasks.push(t)
            } else if (!t.Urgent && t.Important) {
              q2Tasks.push(t)
            }
          }

          // Ordem de prioridade estrita: 1º (!u + !i), 2º (!u), 3º (!i)
          var sortedCandidates = [].concat(q1Tasks, q3Tasks, q2Tasks)
          root.candidateTasks = sortedCandidates

          if (sortedCandidates.length > 0) {
            if (root.currentTaskIndex >= sortedCandidates.length) {
              root.currentTaskIndex = 0
            }
            root.currentTask = sortedCandidates[root.currentTaskIndex]
          } else {
            root.currentTask = null
            root.currentTaskIndex = 0
          }
        } catch(e) {
          root.candidateTasks = []
          root.currentTask = null
        }
      }
    }
  }

  // Timer para busca/atualização das tarefas (a cada 30 segundos)
  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Timer para rotação periódica entre as tarefas qualificadas (a cada 15 minutos)
  Timer {
    interval: 900000 // 15 minutos (15 * 60 * 1000 ms)
    running: true
    repeat: true
    onTriggered: root.rotateTask()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.buildTaskRichText()
    labelVisible: true
    hasVisualContent: root.currentTask !== null

    tooltipText: "Taskle (" + (root.currentTaskIndex + 1) + "/" + root.candidateTasks.length + ")\nLeft-click: Quick View\nMiddle-click: Next Task / Refresh\nRight-click: Open Full TUI"

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) {
        root.bar.run("footclient --title taskle -e /home/ecb/projects/personal/taskle/bin/taskle tui")
      } else if (b === Qt.MiddleButton) {
        root.rotateTask()
      } else {
        root.togglePanel()
      }
    }
  }
}
