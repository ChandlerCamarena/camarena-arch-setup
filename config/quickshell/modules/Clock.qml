import QtQuick
import "." as Modules

Item {
    id: root
    implicitWidth: 320
    implicitHeight: 140

    // Holds the live Date object, refreshed every second by the Timer below.
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Qt.formatDateTime is QML's built-in date formatting function.
    // Format codes: hh = 2-digit hour, mm = 2-digit minute, ss = 2-digit second,
    // dddd = full weekday name, MMMM = full month name, d = day number.
    readonly property string timeString: Qt.formatDateTime(now, "hh:mm:ss")
    readonly property string dateString: Qt.formatDateTime(now, "dddd, MMMM d")

    Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeString
            color: "#" + Modules.Theme.colors.fg
            font.family: Modules.Theme.font.family
            font.pixelSize: 48
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dateString
            color: "#" + Modules.Theme.colors.fg_dim
            font.family: Modules.Theme.font.family
            font.pixelSize: 16
        }
    }
}
