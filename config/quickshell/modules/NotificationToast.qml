import QtQuick
import Quickshell.Services.Notifications
import "." as Modules

Item {
    id: root
    property var notifServer: null

    property string toastSummary: ""
    property string toastBody: ""
    property string toastAppName: ""
    property int toastUrgency: NotificationUrgency.Normal
    property bool toastVisible: false

    // expireTimeout is in SECONDS (confirmed from Quickshell source,
    // notification.hpp). Servers commonly send <=0 to mean "no
    // expiry hint given" -- guard against that rather than trusting
    // a positive value is always present.
    readonly property int defaultDurationMs: 5000

    Connections {
        target: root.notifServer
        function onNotification(notification) {
            root.toastSummary = notification.summary
            root.toastBody = notification.body
            root.toastAppName = notification.appName
            root.toastUrgency = notification.urgency
            root.toastVisible = true

            const durationMs = notification.expireTimeout > 0
                ? notification.expireTimeout * 1000
                : root.defaultDurationMs

            // Critical notifications stay put until manually dismissed
            // or the panel is closed elsewhere -- don't auto-expire
            // an alert that was loud enough to earn a sound.
            if (notification.urgency === NotificationUrgency.Critical) {
                toastTimer.stop()
                progressBar.width = progressTrack.width
            } else {
                toastTimer.interval = durationMs
                toastTimer.restart()
                progressAnim.duration = durationMs
                progressBar.width = progressTrack.width
                progressAnim.restart()
            }
        }
    }

    Timer {
        id: toastTimer
        onTriggered: root.toastVisible = false
    }

    implicitWidth: toastVisible ? panel.width : 0
    implicitHeight: toastVisible ? panel.implicitHeight : 0

    // Fixed width panel, content fills it via anchors rather than
    // an explicit Column width that would fight implicitWidth sizing.
    Modules.BevelPanel {
        id: panel
        visible: root.toastVisible
        width: 280
        implicitHeight: content.implicitHeight + 24
        opacity: root.toastUrgency === NotificationUrgency.Low ? 0.6 : 1.0

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 4

            Text {
                width: parent.width
                visible: root.toastAppName !== ""
                text: root.toastAppName
                color: "#" + Modules.Theme.colors.fg_subtle
                font.family: Modules.Theme.font.family
                font.pixelSize: 10
            }

            Text {
                width: parent.width
                text: root.toastSummary
                color: "#" + Modules.Theme.colors.coral
                font.family: Modules.Theme.font.family
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: root.toastBody !== ""
                text: root.toastBody
                color: "#" + Modules.Theme.colors.fg
                font.family: Modules.Theme.font.family
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            // Auto-dismiss progress track. Hidden for Critical since
            // those don't auto-expire.
            Modules.BevelPanel {
                id: progressTrack
                visible: root.toastUrgency !== NotificationUrgency.Critical
                width: parent.width
                height: 6
                sunken: true

                Rectangle {
                    id: progressBar
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    color: "#" + Modules.Theme.colors.cyan

                    NumberAnimation on width {
                        id: progressAnim
                        to: 0
                        running: false
                    }
                }
            }
        }

        // Critical outline overlay.
        Rectangle {
            anchors.fill: parent
            visible: root.toastUrgency === NotificationUrgency.Critical
            color: "transparent"
            border.width: 2
            border.color: "#" + Modules.Theme.colors.error
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                toastTimer.stop()
                progressAnim.stop()
                root.toastVisible = false
            }
        }
    }
}
