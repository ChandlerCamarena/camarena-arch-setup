import QtQuick
import Quickshell.Io
import "." as Modules

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property var workspaceList: []
    property int activeId: -1

    readonly property var labelMap: ({
        1: "W",
        2: "~",
        3: "1",
        4: "2",
        5: "3",
        6: "4",
        7: "5"
    })

    function labelFor(id) {
        return labelMap[id] !== undefined ? labelMap[id] : String(id)
    }

    Process {
        id: combinedProc
        command: ["sh", "-c", 'echo "LIST:$(hyprctl workspaces -j | jq -c "[.[] | {id: .id}] | sort_by(.id)")"; echo "ACTIVE:$(hyprctl activeworkspace -j | jq -r ".id")"']
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("LIST:")) {
                    try {
                        root.workspaceList = JSON.parse(line.slice(5))
                    } catch (e) {
                        console.log("workspace parse error:", e)
                    }
                } else if (line.startsWith("ACTIVE:")) {
                    root.activeId = parseInt(line.slice(7))
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: combinedProc.running = true
    }

    Row {
        id: row
        spacing: 6

        Repeater {
            model: root.workspaceList
            Modules.BevelPanel {
                width: 33
                height: 33
                sunken: modelData.id === root.activeId

                Text {
                    anchors.centerIn: parent
                    text: root.labelFor(modelData.id)
                    color: modelData.id === root.activeId
                        ? "#" + Modules.Theme.colors.coral
                        : "#" + Modules.Theme.colors.fg_dim
                    font.family: Modules.Theme.font.family
                    font.pixelSize: 16
                }
            }
        }
    }
}
