import QtQuick
import Quickshell.Io
import "." as Modules

Item {
    id: root
    implicitWidth: outerPanel.implicitWidth
    implicitHeight: outerPanel.implicitHeight

    property string title: ""
    property string artist: ""
    property string status: ""
    property string artUrl: ""
    property bool hasMedia: false

    Process {
        id: metadataProc
        command: ["sh", "-c", "playerctl metadata --format '{{title}}|{{artist}}|{{status}}|{{mpris:artUrl}}' 2>/dev/null"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split("|")
                if (parts.length === 4) {
                    root.title = parts[0]
                    root.artist = parts[1]
                    root.status = parts[2]
                    root.artUrl = parts[3]
                    root.hasMedia = true
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.hasMedia = false
            }
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

    Modules.BevelPanel {
        id: outerPanel
        implicitWidth: column.implicitWidth + 36
        implicitHeight: column.implicitHeight + 36

        Column {
            id: column
            anchors.centerIn: parent
            spacing: 18

            Text {
                text: "MEDIA"
                color: "#" + Modules.Theme.colors.coral
                font.family: Modules.Theme.font.family
                font.pixelSize: 24
            }

            Row {
                spacing: 15

                Modules.BevelPanel {
                    width: 84
                    height: 84
                    sunken: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 4
                        source: root.hasMedia && root.artUrl !== "" ? root.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: root.hasMedia && root.artUrl !== ""
                    }

                    Item {
                        anchors.fill: parent
                        visible: !root.hasMedia || root.artUrl === ""

                        Rectangle {
                            anchors.centerIn: parent
                            width: 60
                            height: 60
                            radius: 30
                            color: "transparent"
                            border.width: 2
                            border.color: "#" + Modules.Theme.colors.coral_dim
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 40
                            height: 40
                            radius: 20
                            color: "transparent"
                            border.width: 2
                            border.color: "#" + Modules.Theme.colors.purple_dim
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: "#" + Modules.Theme.colors.coral
                        }
                    }
                }

                Column {
                    width: 240
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        text: root.hasMedia ? root.title : "no media"
                        color: "#" + Modules.Theme.colors.fg
                        font.family: Modules.Theme.font.family
                        font.pixelSize: 18
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.hasMedia ? root.artist : ""
                        color: "#" + Modules.Theme.colors.fg_dim
                        font.family: Modules.Theme.font.family
                        font.pixelSize: 15
                        elide: Text.ElideRight
                        visible: root.hasMedia
                    }

                    Row {
                        spacing: 24
                        topPadding: 6
                        visible: root.hasMedia

                        Text {
                            text: "\uf048"
                            color: "#" + Modules.Theme.colors.fg
                            font.family: Modules.Theme.font.icon_family
                            font.pixelSize: 22
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                onClicked: root.control("previous")
                            }
                        }

                        Text {
                            text: root.status === "Playing" ? "\uf04c" : "\uf04b"
                            color: "#" + Modules.Theme.colors.coral
                            font.family: Modules.Theme.font.icon_family
                            font.pixelSize: 22
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                onClicked: root.control("play-pause")
                            }
                        }

                        Text {
                            text: "\uf051"
                            color: "#" + Modules.Theme.colors.fg
                            font.family: Modules.Theme.font.icon_family
                            font.pixelSize: 22
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                onClicked: root.control("next")
                            }
                        }
                    }
                }
            }
        }
    }
}
