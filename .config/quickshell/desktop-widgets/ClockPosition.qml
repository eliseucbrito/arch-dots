pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string filePath: Quickshell.env("HOME") + "/.config/quickshell/desktop-widgets/clock-position.json"
  property real x: 40
  property real y: 40
  property bool pinned: false
  property bool ready: false

  function setPosition(newX, newY) {
    root.x = newX;
    root.y = newY;
    save();
  }

  function setPinned(newPinned) {
    root.pinned = newPinned;
    save();
  }

  function save() {
    store.setText(JSON.stringify({
      x: root.x,
      y: root.y,
      pinned: root.pinned
    }));
  }

  FileView {
    id: store
    path: root.filePath
    printErrors: false
    preload: true

    onLoaded: {
      const text = store.text();
      if (!text) {
        root.ready = true;
        return ;
      }
      try {
        const parsed = JSON.parse(text);
        root.x = parsed.x;
        root.y = parsed.y;
        root.pinned = !!parsed.pinned;
      } catch (e) {
        console.warn("ClockPosition: failed to parse " + root.filePath + ": " + e);
      }
      root.ready = true;
    }
    onLoadFailed: (error) => {
      root.ready = true;
    }
  }
}
