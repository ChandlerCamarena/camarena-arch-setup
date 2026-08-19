import QtQuick
import Quickshell
import "." as Modules

// Right-edge vertical OSD. Watches VolumeState.changeTick rather than
// percentage/muted directly -- one signal to react to regardless of
// which underlying property changed, avoids double-trigger when both
// fire from the same wpctl event.
PanelWindow {
    id: osd

    anchors {
        top: true
        bottom: true
        right: true
    }

    exclusiveZone: 0
    color: "transparent"
    implicitWidth: 90
    focusable: false

    property bool shown: false

    Connections {
        target: Modules.VolumeState
        function onChangeTickChanged() {
            osd.shown = true
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.shown = false
    }

    Modules.BevelPanel {
        id: panel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 24
        width: 64
        height: 260
        opacity: osd.shown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Modules.VolumeState.muted ? "MUTE" : "VOL"
                color: Modules.VolumeState.muted
                    ? "#" + Modules.Theme.colors.error
                    : "#" + Modules.Theme.colors.fg_dim
                font.family: Modules.Theme.font.family
                font.pixelSize: 11
            }

            Modules.BevelPanel {
                id: barTrack
                sunken: true
                width: 20
                height: 160

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.margins: 4
                    width: 8
                    height: (parent.height - 8) * (Modules.VolumeState.percentage / 100)
                    color: Modules.VolumeState.muted
                        ? "#" + Modules.Theme.colors.error
                        : "#" + Modules.Theme.colors.coral

                    Behavior on height {
                        NumberAnimation { duration: 120 }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Modules.VolumeState.percentage + "%"
                color: "#" + Modules.Theme.colors.fg
                font.family: Modules.Theme.font.family
                font.pixelSize: 14
            }
        }
    }
}
