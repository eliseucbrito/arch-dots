pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string filePath: Quickshell.env("HOME") + "/.config/quickshell/desktop-widgets/countdowns.json"
  property var items: []
  property bool ready: false

  function save() {
    store.setText(JSON.stringify(root.items));
  }

  function add(name, dateString, x, y) {
    root.items = root.items.concat([{
      id: Date.now() + "-" + Math.floor(Math.random() * 10000),
      name: name,
      date: dateString,
      x: x,
      y: y,
      pinned: false
    }]);
    root.save();
  }

  function remove(id) {
    root.items = root.items.filter(function (it) {
      return it.id !== id;
    });
    root.save();
  }

  function update(id, name, dateString) {
    root.items = root.items.map(function (it) {
      if (it.id !== id)
        return it;

      return Object.assign({}, it, {
        name: name,
        date: dateString
      });
    });
    root.save();
  }

  function setPosition(id, x, y) {
    root.items = root.items.map(function (it) {
      if (it.id !== id)
        return it;

      return Object.assign({}, it, {
        x: x,
        y: y
      });
    });
    root.save();
  }

  function setPinned(id, pinned) {
    root.items = root.items.map(function (it) {
      if (it.id !== id)
        return it;

      return Object.assign({}, it, {
        pinned: pinned
      });
    });
    root.save();
  }

  FileView {
    id: store
    path: root.filePath
    printErrors: false
    preload: true

    onLoaded: {
      const text = store.text();
      if (!text)
        return ;

      try {
        root.items = JSON.parse(text);
      } catch (e) {
        console.warn("Countdowns: failed to parse " + root.filePath + ": " + e);
      }
      root.ready = true;
    }
    onLoadFailed: (error) => {
      root.items = [];
      root.ready = true;
    }
  }
}
