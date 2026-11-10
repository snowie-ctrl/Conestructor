import QtQuick 2.15
import QtQuick.Shapes

import Conestructor
import "ConeUtils.js" as ConeUtils

Element {
    id: root
    property int trackWidth:    30
    property int length:        150

    shapeName: "Straight"
    shapeColor: "#b603fc"
    shape: straightShape
    hasGates: true
    shapeEditableProperties: [
        "trackWidth",
        "length"
    ]

    width: length
    height: trackWidth

    // Path runs from (0, height/2) to (length, height/2); gates are
    // center-relative, matching the convention getGateGlobalPosition expects.
    gateA: Qt.point(0 - width / 2, height / 2 - height / 2)
    gateB: Qt.point(length - width / 2, height / 2 - height / 2)
    gateAHeading: 180
    gateBHeading: 0

    Shape {
        id: straightShape
        anchors.fill: parent
        ShapePath {
            strokeColor: root.shapeColor
            strokeWidth: root.trackWidth
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            startX: 0
            startY: root.height / 2
            PathLine {
                x: root.length
                y: root.height / 2
            }
        }
    }


    function getConePlacements(pixelsPerFoot) {
        var minSpacingFt = 8 * 3.28084
        var maxSpacingFt = 10 * 3.28084

        return ConeUtils.straightConeSegment(
            -root.length / 2, 0, 0, root.length,
            root.trackWidth / 2, pixelsPerFoot, minSpacingFt, maxSpacingFt
        )
    }
}
