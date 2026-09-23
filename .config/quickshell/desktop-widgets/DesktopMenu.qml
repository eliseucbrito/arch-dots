import QtQuick

Rectangle {
  id: menu

  signal newCountdownRequested

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
      color: newCountdownArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        color: "white"
        font.pixelSize: 13
        text: "Novo countdown"
      }

      MouseArea {
        id: newCountdownArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.newCountdownRequested()
      }
    }
  }
}
