import QtQuick 2.15
import QtQuick.Shapes

import Conestructor
import "ConeUtils.js" as ConeUtils


Element {
    id: root

    property int leadInLength:          50
    property int leadOutLength:         50
    property int leadWidthOffset:       45
    property int leadHeightOffset:      30
    property int trackWidth:            30
    property string turnDirection:      "left"

    shapeName: "Chicane"
    shapeColor: "#1a46c9"
    shape: chicaneShape
    hasGates: true
    shapeEditableProperties: [
        "leadInLength", "leadOutLength", "leadWidthOffset",
        "leadHeightOffset", "trackWidth", "turnDirection"
    ]

    readonly property real totalLength: leadInLength + leadWidthOffset + leadOutLength
    width: totalLength
    height: leadHeightOffset + trackWidth

    readonly property bool bendRight: turnDirection !== "left"
    readonly property real drawEntryY: bendRight ? trackWidth / 2 : (leadHeightOffset + trackWidth / 2)
    readonly property real drawExitY: bendRight ? (leadHeightOffset + trackWidth / 2) : trackWidth / 2
    readonly property point drawEntry: Qt.point(0, drawEntryY)
    readonly property point drawExit: Qt.point(totalLength, drawExitY)

    // Gates are now plain bindings — always correct, no signal-ordering risk.
    gateA: Qt.point(drawEntry.x - width / 2, drawEntry.y - height / 2)
    gateB: Qt.point(drawExit.x - width / 2, drawExit.y - height / 2)
    gateAHeading: 180
    gateBHeading: 0

    Shape {
        id: chicaneShape
        anchors.fill: parent
        ShapePath {
            strokeWidth: root.trackWidth
            strokeColor: root.shapeColor
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            startX: root.drawEntry.x
            startY: root.drawEntry.y
            PathLine { x: root.leadInLength; y: root.drawEntry.y }
            PathCubic {
                x: root.leadInLength + root.leadWidthOffset
                y: root.drawExit.y
                control1X: root.leadInLength + root.leadWidthOffset / 2
                control1Y: root.drawEntry.y
                control2X: root.leadInLength + root.leadWidthOffset / 2
                control2Y: root.drawExit.y
            }
            PathLine { x: root.drawExit.x; y: root.drawExit.y }
        }
    }


    function getConePlacements(pixelsPerFoot) {
        var leadMinSpacingFt = 8 * 3.28084
        var leadMaxSpacingFt = 10 * 3.28084
        var leaningMinSpacingFt = 3
        var leaningMaxSpacingFt = 6
        var halfWidth = root.trackWidth / 2

        var cones = []

        cones = cones.concat(ConeUtils.straightConeSegment(
            0 - root.width / 2, root.drawEntry.y - root.height / 2, 0, root.leadInLength,
            halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
        ))

        var p0 = Qt.point(root.leadInLength, root.drawEntry.y)
        var c1 = Qt.point(root.leadInLength + root.leadWidthOffset / 2, root.drawEntry.y)
        var c2 = Qt.point(root.leadInLength + root.leadWidthOffset / 2, root.drawExit.y)
        var p3 = Qt.point(root.leadInLength + root.leadWidthOffset, root.drawExit.y)

        function bezierPoint(t) {
            var mt = 1 - t
            return Qt.point(
                mt*mt*mt*p0.x + 3*mt*mt*t*c1.x + 3*mt*t*t*c2.x + t*t*t*p3.x,
                mt*mt*mt*p0.y + 3*mt*mt*t*c1.y + 3*mt*t*t*c2.y + t*t*t*p3.y
            )
        }

        function bezierTangentDeg(t) {
            var mt = 1 - t
            var dx = 3*mt*mt*(c1.x-p0.x) + 6*mt*t*(c2.x-c1.x) + 3*t*t*(p3.x-c2.x)
            var dy = 3*mt*mt*(c1.y-p0.y) + 6*mt*t*(c2.y-c1.y) + 3*t*t*(p3.y-c2.y)
            return Math.atan2(dy, dx) * 180 / Math.PI
        }

        var sampleCount = 60
        var curvePoints = []
        for (var i = 0; i <= sampleCount; i++) {
            var t = i / sampleCount
            var pt = bezierPoint(t)
            curvePoints.push({
                x: pt.x - root.width / 2,
                y: pt.y - root.height / 2,
                heading: bezierTangentDeg(t)
            })
        }

        // FIXED: interior S-curve cones pushed BEFORE the exit lead
        var interior = ConeUtils.sampleInteriorByArcLength(curvePoints, leaningMinSpacingFt, leaningMaxSpacingFt, pixelsPerFoot)
        var bendSign = root.bendRight ? -1 : 1

        for (var j = 0; j < interior.length; j++) {
            var p = interior[j]
            var side = (p.arcFraction < 0.5) ? bendSign : -bendSign

            var headingRad = p.heading * Math.PI / 180
            var outsideAngleRad = headingRad + (90 * side) * Math.PI / 180

            var coneX = p.x + Math.cos(outsideAngleRad) * halfWidth
            var coneY = p.y + Math.sin(outsideAngleRad) * halfWidth
            var coneHeadingDeg = p.heading

            cones.push({ x: coneX, y: coneY, heading: coneHeadingDeg, coneType: "leaning" })
        }

        cones = cones.concat(ConeUtils.straightConeSegment(
            root.leadInLength + root.leadWidthOffset - root.width / 2, root.drawExit.y - root.height / 2, 0, root.leadOutLength,
            halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
        ))

        return cones
    }
}
