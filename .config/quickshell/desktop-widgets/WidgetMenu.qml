import QtQuick

Rectangle {
  id: menu

  property bool showEdit: false
  property bool showRemove: false
  property bool pinned: false

  signal editRequested
  signal removeRequested
  signal pinToggled

  width: 180
  height: itemColumn.height + 8
  radius: 10
  color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.15)

  Column {
    id: itemColumn
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 4
    spacing: 2

    Rectangle {
      width: parent.width
      height: 32
      radius: 6
      color: pinArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        color: "white"
        font.pixelSize: 13
        text: menu.pinned ? "Desafixar" : "Fixar"
      }

      MouseArea {
        id: pinArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.pinToggled()
      }
    }

    Rectangle {
      visible: menu.showEdit
      width: parent.width
      height: visible ? 32 : 0
      radius: 6
      color: editArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        color: "white"
        font.pixelSize: 13
        text: "Editar"
      }

      MouseArea {
        id: editArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.editRequested()
      }
    }

    Rectangle {
      visible: menu.showRemove
      width: parent.width
      height: visible ? 32 : 0
      radius: 6
      color: removeArea.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.18) : "transparent"

      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        color: "#ff8080"
        font.pixelSize: 13
        text: "Remover"
      }

      MouseArea {
        id: removeArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.removeRequested()
      }
    }
  }
}
