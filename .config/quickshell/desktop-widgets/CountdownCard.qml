import QtQuick

Rectangle {
  id: card

  required property string entryId
  property string entryName: ""
  property string entryDate: ""
  property bool pinned: false
  property real dragStartX: 0
  property real dragStartY: 0

  signal contextMenuRequested(real menuX, real menuY)

  readonly property int daysLeft: {
    if (!entryDate)
      return 0;

    const today = new Date();
    const target = new Date(entryDate + "T00:00:00");
    const msPerDay = 1000 * 60 * 60 * 24;
    const startOfToday = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    return Math.round((target - startOfToday) / msPerDay);
  }

  readonly property string relativeLabel: daysLeft === 0 ? "hoje" : Math.abs(daysLeft) + "d"

  width: 200
  height: 100
  radius: 16
  color: Qt.rgba(0, 0, 0, 0.35)
  border.width: closeArea.containsMouse || dragArea.drag.active ? 1 : 0
  border.color: Qt.rgba(1, 1, 1, 0.25)

  Column {
    anchors.centerIn: parent
    spacing: 2

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      color: "white"
      font.pixelSize: 34
      font.bold: true
      text: card.relativeLabel
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      color: "#cccccc"
      font.pixelSize: 13
      text: card.daysLeft > 0 ? "para " + card.entryName : (card.daysLeft === 0 ? card.entryName : "desde " + card.entryName)
    }
  }

  Text {
    id: pinIndicator
    visible: card.pinned || closeArea.containsMouse || pinButtonArea.containsMouse
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.margins: 6
    color: card.pinned ? "#ffd166" : "#ffffff"
    font.pixelSize: 14
    text: "📌"

    MouseArea {
      id: pinButtonArea
      anchors.fill: parent
      anchors.margins: -6
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: Countdowns.setPinned(card.entryId, !card.pinned)
    }
  }

  Text {
    id: closeButton
    visible: closeArea.containsMouse
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 6
    color: "#ffffff"
    font.pixelSize: 14
    text: "✕"

    MouseArea {
      id: closeArea
      anchors.fill: parent
      anchors.margins: -6
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: Countdowns.remove(card.entryId)
    }
  }

  MouseArea {
    id: dragArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    drag.target: card.pinned ? null : card
    cursorShape: card.pinned ? Qt.ArrowCursor : Qt.SizeAllCursor
    onPressed: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        card.dragStartX = card.x;
        card.dragStartY = card.y;
      }
    }
    onReleased: (mouse) => {
      if (mouse.button === Qt.LeftButton && (card.x !== card.dragStartX || card.y !== card.dragStartY))
        Countdowns.setPosition(card.entryId, card.x, card.y);
    }
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton)
        card.contextMenuRequested(mouse.x, mouse.y);
    }
  }
}
