import QtQuick
import Quickshell
import "." as Modules

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
        target: Modules.BrightnessState
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
                text: "BRI"
                color: "#" + Modules.Theme.colors.fg_dim
                font.family: Modules.Theme.font.family
                font.pixelSize: 11
            }

            Modules.BevelPanel {
                sunken: true
                width: 20
                height: 160

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.margins: 4
                    width: 8
                    height: (parent.height - 8) * (Modules.BrightnessState.percentage / 100)
                    color: "#" + Modules.Theme.colors.warning

                    Behavior on height {
                        NumberAnimation { duration: 120 }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Modules.BrightnessState.percentage + "%"
                color: "#" + Modules.Theme.colors.fg
                font.family: Modules.Theme.font.family
                font.pixelSize: 14
            }
        }
    }
}
