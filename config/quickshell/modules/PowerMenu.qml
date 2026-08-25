import QtQuick
import Quickshell.Io
import "." as Modules
FocusScope {
    id: root
    property bool menuVisible: false
    property int currentIndex: 0
    readonly property int cols: 3
    readonly property int rows: 2
    readonly property var actions: [
        { label: "REBOOT",    cmd: "systemctl reboot" },
        { label: "LOCK",      cmd: "loginctl lock-session" },
        { label: "SUSPEND",   cmd: "systemctl suspend" },
        { label: "SHUTDOWN",  cmd: "systemctl poweroff" },
        { label: "LOGOUT",    cmd: "loginctl kill-session $XDG_SESSION_ID" },
        { label: "HIBERNATE", cmd: "systemctl hibernate" }
    ]
    implicitWidth: grid.implicitWidth + 40
    implicitHeight: grid.implicitHeight + 40
    onMenuVisibleChanged: {
        if (menuVisible) {
            currentIndex = 0
            root.forceActiveFocus()
        }
    }
    function colOf(i) { return i % cols }
    function rowOf(i) { return Math.floor(i / cols) }
    function indexAt(r, c) { return r * cols + c }
    function moveH(delta) {
        const r = rowOf(currentIndex)
        let c = colOf(currentIndex) + delta
        if (c < 0) c = cols - 1
        if (c >= cols) c = 0
        currentIndex = indexAt(r, c)
    }
    function moveV(delta) {
        let r = rowOf(currentIndex) + delta
        if (r < 0) r = rows - 1
        if (r >= rows) r = 0
        currentIndex = indexAt(r, colOf(currentIndex))
    }
    function fire(index) {
        fireProc.command = ["sh", "-c", actions[index].cmd]
        fireProc.running = true
        root.menuVisible = false
    }
    Process {
        id: fireProc
        command: ["true"]
    }
    Keys.onPressed: event => {
        switch (event.key) {
            case Qt.Key_H: moveH(-1); event.accepted = true; break
            case Qt.Key_L: moveH(1); event.accepted = true; break
            case Qt.Key_J: moveV(1); event.accepted = true; break
            case Qt.Key_K: moveV(-1); event.accepted = true; break
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                fire(currentIndex)
                event.accepted = true
                break
            case Qt.Key_Escape:
                root.menuVisible = false
                event.accepted = true
                break
        }
    }
    Modules.BevelPanel {
        anchors.centerIn: parent
        implicitWidth: grid.implicitWidth + 40
        implicitHeight: grid.implicitHeight + 40
        Grid {
            id: grid
            anchors.centerIn: parent
            columns: root.cols
            spacing: 16
            Repeater {
                model: root.actions
                Modules.BevelPanel {
                    width: 140
                    height: 100
                    sunken: index === root.currentIndex
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: index === root.currentIndex
                            ? "#" + Modules.Theme.colors.coral
                            : "#" + Modules.Theme.colors.fg
                        font.family: Modules.Theme.font.family
                        font.pixelSize: 16
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.fire(index)
                    }
                }
            }
        }
    }
}
