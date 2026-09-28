pragma Singleton
import Quickshell
import QtQuick

// Ported from /usr/share/omarchy/shell/Commons/Util.qml — trimmed to the
// functions actually used by the plugins this runtime hosts (capture,
// linear, gitlab-ci). Pure functions only, no state.
QtObject {
  id: root

  function clamp(value, min, max) {
    var n = Number(value)
    if (!isFinite(n)) return min
    return Math.max(min, Math.min(max, n))
  }

  function clampAlpha(value) {
    return clamp(value, 0, 1)
  }

  function alpha(c, opacity) {
    var a = clampAlpha(opacity)
    if (!c) return Qt.rgba(0, 0, 0, a)
    if (typeof c === "string") c = Qt.color(c)
    return Qt.rgba(c.r, c.g, c.b, a)
  }

  function fileUrl(path) {
    if (!path) return ""
    return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
  }

  function isPlainObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value)
  }

  function cloneJson(value) {
    return JSON.parse(JSON.stringify(value === undefined ? null : value))
  }
}
