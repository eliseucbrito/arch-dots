import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.services

// Standalone Quickshell host for omarchy-format plugins (manifest.json +
// QML), running without the omarchy package or Hyprland. Waybar is the bar
// here — this process only hosts panel/overlay/menu plugins and answers
// IPC (`niri-omarchy-shell <plugin-id> toggle`) so a waybar custom/* module
// can trigger them.
//
// Ported from /usr/share/omarchy/shell/shell.qml, stripped of: the built-in
// Bar.qml loader, bar-widget/service kinds (not needed by capture/linear/
// gitlab-ci), shell.json persistence, and theme IPC — none of which this
// runtime's 3 target plugins touch. `shell`/`bar` objects keep the same
// method names/signatures the plugins already call. Panel hosting follows
// omarchy's own Instantiator-over-QtObject pattern (shell.qml:610-654) —
// a plain Repeater doesn't work here since ShellRoot has no visual parent
// to host delegate Items in.
ShellRoot {
  id: shell

  property PluginRegistry pluginRegistry: PluginRegistry {}

  // pluginId -> Loader, populated by registerPanelLoader/unregisterPanelLoader.
  property var panelLoaders: ({})

  function registerPanelLoader(pluginId, loader) {
    panelLoaders[pluginId] = loader
  }
  function unregisterPanelLoader(pluginId) {
    delete panelLoaders[pluginId]
  }

  // Reflectively injected into every loaded plugin instance, same pattern
  // omarchy uses ("shell" in item) — plugins declare `property var shell: null`.
  function openLoadedItem(loader, payloadJson) {
    var item = loader.item
    if (item && typeof item.open === "function") item.open(payloadJson || "{}")
  }

  function summon(pluginId, payloadJson) {
    var loader = panelLoaders[pluginId]
    if (!loader) {
      console.warn("shell.summon: unknown plugin " + pluginId)
      return
    }
    if (loader.item) {
      openLoadedItem(loader, payloadJson)
      return
    }
    // asynchronous: true means the component may still be loading — wait for
    // the real `loaded` signal instead of guessing with Qt.callLater, which
    // fires far too early for a cold (not keepLoaded) plugin.
    function onLoadedOnce() {
      loader.loaded.disconnect(onLoadedOnce)
      openLoadedItem(loader, payloadJson)
    }
    loader.loaded.connect(onLoadedOnce)
    loader.active = true
  }

  function hide(pluginId) {
    var loader = panelLoaders[pluginId]
    if (!loader || !loader.item) return
    var item = loader.item
    if (typeof item.close === "function") item.close()
  }

  function toggle(pluginId, payloadJson) {
    var loader = panelLoaders[pluginId]
    if (!loader) {
      console.warn("shell.toggle: unknown plugin " + pluginId)
      return
    }
    var item = loader.item
    var isOpen = !!(item && item.opened)
    if (isOpen) hide(pluginId)
    else summon(pluginId, payloadJson)
  }

  function isPluginOpen(pluginId) {
    var loader = panelLoaders[pluginId]
    var item = loader && loader.item
    return !!(item && item.opened)
  }

  // Stub of omarchy's Bar.qml. No visual bar here: waybar is the bar, so
  // linear/gitlab-ci's Panel.qml (which extends WidgetButton for their own
  // internal icon button) never actually renders this bar's buttons on
  // screen — but WidgetButton still calls these methods unconditionally
  // from Component.onCompleted/onEntered/onExited, so they need to exist
  // as no-ops rather than being read only when present.
  property QtObject bar: QtObject {
    readonly property color foreground: Color.foreground
    readonly property color urgent: Color.urgent
    readonly property string fontFamily: Style.font.family
    readonly property color barForeground: Color.foreground
    readonly property string position: "top"
    readonly property bool vertical: false
    readonly property int barSize: Style.bar.sizeHorizontal
    readonly property bool foregroundAnimationEnabled: true

    function hideTooltip(item) {}
    function showTooltip(item, text) {}
    function registerClickTarget(item) {}
    function unregisterClickTarget(item) {}

    // KeyboardPanel (used by linear/gitlab-ci's Panel-based popups) reads
    // these for bar-relative positioning and same-bar popout coordination.
    // No real bar window exists here, so click-forwarding/popout-switching
    // is inert — every KeyboardPanel just opens independently.
    readonly property var clickTargets: []
    property var activePopout: null
    function requestPopout(key) { activePopout = key }
    function releasePopout(key) { if (activePopout === key) activePopout = null }
    function targetBelongsToWindow(target, window) { return false }
    function switchPanelFrom(panel, direction) { return false }
  }

  // kind (manifest.kinds value) -> entryPoints key. bar-widget's entry point
  // is keyed "barWidget" (matching its manifest.barWidget metadata block),
  // everything else keys by its own kind name.
  readonly property var panelKinds: ["panel", "overlay", "menu", "bar-widget"]
  function entryPointKeyFor(kind) { return kind === "bar-widget" ? "barWidget" : kind }

  function computePanelEntries() {
    var out = []
    var installed = pluginRegistry.installedPlugins
    for (var id in installed) {
      var manifest = installed[id]
      if (!Array.isArray(manifest.kinds)) continue
      for (var k = 0; k < panelKinds.length; k++) {
        var kind = panelKinds[k]
        if (manifest.kinds.indexOf(kind) === -1) continue
        out.push({ id: id, manifest: manifest, kind: entryPointKeyFor(kind), keepLoaded: !!manifest.keepLoaded })
        break
      }
    }
    return out
  }

  property var panelEntries: []
  function refreshPanelEntries() { panelEntries = computePanelEntries() }

  Connections {
    target: pluginRegistry
    function onPluginsChanged() { shell.refreshPanelEntries() }
  }

  Timer {
    id: reloadDebounce
    interval: 150
    onTriggered: {
      Qt.clearComponentCache()
      pluginRegistry.rescan()
    }
  }
  Connections {
    target: pluginRegistry
    function onLocalPluginChanged(id) { reloadDebounce.restart() }
  }

  Instantiator {
    model: shell.panelEntries
    active: true

    delegate: QtObject {
      id: panelEntry
      required property var modelData
      readonly property string pluginId: modelData.id
      readonly property var manifest: modelData.manifest
      readonly property string entryKind: modelData.kind
      readonly property bool keepLoaded: modelData.keepLoaded === true
      readonly property string sourceUrl: shell.pluginRegistry.entryPointUrl(manifest, entryKind)

      property Loader panelLoader: Loader {
        source: panelEntry.sourceUrl
        active: panelEntry.sourceUrl !== "" && panelEntry.keepLoaded
        asynchronous: true
        onLoaded: {
          if (!item) return
          if ("shell" in item) item.shell = shell
          if ("bar" in item) item.bar = shell.bar
          if ("manifest" in item) item.manifest = panelEntry.manifest
        }
        onStatusChanged: {
          if (status === Loader.Error) {
            console.warn("panel plugin " + panelEntry.pluginId + " failed to load")
          }
        }
        Component.onCompleted: shell.registerPanelLoader(panelEntry.pluginId, this)
        Component.onDestruction: shell.unregisterPanelLoader(panelEntry.pluginId)
      }
    }
  }

  IpcHandler {
    target: "shell"

    function summon(pluginId: string, payload: string): void { shell.summon(pluginId, payload) }
    function hide(pluginId: string): void { shell.hide(pluginId) }
    function toggle(pluginId: string, payload: string): void { shell.toggle(pluginId, payload || "{}") }
    function isOpen(pluginId: string): string { return shell.isPluginOpen(pluginId) ? "true" : "false" }
    function rescanPlugins(): void { Qt.clearComponentCache(); shell.pluginRegistry.rescan() }
  }
}
