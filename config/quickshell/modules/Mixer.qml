import QtQuick
import "." as Modules

Item {
    id: root
    property bool popupVisible: false
    property var daemon: null

    implicitWidth: popupVisible ? panel.implicitWidth : 0
    implicitHeight: popupVisible ? panel.implicitHeight : 0

    Modules.BevelPanel {
        id: panel
        visible: root.popupVisible
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        implicitWidth: content.implicitWidth + 24
        implicitHeight: content.implicitHeight + 24

        Column {
            id: content
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: 12
            spacing: 10

            Text {
                text: "AUDIO MIXER"
                color: "#" + Modules.Theme.colors.coral
                font.family: Modules.Theme.font.family
                font.pixelSize: 14
            }

            Text {
                visible: !root.daemon || root.daemon.streams.count === 0
                text: "no active audio streams"
                color: "#" + Modules.Theme.colors.fg_subtle
                font.family: Modules.Theme.font.family
                font.pixelSize: 12
            }

            Repeater {
                model: root.daemon ? root.daemon.streams : null

                Modules.MixerEntry {
                    id: entry
                    streamIndex: model.streamKey
                    wpctlId: model.wpctlId
                    appName: model.name
                    daemon: root.daemon

                    Binding {
                        target: entry
                        property: "percentage"
                        value: model.percent
                        when: !entry.userDragging
                    }
                }
            }
        }
    }
}
