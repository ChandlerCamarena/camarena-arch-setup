import QtQuick
import "." as Modules

// Thin view over the VolumeState singleton (see VolumeState.qml).
// No Process/pactl logic here anymore -- that's shared with
// VolumeOSD.qml through the singleton, one subscription total
// instead of one per widget instance.
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    signal mixerToggleRequested()

    Row {
        id: row
        spacing: 6

        Text {
            text: Modules.VolumeState.muted ? "MUTE" : "VOL"
            color: Modules.VolumeState.muted
                ? "#" + Modules.Theme.colors.error
                : "#" + Modules.Theme.colors.fg_dim
            font.family: Modules.Theme.font.family
            font.pixelSize: 11

            MouseArea {
                anchors.fill: parent
                onClicked: Modules.VolumeState.toggleMute()
            }
        }

        Modules.BevelPanel {
            id: sliderPanel
            width: 80
            height: 16
            sunken: true

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 4
                width: (parent.width - 8) * (Modules.VolumeState.percentage / 100)
                height: 4
                color: "#" + Modules.Theme.colors.coral
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => {
                    Modules.VolumeState.userDragging = true
                    Modules.VolumeState.generation++
                    Modules.VolumeState.setVolume(Math.round((mouse.x / width) * 100))
                }
                onPositionChanged: mouse => {
                    if (pressed) {
                        Modules.VolumeState.setVolume(Math.round((mouse.x / width) * 100))
                    }
                }
                onReleased: {
                    Modules.VolumeState.userDragging = false
                }
            }
        }

        Text {
            text: Modules.VolumeState.percentage + "%"
            color: "#" + Modules.Theme.colors.fg
            font.family: Modules.Theme.font.family
            font.pixelSize: 14

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: root.mixerToggleRequested()
            }
        }
    }
}
