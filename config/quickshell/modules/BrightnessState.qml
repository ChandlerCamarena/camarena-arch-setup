pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root

    property int percentage: 0
    property bool userDragging: false
    property int generation: 0
    property int changeTick: 0

    function refresh() {
        if (root.userDragging) return
        brightnessProc.requestGeneration = root.generation
        brightnessProc.running = true
    }

    Process {
        id: brightnessProc
        property int requestGeneration: 0
        command: ["sh", "-c", "echo $(( $(brightnessctl g) * 100 / $(brightnessctl m) ))"]
        stdout: SplitParser {
            onRead: line => {
                if (brightnessProc.requestGeneration !== root.generation) return
                if (root.userDragging) return
                const val = parseInt(line.trim())
                if (!isNaN(val)) {
                    root.percentage = val
                    root.changeTick++
                }
            }
        }
    }

    Process {
        id: setBrightnessProc
        command: ["sh", "-c", "true"]
    }

    function setBrightness(pct) {
        const clamped = Math.max(1, Math.min(100, pct))
        root.percentage = clamped
        root.changeTick++
        setBrightnessProc.command = ["sh", "-c", "brightnessctl s " + clamped + "%"]
        setBrightnessProc.running = true
    }

    Component.onCompleted: root.refresh()
}
