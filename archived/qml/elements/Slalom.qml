import QtQuick 2.15
import QtQuick.Shapes


Element {
    id: root

    property int leadInLength:          50
    property int leadOutLength:         50
    property int numSlaloms:            3
    property string initialDirection:   "left" // "left" or "right"
    property int apexOffset:            40
    property int slalomOffset:          40
    property int trackWidth:            30


    property color shapeColor: "#c9691a"
    shapeName: "slalom"
    entryGateHeading: rotation  // colinear with each other
    exitGateHeading: rotation   // colinear with each other
    hasGate: true
    hitShape: slalomShape


    readonly property real totalLength: leadInLength + (numSlaloms + 1) * slalomOffset + leadOutLength
    readonly property real centerY: apexOffset + trackWidth / 2
    width: totalLength
    height: 2 * apexOffset + trackWidth

    property int samplesPerSegment: 16 // Shape smoothness

    Shape {
        id: slalomShape
        anchors.fill: parent

        ShapePath {
            id: path
            strokeWidth: root.trackWidth
            strokeColor: root.shapeColor
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            startX: 0
            startY: root.centerY

            PathPolyline { id: polyline } // built dynamically in function below
        }
    }

    Component.onCompleted: rebuildPath()
    onNumSlalomsChanged: rebuildPath()
    onSlalomOffsetChanged: rebuildPath()
    onApexOffsetChanged: rebuildPath()
    onInitialDirectionChanged: rebuildPath()
    onLeadInLengthChanged: rebuildPath()
    onLeadOutLengthChanged: rebuildPath()
    onTrackWidthChanged: rebuildPath()


    function rebuildPath() { // builds shape dynamically
        var keypoints = [
            { x: 0, y: centerY },
            { x: leadInLength, y: centerY }
        ]

        var sign = (initialDirection === "left") ? -1 : 1
        for (var i = 0; i < numSlaloms; i++) {
            keypoints.push({
                x: leadInLength + (i + 1) * slalomOffset,
                y: centerY + sign * apexOffset
            })
            sign = -sign
        }

        var slalomEndX = leadInLength + (numSlaloms + 1) * slalomOffset
        keypoints.push({ x: slalomEndX, y: centerY })
        keypoints.push({ x: totalLength, y: centerY })

        var points = []
        for (var k = 1; k < keypoints.length; k++) {
            var a = keypoints[k - 1]
            var b = keypoints[k]
            var startSample = (k === 1) ? 0 : 1   // skip duplicate point at each join

            for (var s = startSample; s <= samplesPerSegment; s++) {
                var t = s / samplesPerSegment
                var ease = (1 - Math.cos(Math.PI * t)) / 2   // raised-cosine: zero slope at t=0 and t=1
                points.push(Qt.point(
                    a.x + (b.x - a.x) * t,
                    a.y + (b.y - a.y) * ease
                ))
            }
        }

        polyline.path = points
    }
}
