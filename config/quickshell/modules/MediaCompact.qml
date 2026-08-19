import QtQuick
import Quickshell.Io
import "." as Modules

// Compact taskbar version of media info. Full Media.qml has
// album art and is far taller than the 56px taskbar strip, this
// is text + tiny transport glyphs only, sized to match Volume/
// Brightness/Battery in the same bar.
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property string title: ""
    property string artist: ""
    property string status: ""
    property bool hasMedia: false

    Process {
        id: metadataProc
        command: ["sh", "-c", "playerctl metadata --format '{{title}}|{{artist}}|{{status}}' 2>/dev/null"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split("|")
                if (parts.length === 3) {
                    root.title = parts[0]
                    root.artist = parts[1]
                    root.status = parts[2]
                    root.hasMedia = true
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.hasMedia = false
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: metadataProc.running = true
    }

    function control(action) {
        controlProc.command = ["playerctl", action]
        controlProc.running = true
    }

    Process {
        id: controlProc
        command: ["true"]
    }

    Row {
        id: row
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasMedia ? (root.artist + " - " + root.title) : "no media"
            color: "#" + Modules.Theme.colors.fg_dim
            font.family: Modules.Theme.font.family
            font.pixelSize: 13
            elide: Text.ElideRight
            width: 220
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            visible: root.hasMedia

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf048"
                color: "#" + Modules.Theme.colors.fg_dim
                font.family: Modules.Theme.font.icon_family
                font.pixelSize: 14

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: root.control("previous")
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.status === "Playing" ? "\uf04c" : "\uf04b"
                color: "#" + Modules.Theme.colors.coral
                font.family: Modules.Theme.font.icon_family
                font.pixelSize: 14

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: root.control("play-pause")
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf051"
                color: "#" + Modules.Theme.colors.fg_dim
                font.family: Modules.Theme.font.icon_family
                font.pixelSize: 14

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: root.control("next")
                }
            }
        }
    }
}
