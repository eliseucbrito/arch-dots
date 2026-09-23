import QtQuick
import QtQuick.Controls.Basic

Rectangle {
  id: form

  property string editingId: ""
  readonly property bool isEditing: editingId !== ""

  signal cancelled

  function openForCreate() {
    editingId = "";
    nameField.text = "";
    dateField.text = "";
    visible = true;
  }

  function openForEdit(id, name, dateString) {
    editingId = id;
    nameField.text = name;
    dateField.text = dateString;
    visible = true;
  }

  width: 260
  height: 170
  radius: 16
  color: Qt.rgba(0.08, 0.08, 0.08, 0.92)
  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.15)

  onVisibleChanged: if (visible)
    nameField.forceActiveFocus()

  Column {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 10

    Text {
      color: "white"
      font.pixelSize: 14
      font.bold: true
      text: form.isEditing ? "Editar countdown" : "Novo countdown"
    }

    TextField {
      id: nameField
      width: parent.width
      placeholderText: "Nome do evento"
      color: "white"
      placeholderTextColor: "#888888"
      background: Rectangle {
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.08)
      }
    }

    TextField {
      id: dateField
      width: parent.width
      placeholderText: "AAAA-MM-DD"
      color: "white"
      placeholderTextColor: "#888888"
      background: Rectangle {
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.08)
      }
    }

    Text {
      visible: dateField.text.length > 0 && !/^\d{4}-\d{2}-\d{2}$/.test(dateField.text)
      color: "#ff8080"
      font.pixelSize: 11
      text: "Use o formato AAAA-MM-DD"
    }

    Row {
      spacing: 8

      Rectangle {
        width: 70
        height: 30
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.1)

        Text {
          anchors.centerIn: parent
          color: "white"
          font.pixelSize: 12
          text: "Cancelar"
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: form.cancelled()
        }
      }

      Rectangle {
        readonly property bool valid: nameField.text.trim().length > 0 && /^\d{4}-\d{2}-\d{2}$/.test(dateField.text)

        width: 70
        height: 30
        radius: 8
        opacity: valid ? 1 : 0.4
        color: Qt.rgba(0.2, 0.5, 1, 0.6)

        Text {
          anchors.centerIn: parent
          color: "white"
          font.pixelSize: 12
          text: form.isEditing ? "Salvar" : "Criar"
        }

        MouseArea {
          anchors.fill: parent
          enabled: parent.valid
          cursorShape: parent.valid ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (form.isEditing)
              Countdowns.update(form.editingId, nameField.text.trim(), dateField.text);
            else
              Countdowns.add(nameField.text.trim(), dateField.text, form.x, form.y);
            form.cancelled();
          }
        }
      }
    }
  }
}
