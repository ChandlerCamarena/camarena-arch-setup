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

    readonly property var colors: data.colors ?? {}
    readonly property var bevel: data.bevel ?? {}
    readonly property var layout: data.layout ?? {}
    readonly property var font: data.font ?? { "family": "monospace", "size_base": 14, "icon_family": "monospace" }
    readonly property real terminalOpacity: data.terminal_opacity ?? 0.85
}
