import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Minimal, invisible stand-in for Omarchy's real Bar.qml. Waybar's own
// network/bluetooth modules stay the only visible icons; this window exists
// solely so NetworkPanel/BluetoothPanel and the qs.Ui components they build
// on (WidgetButton, KeyboardPanel) have a real backing window to anchor
// their popups to — KeyboardPanel resolves its screen via
// `anchorItem.QsWindow.window`, which requires the bar-icon buttons to
// actually live inside a window rather than a bare QtObject.
PanelWindow {
  id: root

  visible: true
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  implicitWidth: 1
  implicitHeight: 1

  anchors {
    top: true
    left: true
  }

  WlrLayershell.namespace: "bar-widgets-anchor"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  readonly property color foreground: Color.foreground
  readonly property color barForeground: Color.foreground
  readonly property color urgent: Color.urgent
  readonly property string fontFamily: Style.fontFamily
  readonly property bool foregroundAnimationEnabled: true

  readonly property string position: "top"
  readonly property bool vertical: false
  readonly property real barSize: Style.bar.sizeHorizontal

  property var activePopout: null
  function requestPopout(key) { activePopout = key }
  function releasePopout(key) { if (activePopout === key) activePopout = null }

  property var clickTargets: []
  function registerClickTarget(target) {
    if (clickTargets.indexOf(target) === -1) clickTargets.push(target)
  }
  function unregisterClickTarget(target) {
    var i = clickTargets.indexOf(target)
    if (i !== -1) clickTargets.splice(i, 1)
  }
  function targetBelongsToWindow(target, window) {
    return true
  }

  function showTooltip(item, text) {}
  function hideTooltip(item) {}

  function run(command) { Util.execDetached(command) }

  // omarchy.wifiqr / omarchy.speedtest satellite panels are not ported here
  // (see canShareWifi/canRunSpeedTest forced to false in NetworkPanel.qml);
  // this stub only guards the IPC-reachable showQr()/speedTest() functions
  // from crashing on a missing bar.shell.
  property QtObject shell: QtObject {
    function summon(pluginId, payloadJson) {
      console.warn("bar-widgets: summon() is not implemented for", pluginId)
    }
  }

  property var widgetsByModule: ({})
  function moduleWidgets(moduleName) {
    return widgetsByModule[moduleName] || []
  }
}
