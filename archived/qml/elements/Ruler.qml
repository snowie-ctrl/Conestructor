import QtQuick 2.15
import QtQuick.Shapes


Element {
    id: root

    property int length:    150 // in pixels
    property double realWorldLength: 0.0 // in feet


    property color shapeColor: "#f5cb42"
    property string shapeName: "Ruler"


    height: 30      // Standard fixed height
    width: length   // Length of ruler
    hasGate: false
    hitShape: rulerShape

    property double realWorldRatio: length / realWorldLength // pixels per foot


    Shape {
        id: rulerShape
        anchors.fill: parent

        ShapePath {
            strokeColor: root.shapeColor
            fillColor: "transparent"
            strokeWidth: root.height
            capStyle: ShapePath.FlatCap

            startX: 0
            startY: root.height/2
            PathLine {
                x: root.length
                y: root.height/2
            }
        }
    }
}
