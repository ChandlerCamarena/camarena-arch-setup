import QtQuick
import Quickshell.Io
import "." as Modules

// Toggled via `qs ipc call ricepicker toggle` (wire the IpcHandler +
// keybind same as your other dashboard panels). Lists rice dirs under
// ~/.config/rices/, click fires switch.sh, refreshes active marker
// once it exits.
Item {
    id: root
    property bool menuVisible: false
    property var riceList: []
    property string activeName: ""

    implicitWidth: menuVisible ? panel.implicitWidth : 0
    implicitHeight: menuVisible ? panel.implicitHeight : 0

    // ls -1 output spans multiple stdout lines. Collected with
    // StdioCollector instead of SplitParser's line-by-line callback,
    // since we need the whole listing at once, not incremental parsing.
    Process {
        id: rawListProc
        command: ["sh", "-c", "ls -1 $HOME/.config/rices 2>/dev/null | grep -v '^scripts$'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.riceList = text.trim().split("\n").filter(s => s.length > 0)
            }
        }
    }

    function doRefresh() {
        rawListProc.running = true
        activeProc.running = true
    }

    Process {
        id: activeProc
        command: ["sh", "-c", "cat $HOME/.config/rices/.active 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.activeName = text.trim()
            }
        }
    }

    Component.onCompleted: doRefresh()

    function switchTo(name) {
        switchProc.command = ["sh", "-c", Quickshell.env("HOME") + "/.config/rices/scripts/switch.sh " + name]
        switchProc.running = true
    }

    Process {
        id: switchProc
        command: ["true"]
        onExited: (code, status) => {
            if (code === 0) root.doRefresh()
        }
    }

    Modules.BevelPanel {
        id: panel
        visible: root.menuVisible
        implicitWidth: content.implicitWidth + 24
        implicitHeight: content.implicitHeight + 24

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: "RICES"
                color: "#" + Modules.Theme.colors.coral
                font.family: Modules.Theme.font.family
                font.pixelSize: 14
            }

            Repeater {
                model: root.riceList

                Modules.BevelPanel {
                    width: 200
                    height: 32
                    sunken: modelData === root.activeName

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: modelData === root.activeName
                            ? "#" + Modules.Theme.colors.coral
                            : "#" + Modules.Theme.colors.fg
                        font.family: Modules.Theme.font.family
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.switchTo(modelData)
                    }
                }
            }
        }
    }
}
