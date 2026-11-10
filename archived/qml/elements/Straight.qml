import QtQuick 2.15
import QtQuick.Shapes


Element {
    id: root

    property int trackWidth:        30
    property int length:            150


    property color shapeColor: "#b603fc"
    shapeName: "straight"
    hasGate: true
    hitShape: straightShape
    entryGateHeading: rotation // colinear
    exitGateHeading: rotation // colinear


    width: length
    height: trackWidth


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
}
