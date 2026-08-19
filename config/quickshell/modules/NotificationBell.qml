import QtQuick
import "." as Modules

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: 33

    property int notificationCount: 0
    signal clicked()

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf0f3"
            color: "#" + Modules.Theme.colors.fg_dim
            font.family: Modules.Theme.font.icon_family
            font.pixelSize: 20
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.notificationCount > 0
            text: root.notificationCount
            color: "#" + Modules.Theme.colors.coral
            font.family: Modules.Theme.font.family
            font.pixelSize: 20
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
