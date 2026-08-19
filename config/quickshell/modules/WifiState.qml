pragma Singleton
import QtQuick
import Quickshell.Io

// Singleton wifi state. Pulled out of SystemStats' 1s-interval
// mainProc chain -- the nmcli query that produces SSID/signal is
// NOT a cheap read like the rest of that chain, it triggers an
// active radio scan (confirmed: ~2.25s wall-clock on first call,
// ~12ms on a cache hit immediately after). Polling that every
// second, forever, once SystemStats goes always-on, means
// continuous background radio scanning -- real battery/driver
// cost, not just wasted CPU.
//
// Same subscribe-process shape as VolumeState.qml: a long-lived
// `nmcli monitor` process that emits a line on real connectivity
// events (connect/disconnect/roam), triggering one on-demand
// refresh() instead of polling. A slow independent timer tops up
// signal-strength staleness between real events, since signal
// dBm can drift without a monitor-visible event firing.
Item {
    id: root

    property string ssid: ""
    property int signal: 0
    property int changeTick: 0
    property bool refreshing: false

    function refresh() {
        // Guard against overlapping scans -- a monitor event and
        // the slow timer could otherwise both fire while a prior
        // query is still mid-scan.
        if (root.refreshing) return
        root.refreshing = true
        wifiQueryProc.running = true
    }

    Process {
        id: wifiQueryProc
        command: ["sh", "-c", "nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | grep '^yes'"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(":")
                if (parts.length >= 3) {
                    root.ssid = parts[1]
                    root.signal = parseInt(parts[2]) || 0
                    root.changeTick++
                }
            }
        }
        onExited: (code, status) => {
            root.refreshing = false
        }
    }

    // Long-lived, emits a line on real connectivity state changes
    // (associate, disassociate, roam to different AP, etc). This is
    // the event source that replaces 1s polling.
    Process {
        id: nmcliMonitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                root.refresh()
            }
        }
        onExited: (code, status) => {
            console.log("nmcli monitor exited unexpectedly, code:", code, "restarting")
            restartMonitorTimer.start()
        }
    }

    Timer {
        id: restartMonitorTimer
        interval: 2000
        repeat: false
        onTriggered: nmcliMonitor.running = true
    }

    // Signal strength (not SSID/connection state) can drift without
    // nmcli monitor emitting anything -- this is the top-up for that,
    // deliberately slow since each firing costs a real scan.
    Timer {
        interval: 45000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
