import QtQuick 2.15
import QtQuick.Shapes


Element {
    id: root

    property int leadInLength:          50
    property int leadOutLength:         50
    property int leadWidthOffset:       15 // from closest point of leads
    property int leadHeightOffset:      15 // from centerline of lead
    property int trackWidth:            30
    property string turnDirection:      "left" // "left" or "right"


    property color shapeColor: "#1a46c9"
    shapeName: "chicane"
    entryGateHeading: rotation  // parallel
    exitGateHeading: rotation   // parallel
    hasGate: true
    hitShape: chicaneShape

        // Build element rectangle bounds
    readonly property real totalLength: leadInLength + leadWidthOffset + leadOutLength
    width: totalLength
    height: leadHeightOffset + trackWidth
    readonly property bool bendRight: turnDirection !== "left"
    readonly property real drawEntryY: bendRight ? trackWidth / 2 : (leadHeightOffset + trackWidth / 2)
    readonly property real drawExitY: bendRight ? (leadHeightOffset + trackWidth / 2) : trackWidth / 2

    readonly property point drawEntry: Qt.point(0, drawEntryY)
    readonly property point drawExit: Qt.point(totalLength, drawExitY)


    Shape {
        id: chicaneShape
        anchors.fill: parent

        ShapePath {
            strokeWidth: root.trackWidth
            strokeColor: root.geometryValid ? root.shapeColor : "#D8302F"
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
}
