pragma Singleton
import QtQuick

// Simplified from omarchy's Commons/Style.qml. That version polls
// `hyprctl getoption` for corner radius / gaps and parses theme/shell.toml
// for spacing/typography scale. This runtime has no compositor-specific
// theming, so every token is a fixed value — no niri equivalent lookup
// exists (and none of the 3 target plugins need one). Only the API surface
// actually used by capture/linear/gitlab-ci is kept.
QtObject {
  id: root

  property int cornerRadius: 8
  property int gapsOut: 8

  readonly property int normalBorderWidth: 1
  readonly property int hoverBorderWidth: 1
  readonly property int selectedBorderWidth: 0
  readonly property int focusBorderWidth: 1

  readonly property real normalFillAlpha: 0.04
  readonly property real hoverFillAlpha: 0.08
  readonly property real selectedFillAlpha: 0.18
  readonly property real pressedFillAlpha: 0.22
  readonly property real focusFillAlpha: 0.08
  readonly property real normalBorderAlpha: 0.4
  readonly property real hoverBorderAlpha: 0.25
  readonly property real selectedBorderAlpha: 1.0
  readonly property real focusBorderAlpha: 0.25
  readonly property real selectionFillAlpha: 0.35

  // Fixed "foreground" role for every state — this runtime has no themed
  // per-state color tokens (omarchy's styleOverrides / shell.toml [controls]
  // section), so every state just uses whichever foreground/accent color
  // the caller already passed in.
  function normalFillFor(foreground) { return Util.alpha(foreground, normalFillAlpha) }
  function hoverFillFor(foreground) { return Util.alpha(foreground, hoverFillAlpha) }
  function selectedFillFor(foreground, accent) { return Util.alpha(foreground, selectedFillAlpha) }
  function pressedFillFor(foreground, accent) { return Util.alpha(foreground, pressedFillAlpha) }
  function focusFillFor(foreground) { return Util.alpha(foreground, focusFillAlpha) }
  function selectionFillFor(foreground, accent) { return Util.alpha(accent || foreground, selectionFillAlpha) }

  function selectedStateColor(foreground, accent) { return accent || foreground }

  function controlFill(focused, hot, foreground) {
    if (focused) return focusFillFor(foreground)
    if (hot) return hoverFillFor(foreground)
    return normalFillFor(foreground)
  }

  // ---------------------------------------------------------- spacing
  // Fixed 1:1 scale — no theme [spacing] scale override in this runtime.
  function space(px) {
    var n = Number(px)
    return isFinite(n) && n > 0 ? Math.round(n) : 0
  }

  readonly property QtObject spacing: QtObject {
    readonly property int xxs: 2
    readonly property int xs: 3
    readonly property int sm: 4
    readonly property int md: 6
    readonly property int lg: 8
    readonly property int xl: 10
    readonly property int xxl: 12
    readonly property int controlGap: 8
    readonly property int controlPaddingX: 10
    readonly property int controlPaddingY: 6
    readonly property int inputPaddingY: 7
    readonly property int panelPadding: 18
    readonly property int popupPadding: 14
  }

  property string fontFamily: "monospace"

  readonly property QtObject font: QtObject {
    readonly property string family: root.fontFamily
    readonly property string menuFamily: root.fontFamily
    readonly property int caption: 10
    readonly property int bodySmall: 11
    readonly property int body: 12
    readonly property int subtitle: 13
    readonly property int title: 14
    readonly property int heading: 16
    readonly property int display: 24
    readonly property int iconSmall: 11
    readonly property int icon: 14
    readonly property int iconLarge: 18
  }

  // Bar geometry — no visual bar in this runtime (waybar is the bar), but
  // WidgetButton/BarIconButton (used internally by linear/gitlab-ci's Panel
  // for their own icon rendering) size themselves against these tokens.
  readonly property QtObject bar: QtObject {
    readonly property int sizeHorizontal: 26
    readonly property int sizeVertical: 28
    readonly property int iconSlot: 27
    readonly property int iconCanvas: 16
    readonly property int iconFont: 13
  }

  function spaceReal(px) {
    var n = Number(px)
    return isFinite(n) && n > 0 ? n : 0
  }
}
