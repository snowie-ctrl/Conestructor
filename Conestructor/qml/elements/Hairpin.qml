import QtQuick 2.15
import QtQuick.Shapes

import Conestructor
import "ConeUtils.js" as ConeUtils


Element {
    id: root

    property string radiusType:     "constant"
    property int leadInLength:      50
    property int leadOutLength:     50
    property int primaryRadius:     45
    property int secondaryRadius:   0
    property int degreesOfTurn:     180
    property string turnDirection:  "right"
    property int trackWidth:        30

    shapeName: "Hairpin"
    shapeColor: "#34eb7a"
    shape: hairpinShape
    hasGates: true
    shapeEditableProperties: [
        "radiusType", "leadInLength", "leadOutLength", "primaryRadius",
        "secondaryRadius", "degreesOfTurn", "turnDirection", "trackWidth"
    ]

    readonly property int samplesPerDegree: 3
    property point pathStartPoint: Qt.point(0,0)

    // Heading is a simple closed-form value — safe as a plain binding,
    // no dependency on the sampled path geometry.
    readonly property real finalHeading: (turnDirection === "right" ? 1 : -1) * degreesOfTurn
    gateAHeading: 180
    gateBHeading: root.normalizeAngle(finalHeading)

    Shape {
        id: hairpinShape
        anchors.fill: parent
        ShapePath {
            strokeWidth: root.trackWidth
            strokeColor: root.shapeColor
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            startX: root.pathStartPoint.x
            startY: root.pathStartPoint.y
            PathPolyline { id: polyline }
        }
    }

    Component.onCompleted: rebuildPath()
    onRadiusTypeChanged: rebuildPath()
    onLeadInLengthChanged: rebuildPath()
    onLeadOutLengthChanged: rebuildPath()
    onPrimaryRadiusChanged: rebuildPath()
    onSecondaryRadiusChanged: rebuildPath()
    onDegreesOfTurnChanged: rebuildPath()
    onTurnDirectionChanged: rebuildPath()
    onTrackWidthChanged: rebuildPath()

    function rebuildPath() {
        if (root.degreesOfTurn > 180) {
            console.warn("Hairpin degreesOfTurn should not exceed 180")
            return
        }

        var pts = []
        var x = 0
        var y = 0
        var heading = 0

        pts.push(Qt.point(x,y))

        x += root.leadInLength
        pts.push(Qt.point(x,y))

        var turnSign = root.turnDirection === "right" ? 1 : -1
        var steps = Math.max(6, Math.round(Math.abs(root.degreesOfTurn) * root.samplesPerDegree))
        var dThetaDeg = root.degreesOfTurn / steps

        for (var i = 0; i < steps; i++) {
            var thetaMid = (i + 0.5) * dThetaDeg
            var r = root.radiusAtTheta(thetaMid)
            var dThetaRad = dThetaDeg * Math.PI / 180
            var ds = r * dThetaRad
            var headingRad = heading * Math.PI / 180

            x += ds * Math.cos(headingRad)
            y += ds * Math.sin(headingRad)
            heading += turnSign * dThetaDeg

            pts.push(Qt.point(x,y))
        }

        var headingRad2 = heading * Math.PI / 180
        x += root.leadOutLength * Math.cos(headingRad2)
        y += root.leadOutLength * Math.sin(headingRad2)
        pts.push(Qt.point(x,y))

        var minX = pts[0].x, maxX = pts[0].x
        var minY = pts[0].y, maxY = pts[0].y

        for (var p = 0; p < pts.length; p++) {
            minX = Math.min(minX, pts[p].x)
            maxX = Math.max(maxX, pts[p].x)
            minY = Math.min(minY, pts[p].y)
            maxY = Math.max(maxY, pts[p].y)
        }

        var pad = root.trackWidth / 2
        minX -= pad; maxX += pad
        minY -= pad; maxY += pad

        root.width = maxX - minX
        root.height = maxY - minY

        var normalized = []
        for (var q = 0; q < pts.length; q++) {
            normalized.push(Qt.point(pts[q].x - minX, pts[q].y - minY))
        }

        root.pathStartPoint = normalized[0]
        polyline.path = normalized

        // Gates: computed from the SAME normalized array, in the same
        // synchronous pass as width/height/pathStartPoint above — so
        // there's no cross-binding staleness risk like Chicane had.
        var entryPoint = normalized[0]
        var exitPoint = normalized[normalized.length - 1]

        root.gateA = Qt.point(entryPoint.x - root.width / 2, entryPoint.y - root.height / 2)
        root.gateB = Qt.point(exitPoint.x - root.width / 2, exitPoint.y - root.height / 2)
    }

    function radiusAtTheta(thetaDeg) {
        if (root.radiusType === "constant" || root.degreesOfTurn === 0) return root.primaryRadius
        var t = thetaDeg / root.degreesOfTurn
        return root.primaryRadius + (root.secondaryRadius - root.primaryRadius) * t
    }


    function getConePlacements(pixelsPerFoot) {
        if (root.degreesOfTurn > 180) return []

        var leadMinSpacingFt = 8 * 3.28084
        var leadMaxSpacingFt = 10 * 3.28084
        var turnMinSpacingFt = 5
        var turnMaxSpacingFt = 8
        var halfWidth = root.trackWidth / 2

        var cones = []

        cones = cones.concat(ConeUtils.straightConeSegment(
            root.gateA.x, root.gateA.y, 0, root.leadInLength,
            halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
        ))

        var turnPoints = []
        var x = root.leadInLength
        var y = 0
        var heading = 0
        turnPoints.push({ x: x, y: y, heading: heading })

        var turnSign = root.turnDirection === "right" ? 1 : -1
        var steps = Math.max(6, Math.round(Math.abs(root.degreesOfTurn) * root.samplesPerDegree))
        var dThetaDeg = root.degreesOfTurn / steps

        for (var i = 0; i < steps; i++) {
            var thetaMid = (i + 0.5) * dThetaDeg
            var r = root.radiusAtTheta(thetaMid)
            var dThetaRad = dThetaDeg * Math.PI / 180
            var ds = r * dThetaRad
            var headingRad = heading * Math.PI / 180

            x += ds * Math.cos(headingRad)
            y += ds * Math.sin(headingRad)
            heading += turnSign * dThetaDeg

            turnPoints.push({ x: x, y: y, heading: heading })
        }

        var relPoints = turnPoints.map(function(p) {
            return {
                x: p.x + root.pathStartPoint.x - root.width / 2,
                y: p.y + root.pathStartPoint.y - root.height / 2,
                heading: p.heading
            }
        })

        // FIXED: interior curve cones now pushed BEFORE the exit lead,
        // so the array reads lead-in -> curve -> lead-out (physical order)
        var interior = ConeUtils.sampleInteriorByArcLength(relPoints, turnMinSpacingFt, turnMaxSpacingFt, pixelsPerFoot)

        for (var j = 0; j < interior.length; j++) {
            var pt = interior[j]
            var headingRad2 = pt.heading * Math.PI / 180
            var insideAngleRad = headingRad2 - (-90 * turnSign) * Math.PI / 180

            var coneX = pt.x + Math.cos(insideAngleRad) * halfWidth
            var coneY = pt.y + Math.sin(insideAngleRad) * halfWidth
            var coneHeadingDeg = pt.heading

            cones.push({ x: coneX, y: coneY, heading: coneHeadingDeg, coneType: "leaning" })
        }

        var lastRel = relPoints[relPoints.length - 1]
        var lastRaw = turnPoints[turnPoints.length - 1]
        var exitHeadingRad = lastRaw.heading * Math.PI / 180

        cones = cones.concat(ConeUtils.straightConeSegment(
            lastRel.x, lastRel.y, exitHeadingRad, root.leadOutLength,
            halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
        ))

        return cones
    }
}
