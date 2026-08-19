import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property alias streams: streamsModel

    ListModel {
        id: streamsModel
    }

    property var clientNameMap: ({})

    function buildClientNameMap(clientsJson) {
        const map = {}
        for (const client of clientsJson) {
            const props = client.properties
            if (!props) continue
            const objectId = props["object.id"]
            const name = props["application.name"]
            if (objectId && name) {
                map[objectId] = name
            }
        }
        return map
    }

    function displayName(props) {
        if (!props) return "unknown"
        if (props["application.name"]) return props["application.name"]
        if (props["application.process.binary"]) return props["application.process.binary"]
        if (props["client.id"] && root.clientNameMap[props["client.id"]]) {
            return root.clientNameMap[props["client.id"]]
        }
        return "unknown"
    }

    function averagePercent(volumeObj) {
        if (!volumeObj) return 0
        let total = 0
        let count = 0
        for (const ch in volumeObj) {
            const raw = volumeObj[ch] && volumeObj[ch].value_percent
            const num = raw ? parseInt(raw) : NaN
            if (!isNaN(num)) {
                total += num
                count++
            }
        }
        return count > 0 ? Math.round(total / count) : 0
    }

    function reconcile(newList) {
        const newKeys = newList.map(e => e.streamKey)

        for (let i = streamsModel.count - 1; i >= 0; i--) {
            if (newKeys.indexOf(streamsModel.get(i).streamKey) === -1) {
                streamsModel.remove(i)
            }
        }

        for (const entry of newList) {
            let foundAt = -1
            for (let i = 0; i < streamsModel.count; i++) {
                if (streamsModel.get(i).streamKey === entry.streamKey) {
                    foundAt = i
                    break
                }
            }
            if (foundAt >= 0) {
                streamsModel.setProperty(foundAt, "wpctlId", entry.wpctlId)
                streamsModel.setProperty(foundAt, "name", entry.name)
                streamsModel.setProperty(foundAt, "percent", entry.percent)
                streamsModel.setProperty(foundAt, "muted", entry.muted)
            } else {
                streamsModel.append(entry)
            }
        }
    }

    Process {
        id: clientsProc
        command: ["pactl", "-f", "json", "list", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") {
                    root.clientNameMap = {}
                } else {
                    try {
                        root.clientNameMap = root.buildClientNameMap(JSON.parse(text))
                    } catch (e) {
                        console.log("mixer: pactl clients JSON parse error:", e)
                        root.clientNameMap = {}
                    }
                }
                pactlProc.running = true
            }
        }
    }

    Process {
        id: pactlProc
        command: ["pactl", "-f", "json", "list", "sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") {
                    streamsModel.clear()
                    return
                }
                try {
                    const parsed = JSON.parse(text)
                    const list = parsed.map(entry => ({
                        streamKey: entry.index,
                        wpctlId: entry.properties && entry.properties["object.id"]
                            ? parseInt(entry.properties["object.id"])
                            : entry.index,
                        name: root.displayName(entry.properties),
                        percent: root.averagePercent(entry.volume),
                        muted: entry.mute === true
                    }))
                    root.reconcile(list)
                } catch (e) {
                    console.log("mixer: pactl JSON parse error:", e)
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                console.log("mixer: pactl exited with code", code)
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clientsProc.running = true
    }

    Process {
        id: setVolumeProc
        command: ["true"]
    }

    function setVolume(streamKey, wpctlId, pct) {
        const clamped = Math.max(0, Math.min(100, pct))
        for (let i = 0; i < streamsModel.count; i++) {
            if (streamsModel.get(i).streamKey === streamKey) {
                streamsModel.setProperty(i, "percent", clamped)
                break
            }
        }
        setVolumeProc.command = ["wpctl", "set-volume", String(wpctlId), (clamped / 100).toFixed(2)]
        setVolumeProc.running = true
    }
}
