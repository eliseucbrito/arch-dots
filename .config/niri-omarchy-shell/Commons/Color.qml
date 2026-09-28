pragma Singleton
import QtQuick

// Simplified from omarchy's Commons/Color.qml. That version parses
// ~/.local/state/omarchy/current/theme/{colors,shell}.toml so themes can
// swap live. This runtime has no theme system — plugins get a fixed
// palette. Surface roles (menu, popups, ...) are kept because Capture.qml
// reads Color.menu.* directly.
QtObject {
  id: root

  property color foreground: "#cacccc"
  property color background: "#101315"
  property color accent: "#cacccc"
  property color urgent: "#a55555"
  property color muted: "#707880"

  readonly property QtObject menu: QtObject {
    property color background: root.background
    property color text: root.foreground
    property color border: root.foreground
    property color scrim: Util.alpha(root.background, 0.5)
    property color selectedBackground: Util.alpha(root.foreground, 0.08)
    property color selectedText: root.accent
    property color selectedBorder: Util.alpha(root.foreground, 0.0)
  }
  readonly property QtObject popups: QtObject {
    property color background: root.background
    property color text: root.foreground
    property color border: root.accent
  }
  readonly property QtObject tooltip: QtObject {
    property color background: root.background
    property color text: root.foreground
    property color border: root.foreground
  }
}
