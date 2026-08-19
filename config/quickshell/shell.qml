import QtQuick
import Quickshell
import Quickshell.Io
import "modules" as Modules

ShellRoot {
    property bool dashboardVisible: false
    property bool busy: false
    property string savedWorkspace: ""

    Modules.NotificationDaemon {
        id: notifDaemon
    }

    Modules.SystemStats {
        id: sysStats
    }

    Modules.VolumeOSD {}
    Modules.BrightnessOSD {}

    IpcHandler {
        target: "ricepicker"

        function toggle(): void {
            riceSwitcher.menuVisible = !riceSwitcher.menuVisible
            if (riceSwitcher.menuVisible) riceSwitcher.doRefresh()
        }
    }


    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            if (busy) {
                console.log("toggle ignored, still processing previous request")
                return
            }
            busy = true
            dashboardVisible = !dashboardVisible
            if (!dashboardVisible && dashContentLoader.item) {
                dashContentLoader.item.notifCenter.popupVisible = false
                dashContentLoader.item.calendar.expanded = false
                dashContentLoader.item.mixer.popupVisible = false
            }
            captureWorkspaceProc.running = true
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void {
            if (!dashContentLoader.item) return
            dashContentLoader.item.calendarVisible = !dashContentLoader.item.calendarVisible
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            if (!dashContentLoader.item) return
            const nc = dashContentLoader.item.notifCenter
            nc.popupVisible = !nc.popupVisible
            if (nc.popupVisible) {
                notifDaemon.markAllRead()
            }
        }
    }

    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            powerMenu.menuVisible = !powerMenu.menuVisible
        }
    }

    IpcHandler {
        target: "cpugraph"

        function toggle(): void {
            if (!dashContentLoader.item) return
            dashContentLoader.item.cpuGraphOpen = !dashContentLoader.item.cpuGraphOpen
        }
    }

    IpcHandler {
        target: "ramgraph"

        function toggle(): void {
            if (!dashContentLoader.item) return
            dashContentLoader.item.ramGraphOpen = !dashContentLoader.item.ramGraphOpen
        }
    }

    IpcHandler {
        target: "gpugraph"

        function toggle(): void {
            if (!dashContentLoader.item) return
            dashContentLoader.item.gpuGraphOpen = !dashContentLoader.item.gpuGraphOpen
        }
    }

    IpcHandler {
        target: "netgraph"

        function toggle(): void {
            if (!dashContentLoader.item) return
            dashContentLoader.item.netGraphOpen = !dashContentLoader.item.netGraphOpen
        }
    }

    IpcHandler {
        target: "brightness"

        function sync(): void {
            Modules.BrightnessState.refresh()
        }
    }

    IpcHandler {
        target: "mixer"

        function toggle(): void {
            if (!dashContentLoader.item) return
            dashContentLoader.item.mixer.popupVisible = !dashContentLoader.item.mixer.popupVisible
        }
    }

    Process {
        id: captureWorkspaceProc
        command: ["sh", "-c", "hyprctl activeworkspace -j | jq -r '.id'"]
        stdout: SplitParser {
            onRead: line => { savedWorkspace = line.trim() }
        }
        onExited: (code, status) => {
            if (dashboardVisible) {
                hideProc.running = true
            } else {
                showProc.running = true
            }
        }
    }

    Process {
        id: hideProc
        command: ["sh", "-c", "hyprctl clients -j | jq -r '.[].address' | while read addr; do hyprctl dispatch \"hl.dsp.focus({window = 'address:$addr'})\"; hyprctl dispatch 'hl.dsp.window.tag({tag = \"+dashboard_hidden\"})'; done"]
        onExited: (code, status) => { restoreWorkspaceProc.running = true }
    }

    Process {
        id: showProc
        command: ["sh", "-c", "hyprctl clients -j | jq -r '.[].address' | while read addr; do hyprctl dispatch \"hl.dsp.focus({window = 'address:$addr'})\"; hyprctl dispatch 'hl.dsp.window.tag({tag = \"-dashboard_hidden\"})'; done"]
        onExited: (code, status) => { restoreWorkspaceProc.running = true }
    }

    Process {
        id: restoreWorkspaceProc
        command: ["sh", "-c", "hyprctl dispatch \"hl.dsp.focus({workspace = '" + savedWorkspace + "'})\""]
        onExited: (code, status) => { busy = false }
    }

    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        color: "transparent"
        visible: dashboardVisible

        Loader {
            id: dashContentLoader
            anchors.fill: parent
            active: dashboardVisible

            sourceComponent: Item {
                id: dashRoot
                anchors.fill: parent

                property alias notifCenter: notifCenter
                property alias calendar: calendar
                property alias mixer: mixer
                property alias brightnessWidget: brightnessWidget

                property bool cpuGraphOpen: false
                property bool ramGraphOpen: false
                property bool gpuGraphOpen: false
                property bool netGraphOpen: false
                property bool calendarVisible: false

                Modules.Clock {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 40
                }

                Modules.NotificationCenter {
                    id: notifCenter
                    daemon: notifDaemon
                    anchors.right: parent.right
                    anchors.rightMargin: 40
                    anchors.bottom: mixer.popupVisible ? mixer.top : parent.bottom
                    anchors.bottomMargin: mixer.popupVisible ? 12 : 76
                }

                Modules.Calendar {
                    id: calendar
                    visible: dashRoot.calendarVisible
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 20
                    anchors.bottomMargin: 80
                }

                /*
                Modules.Media {
                    anchors.left: calendar.right
                    anchors.bottom: calendar.bottom
                    anchors.leftMargin: 20
                }
                */

                Column {
                    id: statGraphStack
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.topMargin: 40
                    anchors.leftMargin: 40
                    spacing: 12

                    Modules.StatGraph {
                        visible: dashRoot.cpuGraphOpen
                        title: "CPU"
                        unit: "%"
                        history: sysStats.cpuHistory
                        tick: sysStats.historyTick
                        lineColorHex: "06afc7"
                        minValue: 0
                        maxValue: 100
                        panelWidth: 600
                        thresholdColored: true
                        seriesFillAlpha: 0.5

                        Grid {
                            width: parent.width
                            columns: 6
                            columnSpacing: 4
                            rowSpacing: 4

                            Repeater {
                                model: sysStats.coreFrequencies

                                Modules.BevelPanel {
                                    width: 92
                                    height: 34
                                    sunken: true

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 0

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "C" + index
                                            color: "#" + Modules.Theme.colors.fg_subtle
                                            font.family: Modules.Theme.font.family
                                            font.pixelSize: 9
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.toFixed(2) + " GHz"
                                            color: modelData >= 4.0
                                                ? ("#" + Modules.Theme.colors.coral)
                                                : ("#" + Modules.Theme.colors.fg)
                                            font.family: Modules.Theme.font.family
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Modules.StatGraph {
                        visible: dashRoot.ramGraphOpen
                        title: "RAM"
                        unit: "%"
                        history: sysStats.ramHistory
                        tick: sysStats.historyTick
                        lineColorHex: "9b6eb5"
                        minValue: 0
                        maxValue: 100
                        panelWidth: 600
                        thresholdColored: true
                        seriesFillAlpha: 0.5

                        Column {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "Used " + ((sysStats.ramTotalKb - sysStats.ramAvailableKb) / 1048576).toFixed(1)
                                    + " / " + (sysStats.ramTotalKb / 1048576).toFixed(1) + " GB"
                                color: "#" + Modules.Theme.colors.fg
                                font.family: Modules.Theme.font.family
                                font.pixelSize: 12
                            }
                            Text {
                                text: "Buff/Cache " + ((sysStats.ramBuffersKb + sysStats.ramCachedKb) / 1048576).toFixed(1) + " GB"
                                color: "#" + Modules.Theme.colors.fg_dim
                                font.family: Modules.Theme.font.family
                                font.pixelSize: 12
                            }
                            Text {
                                text: "Shared " + (sysStats.ramSharedKb / 1048576).toFixed(2) + " GB"
                                color: "#" + Modules.Theme.colors.fg_dim
                                font.family: Modules.Theme.font.family
                                font.pixelSize: 12
                            }
                            Text {
                                text: "Swap " + (sysStats.swapUsedKb / 1048576).toFixed(2)
                                    + " / " + (sysStats.swapTotalKb / 1048576).toFixed(2) + " GB"
                                color: sysStats.swapThrashing
                                    ? ("#" + Modules.Theme.colors.error)
                                    : ("#" + Modules.Theme.colors.fg_dim)
                                font.family: Modules.Theme.font.family
                                font.pixelSize: 12
                            }
                            Text {
                                visible: sysStats.swapThrashing
                                text: "⚠ SWAP THRASHING (" + sysStats.swapInRateKbps.toFixed(0)
                                    + " in / " + sysStats.swapOutRateKbps.toFixed(0) + " out KB/s)"
                                color: "#" + Modules.Theme.colors.error
                                font.family: Modules.Theme.font.family
                                font.pixelSize: 12
                            }
                        }
                    }

                    Modules.StatGraph {
                        visible: dashRoot.gpuGraphOpen
                        title: "GPU"
                        unit: "%"
                        history: sysStats.gpuHistory
                        tick: sysStats.historyTick
                        lineColorHex: "e8505b"
                        minValue: 0
                        maxValue: 100
                        panelWidth: 600
                        thresholdColored: true
                        seriesFillAlpha: 0.5

                        Column {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "VRAM " + (sysStats.vramUsedMb / 1024).toFixed(2)
                                    + " / " + (sysStats.vramTotalMb / 1024).toFixed(0) + " GB"
                                color: "#" + Modules.Theme.colors.fg
                                font.family: Modules.Theme.font.family
                                font.pixelSize: 12
                            }
                            Text {
                                text: "Encoder " + sysStats.encoderPercent + "%"
                                color: "#" + Modules.Theme.colors.fg_dim
                                font.family: Modules.Theme.font.family
                                font.pixelSize: 12
                            }
                            Text {
                                text: "Decoder " + sysStats.decoderPercent + "%"
                                color: "#" + Modules.Theme.colors.fg_dim
                                font.family: Modules.Theme.font.family
                                font.pixelSize: 12
                            }
                        }
                    }

                    Modules.StatGraph {
                        visible: dashRoot.netGraphOpen
                        title: "NET"
                        unit: " Mbps"
                        primaryLabel: "DOWN"
                        history: sysStats.netRxHistory
                        historySecondary: sysStats.netTxHistory
                        secondaryLabel: "UP"
                        tick: sysStats.historyTick
                        lineColorHex: "06afc7"
                        lineColorSecondaryHex: "e8505b"
                        autoScale: true
                        panelWidth: 600
                        seriesFillAlpha: 0.5
                        secondaryInverted: true
                    }
                }

                Modules.MixerDaemon {
                    id: mixerDaemon
                }

                Modules.Mixer {
                    id: mixer
                    daemon: mixerDaemon
                    anchors.right: parent.right
                    anchors.rightMargin: 40
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 76
                }

                Modules.BevelPanel {
                    id: taskbar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 56

                    Row {
                        id: leftGroup
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16
                        spacing: 32

                        Modules.WorkspaceIndicator {}

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 18

                            Item {
                                id: cpuWrap
                                implicitWidth: cpuMeter.implicitWidth
                                implicitHeight: cpuMeter.implicitHeight

                                Modules.MiniMeter {
                                    id: cpuMeter
                                    label: "CPU"
                                    value: sysStats.cpuPercent
                                    barWidth: 80
                                    fontSize: 14
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: dashRoot.cpuGraphOpen = !dashRoot.cpuGraphOpen
                                }
                            }
                            Item {
                                id: ramWrap
                                implicitWidth: ramMeter.implicitWidth
                                implicitHeight: ramMeter.implicitHeight

                                Modules.MiniMeter {
                                    id: ramMeter
                                    label: "RAM"
                                    value: sysStats.ramPercent
                                    barWidth: 80
                                    fontSize: 14
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: dashRoot.ramGraphOpen = !dashRoot.ramGraphOpen
                                }
                            }
                            Item {
                                id: gpuWrap
                                implicitWidth: gpuMeter.implicitWidth
                                implicitHeight: gpuMeter.implicitHeight

                                Modules.MiniMeter {
                                    id: gpuMeter
                                    label: "GPU"
                                    value: sysStats.gpuPercent
                                    barWidth: 80
                                    fontSize: 14
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: dashRoot.gpuGraphOpen = !dashRoot.gpuGraphOpen
                                }
                            }
                        }
                    }

                    property real gapSize: Math.max(0,
                        (rightGroup.x - (leftGroup.x + leftGroup.width) - tempGroup.width - mediaWidget.width) / 3)

                    Row {
                        id: tempGroup
                        anchors.left: leftGroup.right
                        anchors.leftMargin: taskbar.gapSize
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "TEMP " + sysStats.tempStr
                            color: "#" + Modules.Theme.colors.fg_dim
                            font.family: Modules.Theme.font.family
                            font.pixelSize: 13
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "DISK " + sysStats.diskStr
                            color: "#" + Modules.Theme.colors.fg_dim
                            font.family: Modules.Theme.font.family
                            font.pixelSize: 13
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Modules.WifiState.ssid !== ""
                            text: Modules.WifiState.ssid + " " + Modules.WifiState.signal + "%"
                            color: "#" + Modules.Theme.colors.fg_dim
                            font.family: Modules.Theme.font.family
                            font.pixelSize: 13
                        }
                    }

                    Modules.MediaCompact {
                        id: mediaWidget
                        anchors.left: tempGroup.right
                        anchors.leftMargin: taskbar.gapSize
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        id: rightGroup
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 16
                        spacing: 20

                        Item {
                            id: netWrap
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: netText.implicitWidth
                            implicitHeight: netText.implicitHeight

                            Text {
                                id: netText
                                text: sysStats.netLiveStr + " (" + sysStats.netCumulativeStr + ")"
                                color: "#" + Modules.Theme.colors.fg_dim
                                font.family: Modules.Theme.font.family
                                font.pixelSize: 13
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: dashRoot.netGraphOpen = !dashRoot.netGraphOpen
                            }
                        }

                        Modules.Volume {
                            anchors.verticalCenter: parent.verticalCenter
                            onMixerToggleRequested: mixer.popupVisible = !mixer.popupVisible
                        }
                        Modules.Brightness {
                            id: brightnessWidget
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Modules.Battery {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Modules.NotificationBell {
                            id: bell
                            notificationCount: notifDaemon.unreadCount
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                notifCenter.popupVisible = !notifCenter.popupVisible
                                notifDaemon.markAllRead()
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        color: "transparent"
        visible: powerMenu.menuVisible
        focusable: true

        Modules.PowerMenu {
            id: powerMenu
            anchors.fill: parent
        }
    }

    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        color: "transparent"
        visible: riceSwitcher.menuVisible
        focusable: true

        Modules.RiceSwitcher {
            id: riceSwitcher
            anchors.centerIn: parent
        }
    }

    PanelWindow {
        anchors {
            top: true
            right: true
        }
        color: "transparent"
        visible: true
        implicitWidth: toast.implicitWidth > 0 ? toast.implicitWidth + 40 : 1
        implicitHeight: toast.implicitHeight > 0 ? toast.implicitHeight + 40 : 1

        Modules.NotificationToast {
            id: toast
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            notifServer: notifDaemon.notifServer
        }
    }
}
