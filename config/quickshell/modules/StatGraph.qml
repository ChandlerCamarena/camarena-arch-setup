import QtQuick
import "." as Modules

// Reusable history graph panel. Reads a plain JS array (from
// SystemStats' ring buffers) and redraws on demand via `tick`.
//
// thresholdColored=true (CPU/RAM/GPU): single header row, title
// left, current value right, both colored by the standard
// cyan/warning/error thresholds matching MiniMeter. No legend
// swatch, single series only.
//
// thresholdColored=false (NET): original title + per-series
// legend rows with fixed colors, since it has two series (rx/tx)
// that need distinguishing and no meaningful 0-100% threshold.
Item {
    id: root

    property string title: ""
    property string unit: "%"
    property int tick: 0
    property bool thresholdColored: false

    property var history: []
    property string lineColorHex: "e8505b"
    property string primaryLabel: ""

    property var historySecondary: null
    property string lineColorSecondaryHex: "06afc7"
    property string secondaryLabel: ""

    property real minValue: 0
    property real maxValue: 100
    property bool autoScale: false

    readonly property int historyCapacity: 60
    property real seriesFillAlpha: 0
    property bool secondaryInverted: false

    property real panelWidth: 600
    readonly property real graphAreaHeight: 160

    default property alias extraData: extraColumn.data

    // Updated imperatively on tick, not via binding, since the
    // source arrays are mutated in place and never reassigned.
    property string currentValueStr: "--"
    property string currentSecondaryStr: "--"
    property string currentColorHex: lineColorHex

    implicitWidth: panelWidth
    implicitHeight: panel.height

    function thresholdColor(v) {
        if (v >= 80) return Modules.Theme.colors.error
        if (v >= 60) return Modules.Theme.colors.warning
        return Modules.Theme.colors.cyan
    }

    function updateCurrentValues() {
        if (root.history.length > 0) {
            const latest = root.history[root.history.length - 1]
            currentValueStr = (root.autoScale ? latest.toFixed(1) : Math.round(latest)) + root.unit
            currentColorHex = root.thresholdColored ? thresholdColor(latest) : root.lineColorHex
        } else {
            currentValueStr = "--"
            currentColorHex = root.lineColorHex
        }

        if (root.historySecondary && root.historySecondary.length > 0) {
            currentSecondaryStr = root.historySecondary[root.historySecondary.length - 1].toFixed(1) + root.unit
        } else {
            currentSecondaryStr = "--"
        }
    }

    onTickChanged: {
        updateCurrentValues()
        canvas.requestPaint()
    }

    Modules.BevelPanel {
        id: panel
        width: root.panelWidth
        height: content.implicitHeight + 20

        Column {
            id: content
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            spacing: 8

            // THRESHOLD-COLORED HEADER (CPU/RAM/GPU): title + value
            // on one row, no legend.
            Item {
                width: parent.width
                height: 18
                visible: root.thresholdColored

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title
                    color: "#" + Modules.Theme.colors.coral
                    font.family: Modules.Theme.font.family
                    font.pixelSize: 15
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentValueStr
                    color: "#" + root.currentColorHex
                    font.family: Modules.Theme.font.family
                    font.pixelSize: 15
                }
            }

            // LEGEND HEADER (NET): title row, then per-series rows.
            Text {
                visible: !root.thresholdColored
                text: root.title
                color: "#" + Modules.Theme.colors.coral
                font.family: Modules.Theme.font.family
                font.pixelSize: 15
            }

            Item {
                width: parent.width
                height: 14
                visible: !root.thresholdColored

                Rectangle {
                    id: primarySwatch
                    width: 10
                    height: 10
                    color: "#" + root.lineColorHex
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: primarySwatch.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.primaryLabel !== "" ? root.primaryLabel : root.title
                    color: "#" + Modules.Theme.colors.fg_dim
                    font.family: Modules.Theme.font.family
                    font.pixelSize: 12
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentValueStr
                    color: "#" + root.lineColorHex
                    font.family: Modules.Theme.font.family
                    font.pixelSize: 12
                }
            }

            Item {
                width: parent.width
                height: 14
                visible: !root.thresholdColored && root.historySecondary !== null

                Rectangle {
                    id: secondarySwatch
                    width: 10
                    height: 10
                    color: "#" + root.lineColorSecondaryHex
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: secondarySwatch.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.secondaryLabel
                    color: "#" + Modules.Theme.colors.fg_dim
                    font.family: Modules.Theme.font.family
                    font.pixelSize: 12
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentSecondaryStr
                    color: "#" + root.lineColorSecondaryHex
                    font.family: Modules.Theme.font.family
                    font.pixelSize: 12
                }
            }

            Modules.BevelPanel {
                sunken: true
                width: parent.width
                height: root.graphAreaHeight

                Canvas {
                    id: canvas
                    anchors.fill: parent
                    anchors.margins: 4

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        const hist = root.history
                        const hist2 = root.historySecondary

                        // 4 horizontal lines at 20/40/60/80% of height,
                        // regardless of data scale, purely dividing
                        // the drawing area into 5 even bands.
                        ctx.strokeStyle = "#555880"
                        ctx.lineWidth = 1
                        for (let pct = 20; pct <= 80; pct += 20) {
                            const y = Math.round(height * (1 - pct / 100)) + 0.5
                            ctx.beginPath()
                            ctx.moveTo(0, y)
                            ctx.lineTo(width, y)
                            ctx.stroke()
                        }

                        // 3 vertical lines dividing width into 4 bands
                        for (let i = 1; i <= 3; i++) {
                            const x = Math.round((width / 4) * i) + 0.5
                            ctx.beginPath()
                            ctx.moveTo(x, 0)
                            ctx.lineTo(x, height)
                            ctx.stroke()
                        }

                        if (hist.length < 2) return

                        let lo = root.minValue
                        let hi = root.maxValue
                        if (root.autoScale) {
                            let observedMax = 10
                            for (let i = 0; i < hist.length; i++) observedMax = Math.max(observedMax, hist[i])
                            if (hist2) for (let i = 0; i < hist2.length; i++) observedMax = Math.max(observedMax, hist2[i])
                            lo = 0
                            hi = observedMax
                        }
                        const range = (hi - lo) || 1

                        const stepX = width / (root.historyCapacity - 1)

                        function hexToRgba(hex, alpha) {
                            const r = parseInt(hex.substr(0, 2), 16)
                            const g = parseInt(hex.substr(2, 2), 16)
                            const b = parseInt(hex.substr(4, 2), 16)
                            return "rgba(" + r + "," + g + "," + b + "," + alpha + ")"
                        }

                        // invert flips the vertical mapping: normal
                        // series draw 0 at the bottom / max at the
                        // top, inverted series draw 0 at the top /
                        // max at the bottom (used for NET's upload
                        // line). perPointColorFn, if given, recolors
                        // each segment by the value AT THAT POINT
                        // (the multicolored trail), not the current
                        // value, one stroke+fill call per segment
                        // instead of one for the whole series.
                        function drawSeries(series, colorHex, invert, fillAlpha, perPointColorFn) {
                            const offset = root.historyCapacity - series.length
                            const points = []
                            const colors = []
                            for (let i = 0; i < series.length; i++) {
                                const x = (offset + i) * stepX
                                const v = Math.max(lo, Math.min(hi, series[i]))
                                const frac = (v - lo) / range
                                const y = invert ? (frac * height) : (height - frac * height)
                                points.push([x, y])
                                colors.push(perPointColorFn ? perPointColorFn(series[i]) : colorHex)
                            }

                            if (points.length < 2) return

                            const baselineY = invert ? 0 : height

                            if (fillAlpha > 0) {
                                for (let i = 1; i < points.length; i++) {
                                    ctx.beginPath()
                                    ctx.moveTo(points[i - 1][0], baselineY)
                                    ctx.lineTo(points[i - 1][0], points[i - 1][1])
                                    ctx.lineTo(points[i][0], points[i - 1][1])
                                    ctx.lineTo(points[i][0], points[i][1])
                                    ctx.lineTo(points[i][0], baselineY)
                                    ctx.closePath()
                                    ctx.fillStyle = hexToRgba(colors[i], fillAlpha)
                                    ctx.fill()
                                }
                            }

                            for (let i = 1; i < points.length; i++) {
                                ctx.strokeStyle = "#" + colors[i]
                                ctx.lineWidth = 2
                                ctx.beginPath()
                                ctx.moveTo(points[i - 1][0], points[i - 1][1])
                                ctx.lineTo(points[i][0], points[i - 1][1])
                                ctx.lineTo(points[i][0], points[i][1])
                                ctx.stroke()
                            }
                        }

                        drawSeries(hist, root.currentColorHex, false, root.seriesFillAlpha,
                            root.thresholdColored ? (v => root.thresholdColor(v)) : null)
                        if (hist2 && hist2.length >= 2) drawSeries(hist2, root.lineColorSecondaryHex, root.secondaryInverted, root.seriesFillAlpha, null)
                    }
                }
            }

            Column {
                id: extraColumn
                width: parent.width
                spacing: 5
            }
        }
    }
}
