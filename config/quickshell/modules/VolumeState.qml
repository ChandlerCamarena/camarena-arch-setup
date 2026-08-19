pragma Singleton
import QtQuick
import Quickshell.Io

// Singleton audio state. Single pactl-subscribe process shared by
// the taskbar Volume widget and the OSD, instead of each widget
// running its own subscription (which was the pre-consolidation
// SystemStats problem all over again -- redundant spawns, no shared
// source of truth).
Item {
    id: root

    property int percentage: 0
    property bool muted: false
    property bool userDragging: false
    property int generation: 0

    // Bumped only when percentage/muted actually change, so OSD.qml
    // can watch one signal instead of two separate onXChanged handlers
    // racing each other -- and so unrelated pactl sink events (a new
    // stream attaching, e.g. video starting playback) that trigger a
    // refresh() without an actual volume/mute delta don't pop the OSD.
    property int changeTick: 0

    function refresh() {
        if (root.userDragging) return
        volumeProc.requestGeneration = root.generation
        volumeProc.running = true
    }

    Process {
        id: volumeProc
        property int requestGeneration: 0
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: line => {
                if (volumeProc.requestGeneration !== root.generation) return
                if (root.userDragging) return

                const match = line.match(/Volume:\s*([\d.]+)/)
                const newPercentage = match ? Math.round(parseFloat(match[1]) * 100) : root.percentage
                const newMuted = line.includes("[MUTED]")

                const changed = (newPercentage !== root.percentage) || (newMuted !== root.muted)

                root.percentage = newPercentage
                root.muted = newMuted

                if (changed) {
                    root.changeTick++
                }
            }
        }
    }

    Process {
        id: pactlSubscribe
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("on sink #") !== -1) {
                    root.refresh()
                }
            }
        }
        onExited: (code, status) => {
            console.log("pactl subscribe exited unexpectedly, code:", code, "restarting")
            restartSubscribeTimer.start()
        }
    }

    Timer {
        id: restartSubscribeTimer
        interval: 2000
        repeat: false
        onTriggered: pactlSubscribe.running = true
    }

    Component.onCompleted: root.refresh()

    Process {
        id: setVolumeProc
        command: ["sh", "-c", "true"]
    }

    function setVolume(pct) {
        const clamped = Math.max(0, Math.min(100, pct))
        root.percentage = clamped
        root.changeTick++
        setVolumeProc.command = ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (clamped / 100).toFixed(2)]
        setVolumeProc.running = true
    }

    Process {
        id: muteToggleProc
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
    }

    function toggleMute() {
        muteToggleProc.running = true
        // wpctl's own event will land via pactl subscribe -> refresh(),
        // no need to flip root.muted optimistically here.
    }
}
