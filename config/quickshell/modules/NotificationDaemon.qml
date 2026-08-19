import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "." as Modules

Item {
    id: root
    property bool popupVisible: false
    property alias notifServer: notifServer
    property int unreadCount: 0

    property var reversedNotifications: {
        const list = notifServer.trackedNotifications.values
        let copy = []
        for (let i = list.length - 1; i >= 0; i--) copy.push(list[i])
        return copy
    }

    NotificationServer {
        id: notifServer
        onNotification: notification => {
            console.log("notification received: app=", notification.appName, "summary=", notification.summary, "urgency=", notification.urgency, "transient=", notification.transient)
            notification.tracked = true
            root.unreadCount++

            // Only Critical notifications get the alert sound. Low/Normal
            // stay silent so the sound actually signals something.
            if (notification.urgency === NotificationUrgency.Critical) {
                alertSoundProc.running = true
            }
        }
    }

    Process {
        id: alertSoundProc
        command: ["pw-play", Quickshell.env("HOME") + "/.config/quickshell/sounds/mgs-alert.wav"]
    }

    function markAllRead() {
        root.unreadCount = 0
    }

    function clearAll() {
        const list = notifServer.trackedNotifications.values
        for (let i = list.length - 1; i >= 0; i--) {
            list[i].tracked = false
        }
    }

    implicitWidth: popupVisible ? panel.implicitWidth : 0
    implicitHeight: popupVisible ? panel.implicitHeight : 0

    Modules.BevelPanel {
        id: panel
        visible: root.popupVisible
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        implicitWidth: content.implicitWidth + 24
        implicitHeight: content.implicitHeight + 24

        Column {
            id: content
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: 12
            spacing: 10

            Text {
                text: "NOTIFICATIONS"
                color: "#" + Modules.Theme.colors.coral
                font.family: Modules.Theme.font.family
                font.pixelSize: 14
            }

            Text {
                visible: root.reversedNotifications.length === 0
                text: "no notifications"
                color: "#" + Modules.Theme.colors.fg_subtle
                font.family: Modules.Theme.font.family
                font.pixelSize: 12
            }

            Repeater {
                model: root.reversedNotifications

                Item {
                    id: notifCard
                    width: 260
                    implicitHeight: notifBevel.implicitHeight
                    opacity: modelData.urgency === NotificationUrgency.Low ? 0.6 : 1.0

                    Modules.BevelPanel {
                        id: notifBevel
                        width: parent.width
                        implicitHeight: notifColumn.implicitHeight + 16
                        sunken: true

                        Column {
                            id: notifColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 8
                            spacing: 2

                            Row {
                                width: parent.width
                                spacing: 6

                                Text {
                                    text: modelData.appName !== "" ? modelData.appName : "unknown"
                                    color: "#" + Modules.Theme.colors.fg_subtle
                                    font.family: Modules.Theme.font.family
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                width: parent.width
                                text: modelData.summary
                                color: "#" + Modules.Theme.colors.fg
                                font.family: Modules.Theme.font.family
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: modelData.body !== ""
                                text: modelData.body
                                color: "#" + Modules.Theme.colors.fg_dim
                                font.family: Modules.Theme.font.family
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: modelData.urgency === NotificationUrgency.Critical
                        color: "transparent"
                        border.width: 2
                        border.color: "#" + Modules.Theme.colors.error
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: modelData.dismiss()
                    }
                }
            }

            Modules.BevelPanel {
                width: 260
                height: 28
                visible: root.reversedNotifications.length > 0

                Text {
                    anchors.centerIn: parent
                    text: "CLEAR ALL"
                    color: "#" + Modules.Theme.colors.error
                    font.family: Modules.Theme.font.family
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.clearAll()
                }
            }
        }
    }
}
