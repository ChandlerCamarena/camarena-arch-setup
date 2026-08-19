import QtQuick
import Quickshell.Io
import "." as Modules

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property int percentage: 0
    property bool charging: false

    Process {
        id: batteryProc
        command: ["sh", "-c", "upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep -E 'percentage|state'"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("percentage")) {
                    const match = line.match(/(\d+)%/)
                    if (match) root.percentage = parseInt(match[1])
                } else if (line.includes("state")) {
                    // Treat both "charging" and "fully-charged" as
                    // plugged-in states. Only "discharging" means
                    // running on battery.
                    root.charging = !line.includes("discharging")
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: batteryProc.running = true
    }

    Row {
        id: row
        spacing: 4

        Text {
            text: "⚡"
            color: "#" + Modules.Theme.colors.coral
            font.pixelSize: 14
            visible: root.charging
        }

        Text {
            text: root.percentage + "%"
            color: "#" + Modules.Theme.colors.fg
            font.family: Modules.Theme.font.family
            font.pixelSize: 14
        }
    }
}
