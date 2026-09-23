import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

ShellRoot {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData

      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: newCountdownForm.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }

      // right-click anywhere on empty desktop opens the context menu at the
      // cursor; left-click elsewhere dismisses an open menu/form
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
          if (mouse.button === Qt.RightButton) {
            desktopMenu.x = Math.min(mouse.x, panel.width - desktopMenu.width - 20);
            desktopMenu.y = Math.min(mouse.y, panel.height - desktopMenu.height - 20);
            desktopMenu.visible = true;
            newCountdownForm.visible = false;
            widgetMenu.visible = false;
          } else {
            desktopMenu.visible = false;
            newCountdownForm.visible = false;
            widgetMenu.visible = false;
          }
        }
      }

      Rectangle {
        id: clock
        property real dragStartX: 0
        property real dragStartY: 0

        x: ClockPosition.x
        y: ClockPosition.y
        width: 240
        height: 120
        radius: 16
        color: Qt.rgba(0, 0, 0, 0.35)
        border.width: clockDragArea.drag.active ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.25)

        Column {
          anchors.centerIn: parent
          spacing: 4

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "white"
            font.pixelSize: 40
            font.bold: true
            text: Qt.formatTime(clockTimer.now, "HH:mm")
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#cccccc"
            font.pixelSize: 16
            text: Qt.formatDate(clockTimer.now, "dddd, d MMMM")
          }
        }

        Text {
          visible: ClockPosition.pinned || clockPinArea.containsMouse
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.margins: 6
          color: ClockPosition.pinned ? "#ffd166" : "#ffffff"
          font.pixelSize: 14
          text: "📌"

          MouseArea {
            id: clockPinArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ClockPosition.setPinned(!ClockPosition.pinned)
          }
        }

        MouseArea {
          id: clockDragArea
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          drag.target: ClockPosition.pinned ? null : clock
          cursorShape: ClockPosition.pinned ? Qt.ArrowCursor : Qt.SizeAllCursor
          onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
              clock.dragStartX = clock.x;
              clock.dragStartY = clock.y;
            }
          }
          onReleased: (mouse) => {
            if (mouse.button === Qt.LeftButton && (clock.x !== clock.dragStartX || clock.y !== clock.dragStartY))
              ClockPosition.setPosition(clock.x, clock.y);
          }
          onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
              widgetMenu.openFor("clock", "", clock.x + mouse.x, clock.y + mouse.y);
            }
          }
        }
      }

      Timer {
        id: clockTimer
        property date now: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: now = new Date()
      }

      Repeater {
        model: Countdowns.ready ? Countdowns.items : []

        CountdownCard {
          required property var modelData

          entryId: modelData.id
          entryName: modelData.name
          entryDate: modelData.date
          pinned: !!modelData.pinned
          x: modelData.x
          y: modelData.y

          onContextMenuRequested: (menuX, menuY) => widgetMenu.openFor("countdown", entryId, x + menuX, y + menuY)
        }
      }

      DesktopMenu {
        id: desktopMenu
        visible: false
        onNewCountdownRequested: {
          newCountdownForm.openForCreate();
          desktopMenu.visible = false;
        }
      }

      WidgetMenu {
        id: widgetMenu

        property string targetKind: ""
        property string targetId: ""

        function openFor(kind, id, menuX, menuY) {
          targetKind = kind;
          targetId = id;
          showEdit = kind === "countdown";
          showRemove = kind === "countdown";
          pinned = kind === "clock" ? ClockPosition.pinned : (Countdowns.items.find(it => it.id === id) || {}).pinned || false;
          x = Math.min(menuX, panel.width - width - 20);
          y = Math.min(menuY, panel.height - height - 20);
          visible = true;
          desktopMenu.visible = false;
          newCountdownForm.visible = false;
        }

        visible: false

        onPinToggled: {
          if (targetKind === "clock")
            ClockPosition.setPinned(!ClockPosition.pinned);
          else
            Countdowns.setPinned(targetId, !pinned);
          visible = false;
        }
        onEditRequested: {
          const entry = Countdowns.items.find(it => it.id === targetId);
          if (entry)
            newCountdownForm.openForEdit(entry.id, entry.name, entry.date);
          visible = false;
        }
        onRemoveRequested: {
          Countdowns.remove(targetId);
          visible = false;
        }
      }

      NewCountdownForm {
        id: newCountdownForm
        anchors.centerIn: parent
        visible: false
        onCancelled: newCountdownForm.visible = false
      }
    }
  }
}
