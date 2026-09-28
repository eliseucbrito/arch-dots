pragma Singleton
import QtQuick
import "BorderGeometry.js" as Geometry

// Simplified from omarchy's Commons/Border.qml — the theme-token lookup
// (Color.shellValues["section.key"]) is gone since this runtime has no
// theme system; specs are built directly from fixed colors/widths. The
// geometry helpers (widths/gradient/native-vs-overlay decisions) are the
// same ones BorderSurface/BorderOverlay expect, ported unchanged.
QtObject {
  id: root

  function none() {
    return flat("transparent", 0)
  }

  function flat(color, width) {
    return {
      color: color || "transparent",
      widths: Geometry.parseWidthSpec(width, 0),
      gradient: { colors: [], angle: 0, enabled: false },
    }
  }

  function surfaceSpec(section, token, fallbackColor, fallbackWidth) {
    return flat(fallbackColor, fallbackWidth)
  }

  function controlWidthFor(state) {
    if (state === "focus") return Style.focusBorderWidth
    if (state === "hover-cursor") return Style.hoverBorderWidth
    if (state === "selected") return Style.selectedBorderWidth
    return Style.normalBorderWidth
  }

  function controlAlphaFor(state) {
    if (state === "focus") return Style.focusBorderAlpha
    if (state === "hover-cursor") return Style.hoverBorderAlpha
    if (state === "selected") return Style.selectedBorderAlpha
    return Style.normalBorderAlpha
  }

  function controlSpec(state, foreground, accent) {
    var color = (state === "focus" || state === "hover-cursor") ? (accent || foreground) : foreground
    return flat(Util.alpha(color, controlAlphaFor(state)), controlWidthFor(state))
  }

  function controlHasWidth(state) {
    return controlWidthFor(state) > 0
  }

  // No theme-supplied per-surface border override in this runtime — a local
  // override always wins, same call shape omarchy's Button.qml expects.
  function localOrSurfaceSpec(section, token, localColor, defaultColor, fallbackWidth) {
    return flat(localColor, fallbackWidth)
  }

  function isNone(spec) { return !spec || Geometry.maxWidth(spec.widths) <= 0 }
  function needsOverlay(spec) { return Geometry.needsOverlay(spec) }
  function canUseNative(spec) { return Geometry.canUseNative(spec) }
  function top(spec) { return spec && spec.widths ? spec.widths.top : 0 }
  function right(spec) { return spec && spec.widths ? spec.widths.right : 0 }
  function bottom(spec) { return spec && spec.widths ? spec.widths.bottom : 0 }
  function left(spec) { return spec && spec.widths ? spec.widths.left : 0 }
  function uniformWidth(spec) { return spec && spec.widths ? spec.widths.top : 0 }
  function color(spec) { return spec ? spec.color : "transparent" }
}
