import QtQuick
import "." as Modules

Rectangle {
    id: root

    property bool sunken: false
    property color fillColor: "#" + Modules.Theme.colors.bg_surface

    // Bevel width comes from theme.json's shared layout value
    readonly property int bevelWidth: Modules.Theme.bevel.width ?? 2

    // Base rectangle acts as the "dark" bevel color, showing through
    // on the bottom/right (raised) or top/left (sunken) edges.
    color: sunken
        ? "#" + Modules.Theme.bevel.sunken_dark
        : "#" + Modules.Theme.bevel.raised_dark

    // Top/left light edge
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.bevelWidth
        anchors.bottomMargin: root.bevelWidth
        color: root.sunken
            ? "#" + Modules.Theme.bevel.sunken_light
            : "#" + Modules.Theme.bevel.raised_light
    }

    // Inner fill, inset by bevel width on all sides, this is the
    // actual content background color.
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.bevelWidth
        color: root.fillColor
    }

    default property alias content: contentItem.data
    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: root.bevelWidth
    }
}
