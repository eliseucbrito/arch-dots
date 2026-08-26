import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// CIn VPN connection picker: lists OpenVPN/IKEv2 profiles from vpn.sh list,
// asks for a password inline when connecting, and disconnects whatever is
// active. Replaces the old waybar+walker dmenu with a native panel so no
// external launcher is required.
Panel {
  id: root
  moduleName: "ecb.vpn"
  ipcTarget: ""
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string scriptPath: ""

  readonly property var barIdentity: hostWidget || root
  readonly property color fg: bar ? bar.foreground : Color.popups.text
  readonly property string ff: bar ? bar.fontFamily : Style.font.family

  function dim(alpha) { return Qt.rgba(fg.r, fg.g, fg.b, alpha) }

  property bool connected: false
  property var activeName: null
  property var profiles: []  // [{kind, name}]

  // Profile awaiting a password ({kind, name}), or null when the list is shown.
  property var pending: null
  property bool connecting: false
  property string errorText: ""

  function glyphFor(kind) { return kind === "ike" ? "󰦝" : "󰖟" }
  function labelFor(kind) { return kind === "ike" ? "IKEv2" : "OpenVPN" }

  function open() {
    root.controller.show()
    root.pending = null
    root.errorText = ""
    root.refresh()
  }

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function startConnect(entry) {
    root.errorText = ""
    root.pending = entry
    Qt.callLater(function() { pwField.forceActiveFocus() })
  }

  function cancelConnect() {
    root.pending = null
    pwField.text = ""
  }

  function submitConnect() {
    if (!root.pending || root.connecting) return
    root.connecting = true
    connectProc.secret = pwField.text
    connectProc.command = [root.scriptPath,
      root.pending.kind === "ike" ? "connect-ike" : "connect-ovpn", root.pending.name]
    connectProc.running = true
  }

  function disconnectAll() {
    root.errorText = ""
    disconnectProc.running = true
  }

  Process {
    id: listProc
    command: [root.scriptPath, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text || "{}")
          root.connected = data.connected === true
          root.activeName = data.active || null
          root.profiles = Array.isArray(data.profiles) ? data.profiles : []
        } catch (e) {
          root.profiles = []
        }
      }
    }
  }

  // Password goes over stdin, never argv — matches the pattern used by the
  // built-in network panel's enterprise-WiFi connect.
  Process {
    id: connectProc
    property string secret: ""
    stdinEnabled: true
    onStarted: { write(secret + "\n"); secret = "" }
    onExited: {
      root.connecting = false
      root.pending = null
      pwField.text = ""
      root.refresh()
    }
  }

  Process {
    id: disconnectProc
    command: [root.scriptPath, "disconnect"]
    onExited: root.refresh()
  }

  // KeyboardPanel (not PopupCard) because the password field needs real
  // Wayland keyboard focus: PopupCard's HyprlandFocusGrab only routes
  // pointer input to the popup surface, so forceActiveFocus() on a TextField
  // inside it never actually receives key events. KeyboardPanel primes
  // WlrLayershell.keyboardFocus on open, which is what lets focusTarget
  // (and pwField's own forceActiveFocus below) work.
  KeyboardPanel {
    id: card
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.barIdentity
    open: root.opened
    focusTarget: pwField
    contentWidth: card.fittedContentWidth(Style.space(300))
    contentHeight: card.fittedContentHeight(content.implicitHeight, Style.space(420))

    Column {
      id: content
      width: parent.width
      spacing: Style.space(10)

      Item {
        width: parent.width
        implicitHeight: headGlyph.implicitHeight

        Text {
          id: headGlyph
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: root.connected ? "󰌾" : "󰌿"
          color: root.connected ? Color.accent : root.dim(0.8)
          font.family: root.ff
          font.pixelSize: Style.font.icon
        }

        Text {
          anchors.left: headGlyph.right
          anchors.leftMargin: Style.space(8)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          elide: Text.ElideRight
          text: root.connected ? ("Conectado · " + (root.activeName || "")) : "VPN desconectada"
          color: root.fg
          font.family: root.ff
          font.pixelSize: Style.font.body
          font.bold: true
        }
      }

      PanelSeparator { width: parent.width; foreground: root.fg }

      // ------------------------------------------------------ password prompt
      Column {
        width: parent.width
        visible: root.pending !== null
        spacing: Style.space(8)

        Text {
          width: parent.width
          elide: Text.ElideRight
          text: root.pending
                ? (root.labelFor(root.pending.kind) + ": " + root.pending.name)
                : ""
          color: root.fg
          font.family: root.ff
          font.pixelSize: Style.font.body
        }

        TextField {
          id: pwField
          width: parent.width
          password: true
          placeholderText: "Senha"
          foreground: root.fg
          onAccepted: root.submitConnect()
          Keys.onEscapePressed: root.cancelConnect()
          onVisibleChanged: if (visible) Qt.callLater(forceActiveFocus)
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            width: (parent.width - Style.space(8)) / 2
            text: root.connecting ? "Conectando…" : "Conectar"
            bordered: true
            foreground: root.fg
            background: root.bar ? root.bar.background : Color.background
            fontFamily: root.ff
            onClicked: root.submitConnect()
          }

          Button {
            width: (parent.width - Style.space(8)) / 2
            text: "Cancelar"
            bordered: true
            foreground: root.fg
            background: root.bar ? root.bar.background : Color.background
            fontFamily: root.ff
            onClicked: root.cancelConnect()
          }
        }
      }

      // -------------------------------------------------------------- list
      Column {
        width: parent.width
        visible: root.pending === null
        spacing: Style.space(6)

        Button {
          width: parent.width
          visible: root.connected
          leftAlign: true
          bordered: true
          text: "Desconectar"
          iconText: "󰌾"
          foreground: root.fg
          background: root.bar ? root.bar.background : Color.background
          fontFamily: root.ff
          onClicked: root.disconnectAll()
        }

        Repeater {
          model: root.profiles

          Button {
            required property var modelData
            width: parent.width
            leftAlign: true
            bordered: true
            selected: root.connected && root.activeName === modelData.name
            text: root.labelFor(modelData.kind) + ": " + modelData.name
            iconText: root.glyphFor(modelData.kind)
            foreground: root.fg
            background: root.bar ? root.bar.background : Color.background
            fontFamily: root.ff
            onClicked: root.startConnect(modelData)
          }
        }

        Text {
          width: parent.width
          visible: root.profiles.length === 0
          wrapMode: Text.WordWrap
          text: "Nenhuma VPN configurada em ~/.vpn"
          color: root.dim(0.5)
          font.family: root.ff
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        width: parent.width
        visible: root.errorText !== ""
        wrapMode: Text.WordWrap
        text: root.errorText
        color: Color.urgent
        font.family: root.ff
        font.pixelSize: Style.font.caption
      }
    }
  }
}
