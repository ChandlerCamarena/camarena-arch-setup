import QtQuick
import "." as Modules

Row {
    id: root
    property string label: ""
    property int value: 0
    property int barWidth: 60
    property int fontSize: 12

    // Threshold-based coloring: blue up to 60%, yellow 60-80%,
    // coral above 80%. Applies to both the bar fill and the number.
    readonly property color statColor: value >= 80
        ? "#" + Modules.Theme.colors.error
        : value >= 60
            ? "#" + Modules.Theme.colors.warning
            : "#" + Modules.Theme.colors.cyan

    spacing: 6

    Text {
        text: root.label
        color: "#" + Modules.Theme.colors.fg_dim
        font.family: Modules.Theme.font.family
        font.pixelSize: root.fontSize
    }

    Modules.BevelPanel {
        width: root.barWidth
        height: 14
        sunken: true

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 3
            width: (parent.width - 6) * (root.value / 100)
            height: 8
            color: root.statColor
        }
    }

    Text {
        text: root.value + "%"
        color: root.statColor
        font.family: Modules.Theme.font.family
        font.pixelSize: root.fontSize
    }
}
