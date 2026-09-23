import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  property var lastNotified: ({})
  property var inProgressTask: null
  property double idleStartTime: 0
  property bool wasIdle: false

  // Monitor idle activity using Wayland IdleMonitor (5 minutes threshold for work tracking)
  IdleMonitor {
    id: workIdleMonitor
    timeout: 300 // 5 minutes
    respectInhibitors: true
    onIsIdleChanged: {
      if (isIdle) {
        root.wasIdle = true
        root.idleStartTime = Date.now()
      } else {
        if (root.wasIdle) {
          var idleDurationMinutes = Math.round((Date.now() - root.idleStartTime) / 60000)
          root.wasIdle = false
          // Check if there was an in_progress task to notify
          if (root.inProgressTask && idleDurationMinutes >= 5) {
            Quickshell.execDetached([
              "omarchy-notification-send",
              "--urgency", "normal",
              "Taskle: Ausência detectada (" + idleDurationMinutes + "m)",
              "Você estava trabalhando em: \"" + root.inProgressTask.Text + "\". Continuar focado?"
            ])
          }
        }
      }
    }
  }

  Process {
    id: checkAgenda
    command: ["/home/ecb/projects/personal/taskle/bin/taskle", "agenda", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) return
        try {
          var parsed = JSON.parse(raw)
          var overdueCount = parsed.overdue ? parsed.overdue.length : 0
          var todayCount = parsed.today ? parsed.today.length : 0

          if (overdueCount > 0 && root.lastNotified.overdue !== overdueCount) {
            var overMsg = overdueCount === 1 
              ? "A tarefa \"" + parsed.overdue[0].Text + "\" está atrasada!"
              : overdueCount + " tarefas estão atrasadas!"
            Quickshell.execDetached(["omarchy-notification-send", "--urgency", "critical", "Taskle: Tarefas Atrasadas", overMsg])
            root.lastNotified.overdue = overdueCount
          }

          if (todayCount > 0 && root.lastNotified.today !== todayCount) {
            var todayMsg = todayCount === 1
              ? "A tarefa \"" + parsed.today[0].Text + "\" vence hoje!"
              : todayCount + " tarefas vencem hoje."
            Quickshell.execDetached(["omarchy-notification-send", "Taskle: Prazo Hoje", todayMsg])
            root.lastNotified.today = todayCount
          }
        } catch(e) {}
      }
    }
  }

  Process {
    id: checkActiveTasks
    command: ["/home/ecb/projects/personal/taskle/bin/taskle", "list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) {
          root.inProgressTask = null
          return
        }
        try {
          var parsed = JSON.parse(raw)
          var active = null
          for (var i = 0; i < parsed.length; i++) {
            if (parsed[i].Status === "in_progress") {
              active = parsed[i]
              break
            }
          }
          root.inProgressTask = active
        } catch(e) {
          root.inProgressTask = null
        }
      }
    }
  }

  // Periodic reminder checking (every 30 minutes for deadlines, 1 minute for active status tracking)
  Timer {
    interval: 1800000 // 30 minutes
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: checkAgenda.running = true
  }

  Timer {
    interval: 60000 // 1 minute
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: checkActiveTasks.running = true
  }
}
