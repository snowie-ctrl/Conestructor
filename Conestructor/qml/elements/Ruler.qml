import QtQuick 2.15
import QtQuick.Shapes

import Conestructor


Element {
    id: root

    property int length:                75 // in pixels     default length for preview
    property double realWorldLength:    0.0 // in feet


    property double realWorldRatio: realWorldLength > 0 // pixels per foot
        ? length / realWorldLength
        : 0.0


    shapeName: "Ruler"
    shapeColor: "#f5cb42"
    shape: rulerShape
    hasGates: false
    shapeEditableProperties: [
        "length",
        "realWorldLength"
    ]

    height: 20 // Standard fixed height of rectangle
    width: length // Width of rectangle drawn (length of ruler)


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
