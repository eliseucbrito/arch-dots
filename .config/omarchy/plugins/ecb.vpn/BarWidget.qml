import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// CIn VPN status pill. Left click opens the connection panel; the panel
// (not this widget) drives connect/disconnect so credentials never touch
// the bar layer.
BarWidget {
  id: root
  moduleName: "ecb.vpn"

  readonly property string scriptPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/ecb.vpn/scripts/vpn.sh"

  property bool connected: false
  property string statusText: "󰌿 VPN"
  property string tooltip: "VPN desconectada — clique para escolher"

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open()  { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target)        target.bar = root.bar
    if ("settings" in target)   target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = root
    if ("hostWidget" in target) target.hostWidget = root
    if ("scriptPath" in target) target.scriptPath = root.scriptPath
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "ecb.vpn"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Process {
    id: statusProc
    command: [root.scriptPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var status = Util.parseModuleJson(text)
        if (status.class === undefined) return  // mid-connect run gave no JSON; keep last known state
        root.connected = status.class === "connected"
        root.statusText = status.text || root.statusText
        root.tooltip = String(status.tooltip || "").replace(/\\n/g, "\n")
      }
    }
  }

  Timer {
    interval: root.setting("refreshIntervalSec", 10) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

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

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.statusText
    active: root.connected
    tooltipText: root.tooltip
    onPressed: root.togglePanel()
  }
}
