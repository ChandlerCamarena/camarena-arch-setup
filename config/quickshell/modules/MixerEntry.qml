import QtQuick
import "." as Modules

Item {
    id: root
    property int streamIndex: -1
    property int wpctlId: -1
    property string appName: ""
    property int percentage: 0
    property bool userDragging: false
    property var daemon: null

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    function setPct(pct) {
        const clamped = Math.max(0, Math.min(100, pct))
        root.percentage = clamped
        if (root.daemon) root.daemon.setVolume(root.streamIndex, root.wpctlId, clamped)
    }

    function titleCase(s) {
        return s.replace(/\b\w/g, c => c.toUpperCase())
    }

    Column {
        id: column
        spacing: 4

        Text {
            width: 180
            text: root.titleCase(root.appName)
            color: "#" + Modules.Theme.colors.fg_dim
            font.family: Modules.Theme.font.family
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Row {
            spacing: 6

            Modules.BevelPanel {
                id: sliderPanel
                width: 160
                height: 16
                sunken: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 4
                    width: (parent.width - 8) * (root.percentage / 100)
                    height: 4
                    color: root.streamIndex >= 0
                        ? "#" + Modules.Theme.colors.coral
                        : "#" + Modules.Theme.colors.fg_subtle
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: mouse => {
                        root.userDragging = true
                        root.setPct(Math.round((mouse.x / width) * 100))
                    }
                    onPositionChanged: mouse => {
                        if (pressed) root.setPct(Math.round((mouse.x / width) * 100))
                    }
                    onReleased: root.userDragging = false
                }
            }

            Text {
                text: root.percentage + "%"
                color: "#" + Modules.Theme.colors.fg
                font.family: Modules.Theme.font.family
                font.pixelSize: 13
            }
        }
    }
}
