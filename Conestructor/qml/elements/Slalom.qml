import QtQuick 2.15
import QtQuick.Shapes

import Conestructor
import "ConeUtils.js" as ConeUtils


Element {
    id: root
    property int leadInLength:          50
    property int leadOutLength:         50
    property int numSlaloms:            3
    property string initialDirection:   "left"
    property int apexOffset:            40
    property int slalomOffset:          40
    property int trackWidth:            30

    shapeName: "Slalom"
    shapeColor: "#c9691a"
    shape: slalomShape
    hasGates: true
    shapeEditableProperties: [
        "leadInLength", "leadOutLength", "numSlaloms",
        "initialDirection", "apexOffset", "slalomOffset", "trackWidth"
    ]

    readonly property real totalLength: leadInLength + (numSlaloms + 1) * slalomOffset + leadOutLength
    readonly property real centerY: apexOffset + trackWidth / 2
    width: totalLength
    height: 2 * apexOffset + trackWidth

    readonly property int samplesPerSegment: 16

    gateA: Qt.point(0 - width / 2, centerY - height / 2)
    gateB: Qt.point(totalLength - width / 2, centerY - height / 2)
    gateAHeading: 180
    gateBHeading: 0

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
            PathPolyline { id: polyline }
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

    function rebuildPath() {
        // Computed locally from raw leaf properties — NOT read from
        // root.totalLength / root.centerY, since those bindings may not
        // have caught up yet if this function was triggered by a change
        // to one of their own dependencies (leadOutLength, numSlaloms, etc).
        var totalLen = leadInLength + (numSlaloms + 1) * slalomOffset + leadOutLength
        var centerYLocal = apexOffset + trackWidth / 2

        var keypoints = [
            { x: 0, y: centerYLocal },
            { x: leadInLength, y: centerYLocal }
        ]
        var sign = (initialDirection === "left") ? -1 : 1
        for (var i = 0; i < numSlaloms; i++) {
            keypoints.push({
                x: leadInLength + (i + 1) * slalomOffset,
                y: centerYLocal + sign * (apexOffset + (trackWidth/2))
            })
            sign = -sign
        }
        var slalomEndX = leadInLength + (numSlaloms + 1) * slalomOffset
        keypoints.push({ x: slalomEndX, y: centerYLocal })
        keypoints.push({ x: totalLen, y: centerYLocal })   // fixed: local var, not root.totalLength

        var points = []
        for (var k = 1; k < keypoints.length; k++) {
            var a = keypoints[k - 1]
            var b = keypoints[k]
            var startSample = (k === 1) ? 0 : 1
            for (var s = startSample; s <= samplesPerSegment; s++) {
                var t = s / samplesPerSegment
                var ease = (1 - Math.cos(Math.PI * t)) / 2
                points.push(Qt.point(
                    a.x + (b.x - a.x) * t,
                    a.y + (b.y - a.y) * ease
                ))
            }
        }
        polyline.path = points
    }


    function getConePlacements(pixelsPerFoot) {
        var leadMinSpacingFt = 8 * 3.28084
        var leadMaxSpacingFt = 10 * 3.28084

        // Distance from apex to leaning cone's center, such that the leaning
        // cone's tip (far end, 18" long) just touches the standing cone's edge
        // (10.5" wide): half-standing-width + half-leaning-length.
        var leaningOffsetFt = (10.5 / 2 + 18 / 2) / 12   // (5.25" + 9") / 12 = 1.1875 ft
        var leaningOffsetPx = leaningOffsetFt * pixelsPerFoot
        var halfWidth = trackWidth / 2

        var cones = []

        cones = cones.concat(ConeUtils.straightConeSegment(
            -width / 2, 0, 0, leadInLength,
            halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
        ))

        var sign = (initialDirection === "left") ? -1 : 1
        for (var i = 0; i < numSlaloms; i++) {
            var apexX = leadInLength + (i + 1) * slalomOffset - width / 2

            // FIXED: apexOffset is a direct centerline distance, no trackWidth
            // subtraction — apexOffset = 0 now correctly puts the apex on centerline.
            var apexY = sign * apexOffset

            var leanY = apexY + sign * leaningOffsetPx

            cones.push({ x: apexX, y: apexY, heading: 0, coneType: "standing" })

            var headingDeg = Math.atan2(-sign, 0) * 180 / Math.PI
            cones.push({ x: apexX, y: leanY, heading: headingDeg, coneType: "leaning" })

            sign = -sign
        }

        var slalomEndLocalX = leadInLength + (numSlaloms + 1) * slalomOffset - width / 2
        cones = cones.concat(ConeUtils.straightConeSegment(
            slalomEndLocalX, 0, 0, leadOutLength,
            halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
        ))

        return cones
    }
}
