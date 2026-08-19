import QtQuick
import "." as Modules

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Kept as a thin alias so shell.qml's existing brightnessWidget.refresh()
    // reference (if anything still calls it directly) keeps working;
    // the real work now happens in BrightnessState.
    function refresh() {
        Modules.BrightnessState.refresh()
    }

    Row {
        id: row
        spacing: 6

        Text {
            text: "BRI"
            color: "#" + Modules.Theme.colors.fg_dim
            font.family: Modules.Theme.font.family
            font.pixelSize: 11
        }

        Modules.BevelPanel {
            width: 80
            height: 16
            sunken: true

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 4
                width: (parent.width - 8) * (Modules.BrightnessState.percentage / 100)
                height: 4
                color: "#" + Modules.Theme.colors.warning
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => {
                    Modules.BrightnessState.userDragging = true
                    Modules.BrightnessState.generation++
                    Modules.BrightnessState.setBrightness(Math.round((mouse.x / width) * 100))
                }
                onPositionChanged: mouse => {
                    if (pressed) {
                        Modules.BrightnessState.setBrightness(Math.round((mouse.x / width) * 100))
                    }
                }
                onReleased: {
                    Modules.BrightnessState.userDragging = false
                }
            }
        }

        Text {
            text: Modules.BrightnessState.percentage + "%"
            color: "#" + Modules.Theme.colors.fg
            font.family: Modules.Theme.font.family
            font.pixelSize: 14
        }
    }
}
