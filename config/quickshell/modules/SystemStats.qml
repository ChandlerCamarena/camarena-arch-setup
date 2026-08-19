import QtQuick
import Quickshell.Io

// Data-only component. No visual output of its own; exposes
// properties that shell.qml reads directly into the taskbar and
// graph panels.
//
// PROCESS CONSOLIDATION: mainProc chains everything that's a cheap
// file/sysfs read (CPU, meminfo, per-core freq, vmstat swap
// counters, temp, disk, wifi) into one shell invocation, each
// command's output tagged with a prefix via sed, parsed by prefix
// below. gpuProc (nvidia-smi) and netProc (dynamic IFACE lookup)
// stay separate, different binaries, no shared benefit from
// chaining them in. 8 spawns/sec -> 3 spawns/sec.
Item {
    id: root
    visible: false

    property int cpuPercent: 0
    property int ramPercent: 0
    property int gpuPercent: 0
    property int memTotal: 0
    property int prevIdle: 0
    property int prevTotal: 0

    property string tempStr: "--"
    property string diskStr: "--"
    property string netLiveStr: "--"
    property string netCumulativeStr: "--"

    property real netRxRate: 0
    property real netTxRate: 0

    property real prevRx: -1
    property real prevTx: -1
    property real prevNetTime: 0

    readonly property int historyCapacity: 60
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistory: []
    property var netRxHistory: []
    property var netTxHistory: []
    property int historyTick: 0

    function pushHistory(arr, val) {
        arr.push(val)
        if (arr.length > root.historyCapacity) arr.shift()
    }

    property var coreFrequencies: []
    property var _freqAccum: []

    property real ramTotalKb: 0
    property real ramFreeKb: 0
    property real ramAvailableKb: 0
    property real ramBuffersKb: 0
    property real ramCachedKb: 0
    property real ramSharedKb: 0
    property real swapTotalKb: 0
    property real swapFreeKb: 0
    property real swapUsedKb: 0

    property real swapInRateKbps: 0
    property real swapOutRateKbps: 0
    property bool swapThrashing: false
    property int swapThrashTicks: 0

    property real prevPswpin: -1
    property real prevPswpout: -1
    property real prevVmstatTime: 0
    property real _pswpin: 0
    property real _pswpout: 0

    property real vramUsedMb: 0
    property real vramTotalMb: 0
    property int encoderPercent: 0
    property int decoderPercent: 0

    Process {
        id: mainProc
        command: ["sh", "-c", 'echo "CPU:$(head -1 /proc/stat)"; grep -E "^(MemTotal|MemFree|MemAvailable|Buffers|Cached|Shmem|SwapTotal|SwapFree):" /proc/meminfo | sed "s/^/MEM:/"; cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | sed "s/^/FREQ:/"; grep -E "^(pswpin|pswpout)" /proc/vmstat | sed "s/^/VMSTAT:/"; cat /sys/class/thermal/thermal_zone12/temp 2>/dev/null | sed "s/^/TEMP:/"; df -h / --output=used,size | tail -1 | sed "s/^/DISK:/"']
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("CPU:")) {
                    const rest = line.slice(4)
                    if (rest.startsWith("cpu ")) {
                        const parts = rest.trim().split(/\s+/).slice(1).map(Number)
                        const idle = parts[3] + (parts[4] || 0)
                        const total = parts.reduce((a, b) => a + b, 0)
                        const diffIdle = idle - root.prevIdle
                        const diffTotal = total - root.prevTotal
                        if (diffTotal > 0 && root.prevTotal > 0) {
                            root.cpuPercent = Math.round(100 * (1 - diffIdle / diffTotal))
                            root.pushHistory(root.cpuHistory, root.cpuPercent)
                        }
                        root.prevIdle = idle
                        root.prevTotal = total
                    }
                } else if (line.startsWith("MEM:")) {
                    const rest = line.slice(4)
                    const m = rest.match(/^(\w+):\s*(\d+)/)
                    if (!m) return
                    const key = m[1]
                    const val = parseInt(m[2])
                    switch (key) {
                        case "MemTotal": root.ramTotalKb = val; root.memTotal = val; break
                        case "MemFree": root.ramFreeKb = val; break
                        case "MemAvailable":
                            root.ramAvailableKb = val
                            if (root.ramTotalKb > 0) {
                                root.ramPercent = Math.round(100 * (1 - val / root.ramTotalKb))
                                root.pushHistory(root.ramHistory, root.ramPercent)
                            }
                            break
                        case "Buffers": root.ramBuffersKb = val; break
                        case "Cached": root.ramCachedKb = val; break
                        case "Shmem": root.ramSharedKb = val; break
                        case "SwapTotal": root.swapTotalKb = val; break
                        case "SwapFree":
                            root.swapFreeKb = val
                            root.swapUsedKb = root.swapTotalKb - val
                            break
                    }
                } else if (line.startsWith("FREQ:")) {
                    const khz = parseInt(line.slice(5))
                    if (!isNaN(khz)) root._freqAccum.push(khz / 1000000)
                } else if (line.startsWith("VMSTAT:")) {
                    const parts = line.slice(7).trim().split(/\s+/)
                    if (parts[0] === "pswpin") root._pswpin = parseInt(parts[1])
                    if (parts[0] === "pswpout") root._pswpout = parseInt(parts[1])
                } else if (line.startsWith("TEMP:")) {
                    const val = parseInt(line.slice(5))
                    if (!isNaN(val)) root.tempStr = Math.round(val / 1000) + "°C"
                } else if (line.startsWith("DISK:")) {
                    const parts = line.slice(5).trim().split(/\s+/)
                    if (parts.length === 2) root.diskStr = parts[0] + "/" + parts[1]
                }
            }
        }
        onExited: (code, status) => {
            root.coreFrequencies = root._freqAccum

            const now = Date.now() / 1000
            if (root.prevPswpin >= 0 && root.prevVmstatTime > 0) {
                const dt = now - root.prevVmstatTime
                if (dt > 0) {
                    root.swapInRateKbps = Math.max(0, (root._pswpin - root.prevPswpin) * 4096 / 1024 / dt)
                    root.swapOutRateKbps = Math.max(0, (root._pswpout - root.prevPswpout) * 4096 / 1024 / dt)

                    if (root.swapInRateKbps > 0 || root.swapOutRateKbps > 0) {
                        root.swapThrashTicks++
                    } else {
                        root.swapThrashTicks = 0
                    }
                    root.swapThrashing = root.swapThrashTicks >= 3
                }
            }
            root.prevPswpin = root._pswpin
            root.prevPswpout = root._pswpout
            root.prevVmstatTime = now
        }
    }

    Process {
        id: gpuProc
        command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,utilization.encoder,utilization.decoder --format=csv,noheader,nounits"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(",").map(s => s.trim())
                if (parts.length < 5) return
                const util = parseInt(parts[0])
                if (!isNaN(util)) {
                    root.gpuPercent = util
                    root.pushHistory(root.gpuHistory, util)
                }
                root.vramUsedMb = parseFloat(parts[1]) || 0
                root.vramTotalMb = parseFloat(parts[2]) || 0
                root.encoderPercent = parseInt(parts[3]) || 0
                root.decoderPercent = parseInt(parts[4]) || 0
            }
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c", "IFACE=$(ip route | awk '/default/ {print $5; exit}'); grep \"$IFACE:\" /proc/net/dev"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.trim().split(/\s+/)
                const rxBytes = parseInt(parts[1])
                const txBytes = parseInt(parts[9])

                const rxMbCumulative = (rxBytes * 8 / 1000000).toFixed(1)
                const txMbCumulative = (txBytes * 8 / 1000000).toFixed(1)
                root.netCumulativeStr = rxMbCumulative + "↓ " + txMbCumulative + "↑ Mb"

                const now = Date.now() / 1000
                if (root.prevRx >= 0 && root.prevNetTime > 0) {
                    const dt = now - root.prevNetTime
                    if (dt > 0) {
                        const rxRateMbps = (rxBytes - root.prevRx) * 8 / 1000000 / dt
                        const txRateMbps = (txBytes - root.prevTx) * 8 / 1000000 / dt
                        root.netRxRate = rxRateMbps
                        root.netTxRate = txRateMbps
                        root.netLiveStr = rxRateMbps.toFixed(2) + "↓ " + txRateMbps.toFixed(2) + "↑ Mbps"
                        root.pushHistory(root.netRxHistory, rxRateMbps)
                        root.pushHistory(root.netTxHistory, txRateMbps)
                    }
                }
                root.prevRx = rxBytes
                root.prevTx = txBytes
                root.prevNetTime = now
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root._freqAccum = []
            mainProc.running = true
            gpuProc.running = true
            netProc.running = true
            root.historyTick++
        }
    }
}
