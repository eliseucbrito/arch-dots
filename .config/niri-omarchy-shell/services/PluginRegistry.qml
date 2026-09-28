import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Trimmed from omarchy's services/PluginRegistry.qml. That version also
// manages bar-layout placement (shell.json `bar.layout.*`, clones,
// enable/disable) because the omarchy bar lives inside the same Quickshell
// process. This runtime has no bar of its own — waybar triggers plugins by
// id over IPC — so only discovery, manifest validation, and hot-reload
// survive.
QtObject {
  id: registry

  property string home: Quickshell.env("HOME")
  property string pluginsDir: home + "/.config/omarchy/plugins"

  // { pluginId: manifest } — manifests have __sourceDir stamped in.
  property var installedPlugins: ({})
  property int registryRevision: 0
  property bool scanning: false

  signal pluginsChanged()
  signal scanFinished()
  signal localPluginChanged(string id)

  function isSafeEntryPoint(value) {
    if (typeof value !== "string" || value.length === 0) return false
    if (value.charAt(0) === "/") return false
    if (value.indexOf("..") !== -1) return false
    return true
  }

  function validateManifest(manifest, sourcePath) {
    if (!Util.isPlainObject(manifest)) {
      console.warn("PluginRegistry: manifest is not an object at " + sourcePath)
      return null
    }
    if (manifest.schemaVersion !== 1) {
      console.warn("PluginRegistry: unsupported schemaVersion at " + sourcePath)
      return null
    }
    var required = ["id", "name", "version", "kinds", "entryPoints"]
    for (var i = 0; i < required.length; i++) {
      if (manifest[required[i]] === undefined) {
        console.warn("PluginRegistry: missing required field '" + required[i] + "' at " + sourcePath)
        return null
      }
    }
    var id = String(manifest.id)
    if (!id || id.indexOf("/") !== -1 || id.indexOf("..") !== -1 || id.charAt(0) === "/") {
      console.warn("PluginRegistry: invalid plugin id '" + id + "' at " + sourcePath)
      return null
    }
    if (!Array.isArray(manifest.kinds) || manifest.kinds.length === 0) {
      console.warn("PluginRegistry: kinds must be a non-empty array at " + sourcePath)
      return null
    }
    if (!Util.isPlainObject(manifest.entryPoints)) {
      console.warn("PluginRegistry: entryPoints must be an object at " + sourcePath)
      return null
    }
    for (var key in manifest.entryPoints) {
      if (!isSafeEntryPoint(manifest.entryPoints[key])) {
        console.warn("PluginRegistry: unsafe entryPoint '" + key + "'='"
          + manifest.entryPoints[key] + "' at " + sourcePath)
        return null
      }
    }
    return manifest
  }

  function entryPointUrl(manifest, kind) {
    if (!Util.isPlainObject(manifest)) return ""
    var ep = manifest.entryPoints ? manifest.entryPoints[kind] : null
    if (!ep) return ""
    var dir = manifest.__sourceDir || ""
    if (!dir) return ""
    var resolved = dir.replace(/\/$/, "") + "/" + String(ep)
    var expectedPrefix = dir.replace(/\/$/, "") + "/"
    if (resolved.indexOf(expectedPrefix) !== 0) {
      console.warn("PluginRegistry: entry point escapes sourceDir: " + resolved)
      return ""
    }
    return Util.fileUrl(resolved)
  }

  // Output format produced by the rescan script:
  //   ===<absolute-source-dir>===
  //   ... raw manifest.json content ...
  //   === EOM ===
  function parseScanOutput(text) {
    var lines = String(text || "").split("\n")
    var merged = {}
    var currentSource = null
    var currentJson = []

    function flush() {
      if (!currentSource) return
      var raw = currentJson.join("\n").trim()
      try {
        var manifest = JSON.parse(raw)
        manifest.__sourceDir = currentSource
        var validated = validateManifest(manifest, currentSource + "/manifest.json")
        if (validated) merged[validated.id] = validated
      } catch (e) {
        console.warn("PluginRegistry: bad manifest at " + currentSource + ": " + e)
      }
      currentSource = null
      currentJson = []
    }

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (line === "=== EOM ===") {
        flush()
        continue
      }
      var startMatch = line.match(/^===(.+)===$/)
      if (startMatch) {
        flush()
        currentSource = startMatch[1].replace(/\/$/, "")
        currentJson = []
        continue
      }
      if (currentSource) currentJson.push(line)
    }
    flush()

    installedPlugins = merged
    registryRevision++
    scanning = false
    pluginsChanged()
    scanFinished()
  }

  property Process scanProcess: Process {
    onExited: function(exitCode) {
      registry.parseScanOutput(scanStdout.text || "")
    }
    stdout: StdioCollector {
      id: scanStdout
      waitForEnd: true
    }
  }

  property Process initProcess: Process {
    onExited: {
      localPluginWatcher.running = true
      registry.rescan()
    }
  }

  property Process localPluginWatcher: Process {
    command: [
      "inotifywait", "-m", "-r", "-q",
      "-e", "close_write,create,delete,move",
      "--format", "%w%f",
      registry.pluginsDir
    ]
    stdout: SplitParser {
      onRead: function(path) {
        var pluginId = registry.localPluginIdForPath(path)
        if (pluginId) registry.localPluginChanged(pluginId)
      }
    }
    onExited: localPluginWatcherRestart.restart()
  }

  property Timer localPluginWatcherRestart: Timer {
    interval: 1000
    onTriggered: localPluginWatcher.running = true
  }

  function rescan() {
    if (scanning) return
    scanning = true
    var script = ""
      + "for sub in \"$0\"/*/; do "
      + "  [[ -f \"$sub/manifest.json\" ]] || continue; "
      + "  printf '===%s===\\n' \"${sub%/}\"; "
      + "  cat \"$sub/manifest.json\"; "
      + "  printf '\\n=== EOM ===\\n'; "
      + "done"
    scanProcess.command = ["bash", "-c", script, registry.pluginsDir]
    scanProcess.running = true
  }

  function ensureUserDir() {
    initProcess.command = ["bash", "-c", "mkdir -p \"$0\"", registry.pluginsDir]
    initProcess.running = true
  }

  function localPluginIdForPath(filePath) {
    var base = pluginsDir.replace(/\/$/, "") + "/"
    var path = String(filePath || "").trim()
    if (path.indexOf(base) !== 0) return ""
    var relative = path.slice(base.length)
    if (relative.indexOf(".") === 0) return ""
    if (relative.indexOf("/.git/") !== -1 || relative.endsWith("/.git")) return ""
    var slash = relative.indexOf("/")
    return slash === -1 ? relative : relative.slice(0, slash)
  }

  Component.onCompleted: ensureUserDir()
}
