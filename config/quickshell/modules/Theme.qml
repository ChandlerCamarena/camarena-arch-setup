pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var data: ({})

    property FileView configFile: FileView {
        path: Qt.resolvedUrl(Quickshell.env("HOME") + "/.config/hypr/theme.json")
        watchChanges: true
        onLoaded: {
            try {
                root.data = JSON.parse(text())
            } catch (e) {
                console.log("[Theme.qml] Failed to parse theme.json, keeping previous data:", e)
            }
        }
        onFileChanged: reload()
    }

    // theme.json is a symlink into the active rice. A rice switch
    // repoints it, but the watcher stays on the old target, so
    // switch.sh calls this (via `qs ipc call theme reload`) to re-set
    // the path, which re-reads and re-watches the new target.
    function reload() {
        const p = configFile.path
        configFile.path = ""
        configFile.path = p
    }

    readonly property var colors: data.colors ?? {}
    readonly property var bevel: data.bevel ?? {}
    readonly property var layout: data.layout ?? {}
    readonly property var font: data.font ?? { "family": "monospace", "size_base": 14, "icon_family": "monospace" }
    readonly property real terminalOpacity: data.terminal_opacity ?? 0.85
}
