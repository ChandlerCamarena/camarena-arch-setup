import QtQuick
import "." as Modules

Item {
    id: root
    property bool expanded: false

    property date today: new Date()

    // Monday-first day-of-week adjustment: JS getDay() returns
    // 0=Sunday..6=Saturday. Shifting by -1 mod 7 makes 0=Monday.
    function buildMonth(year, month) {
        const jsFirstDay = new Date(year, month, 1).getDay()
        const firstDay = (jsFirstDay + 6) % 7
        const daysInMonth = new Date(year, month + 1, 0).getDate()
        let cells = []
        for (let i = 0; i < firstDay; i++) cells.push(0)
        for (let d = 1; d <= daysInMonth; d++) cells.push(d)
        return cells
    }

    readonly property var weekdayLabels: ["M","T","W","T","F","S","S"]

    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    Modules.BevelPanel {
        id: panel
        anchors.fill: parent
        sunken: false

        implicitWidth: content.implicitWidth + 20
        implicitHeight: content.implicitHeight + 20

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: root.expanded
                    ? Qt.formatDateTime(root.today, "yyyy")
                    : Qt.formatDateTime(root.today, "MMMM yyyy")
                color: "#" + Modules.Theme.colors.coral
                font.family: Modules.Theme.font.family
                font.pixelSize: 16
            }

            Grid {
                visible: !root.expanded
                columns: 7
                spacing: 3

                Repeater {
                    model: root.weekdayLabels
                    Text {
                        text: modelData
                        width: 28
                        horizontalAlignment: Text.AlignHCenter
                        color: "#" + Modules.Theme.colors.fg_dim
                        font.family: Modules.Theme.font.family
                        font.pixelSize: 11
                    }
                }

                Repeater {
                    model: root.buildMonth(root.today.getFullYear(), root.today.getMonth())
                    Item {
                        width: 28
                        height: 28

                        Modules.BevelPanel {
                            visible: modelData === root.today.getDate()
                            anchors.fill: parent
                            sunken: true
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData === 0 ? "" : modelData
                            color: modelData === root.today.getDate()
                                ? "#" + Modules.Theme.colors.coral
                                : "#" + Modules.Theme.colors.fg
                            font.family: Modules.Theme.font.family
                            font.pixelSize: 13
                        }
                    }
                }
            }

            Grid {
                visible: root.expanded
                columns: 3
                spacing: 20

                Repeater {
                    model: 12

                    // Capture the outer Repeater's index into a named
                    // property immediately, before entering any nested
                    // Repeater. The inner day-Repeater below declares
                    // its own `index`, which shadows this delegate's
                    // `index` inside its own scope, so referencing
                    // `index` directly inside the inner delegate would
                    // silently read the wrong value.
                    Column {
                        id: monthDelegate
                        property int monthIndex: index
                        spacing: 4

                        Text {
                            text: Qt.formatDateTime(new Date(root.today.getFullYear(), monthDelegate.monthIndex, 1), "MMMM")
                            color: "#" + Modules.Theme.colors.fg_dim
                            font.family: Modules.Theme.font.family
                            font.pixelSize: 12
                        }

                        Grid {
                            columns: 7
                            spacing: 2

                            Repeater {
                                model: root.weekdayLabels
                                Text {
                                    text: modelData
                                    width: 22
                                    horizontalAlignment: Text.AlignHCenter
                                    color: "#" + Modules.Theme.colors.fg_subtle
                                    font.family: Modules.Theme.font.family
                                    font.pixelSize: 8
                                }
                            }

                            Repeater {
                                model: root.buildMonth(root.today.getFullYear(), monthDelegate.monthIndex)
                                Item {
                                    width: 22
                                    height: 22

                                    Modules.BevelPanel {
                                        visible: modelData === root.today.getDate() && monthDelegate.monthIndex === root.today.getMonth()
                                        anchors.fill: parent
                                        sunken: true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData === 0 ? "" : modelData
                                        color: (modelData === root.today.getDate() && monthDelegate.monthIndex === root.today.getMonth())
                                            ? "#" + Modules.Theme.colors.coral
                                            : "#" + Modules.Theme.colors.fg_dim
                                        font.family: Modules.Theme.font.family
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
