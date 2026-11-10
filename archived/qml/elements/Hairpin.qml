import QtQuick 2.15
import QtQuick.Shapes


Element {
    id: root


    // ================================================================
    // EDITABLE PROPERTIES
    // ================================================================

    property string radiusType:
        "constant"


    property int leadInLength:
        50


    property int leadOutLength:
        50


    property int primaryRadius:
        15


    property int secondaryRadius:
        0


    property int degreesOfTurn:
        180


    property string turnDirection:
        "left"


    property int trackWidth:
        30


    // ================================================================
    // INTERNAL PROPERTIES
    // ================================================================

    property color shapeColor:
        "#34eb7a"


    property int samplesPerDegree:
        3


    property point pathStartPoint:
        Qt.point(0, 0)


    // ================================================================
    // ELEMENT CONTRACT
    // ================================================================

    shapeName:
        "hairpin"


    hasGate:
        true


    hitShape:
        hairpinShape


    entryGateHeading:
        rotation


    exitGateHeading:
        -rotation


    // ================================================================
    // SHAPE
    // ================================================================

    Shape {
        id: hairpinShape


        anchors.fill:
            parent


        ShapePath {


            strokeWidth:
                root.trackWidth


            strokeColor:
                root.shapeColor


            fillColor:
                "transparent"


            capStyle:
                ShapePath.FlatCap


            startX:
                root.pathStartPoint.x


            startY:
                root.pathStartPoint.y


            PathPolyline {
                id: polyline
            }
        }
    }


    // ================================================================
    // PROPERTY EXPORT
    // ================================================================

    function getEditableProperties() {


        var properties =
            root.getBaseEditableProperties()


        properties["radiusType"] =
            root.radiusType


        properties["leadInLength"] =
            root.leadInLength


        properties["leadOutLength"] =
            root.leadOutLength


        properties["primaryRadius"] =
            root.primaryRadius


        properties["secondaryRadius"] =
            root.secondaryRadius


        properties["degreesOfTurn"] =
            root.degreesOfTurn


        properties["turnDirection"] =
            root.turnDirection


        properties["trackWidth"] =
            root.trackWidth


        return properties
    }


    // ================================================================
    // REBUILD TRIGGERS
    // ================================================================

    Component.onCompleted:
        rebuildPath()


    onRadiusTypeChanged:
        rebuildPath()


    onLeadInLengthChanged:
        rebuildPath()


    onLeadOutLengthChanged:
        rebuildPath()


    onPrimaryRadiusChanged:
        rebuildPath()


    onSecondaryRadiusChanged:
        rebuildPath()


    onDegreesOfTurnChanged:
        rebuildPath()


    onTurnDirectionChanged:
        rebuildPath()


    onTrackWidthChanged:
        rebuildPath()


    // ================================================================
    // RADIUS
    // ================================================================

    function radiusAtTheta(
        thetaDeg
    ) {


        if (
            root.radiusType ===
            "constant" ||

            root.degreesOfTurn ===
            0
        ) {

            return root.primaryRadius
        }


        var t =
            thetaDeg /
            root.degreesOfTurn


        return root.primaryRadius +
            (
                root.secondaryRadius -
                root.primaryRadius
            ) *
            t
    }


    // ================================================================
    // PATH REBUILD
    // ================================================================

    function rebuildPath() {


        if (
            root.degreesOfTurn >
            180
        ) {


            console.warn(
                "Hairpin degreesOfTurn should not exceed 180"
            )
        }


        var pts =
            []


        var x =
            0


        var y =
            0


        var heading =
            0


        pts.push(
            Qt.point(
                x,
                y
            )
        )


        x +=
            root.leadInLength


        pts.push(
            Qt.point(
                x,
                y
            )
        )


        var turnSign =
            root.turnDirection ===
            "left"
            ? 1
            : -1


        var steps =
            Math.max(
                6,

                Math.round(
                    Math.abs(
                        root.degreesOfTurn
                    ) *
                    root.samplesPerDegree /
                    10
                )
            )


        var dThetaDeg =
            root.degreesOfTurn /
            steps


        for (
            var i = 0;
            i < steps;
            i++
        ) {


            var thetaMid =
                (
                    i +
                    0.5
                ) *
                dThetaDeg


            var r =
                root.radiusAtTheta(
                    thetaMid
                )


            var dThetaRad =
                dThetaDeg *
                Math.PI /
                180


            var ds =
                r *
                dThetaRad


            var headingRad =
                heading *
                Math.PI /
                180


            x +=
                ds *
                Math.cos(
                    headingRad
                )


            y +=
                ds *
                Math.sin(
                    headingRad
                )


            heading +=
                turnSign *
                dThetaDeg


            pts.push(
                Qt.point(
                    x,
                    y
                )
            )
        }


        var headingRad2 =
            heading *
            Math.PI /
            180


        x +=
            root.leadOutLength *
            Math.cos(
                headingRad2
            )


        y +=
            root.leadOutLength *
            Math.sin(
                headingRad2
            )


        pts.push(
            Qt.point(
                x,
                y
            )
        )


        // ------------------------------------------------------------
        // BOUNDING BOX
        // ------------------------------------------------------------

        var minX =
            pts[0].x


        var maxX =
            pts[0].x


        var minY =
            pts[0].y


        var maxY =
            pts[0].y


        for (
            var p = 0;
            p < pts.length;
            p++
        ) {


            minX =
                Math.min(
                    minX,
                    pts[p].x
                )


            maxX =
                Math.max(
                    maxX,
                    pts[p].x
                )


            minY =
                Math.min(
                    minY,
                    pts[p].y
                )


            maxY =
                Math.max(
                    maxY,
                    pts[p].y
                )
        }


        var pad =
            root.trackWidth /
            2


        minX -=
            pad


        maxX +=
            pad


        minY -=
            pad


        maxY +=
            pad


        root.width =
            maxX -
            minX


        root.height =
            maxY -
            minY


        var normalized =
            []


        for (
            var q = 0;
            q < pts.length;
            q++
        ) {


            normalized.push(
                Qt.point(
                    pts[q].x -
                    minX,

                    pts[q].y -
                    minY
                )
            )
        }


        root.pathStartPoint =
            normalized[0]


        root.entryLocal =
            Qt.point(
                normalized[0].x -
                root.width / 2,

                normalized[0].y -
                root.height / 2
            )


        root.exitLocal =
            Qt.point(
                normalized[
                    normalized.length - 1
                ].x -
                root.width / 2,

                normalized[
                    normalized.length - 1
                ].y -
                root.height / 2
            )


        root.exitGateHeading =
            heading


        polyline.path =
            normalized
    }


    function applyShapeProperties(
        properties
    ) {


        if (
            properties.hasOwnProperty(
                "radiusType"
            )
        ) {

            root.radiusType =
                properties.radiusType
        }


        if (
            properties.hasOwnProperty(
                "leadInLength"
            )
        ) {

            root.leadInLength =
                Number(
                    properties.leadInLength
                )
        }


        if (
            properties.hasOwnProperty(
                "leadOutLength"
            )
        ) {

            root.leadOutLength =
                Number(
                    properties.leadOutLength
                )
        }


        if (
            properties.hasOwnProperty(
                "primaryRadius"
            )
        ) {

            root.primaryRadius =
                Number(
                    properties.primaryRadius
                )
        }


        if (
            properties.hasOwnProperty(
                "secondaryRadius"
            )
        ) {

            root.secondaryRadius =
                Number(
                    properties.secondaryRadius
                )
        }


        if (
            properties.hasOwnProperty(
                "degreesOfTurn"
            )
        ) {

            root.degreesOfTurn =
                Number(
                    properties.degreesOfTurn
                )
        }


        if (
            properties.hasOwnProperty(
                "turnDirection"
            )
        ) {

            root.turnDirection =
                properties.turnDirection
        }


        if (
            properties.hasOwnProperty(
                "trackWidth"
            )
        ) {

            root.trackWidth =
                Number(
                    properties.trackWidth
                )
        }
    }
}
