import QtQuick 2.15
import QtQuick.Shapes

import Conestructor


Element {
    id: root

    property int dotRadius          : 5
    property double elementOpacity  : 100.0
    property int referenceIndex     : 0


    shapeName: "Target"
    shapeColor: "#00FFFF"
    shape: dotShape
    hasGates: false
    shapeEditableProperties: [
        "dotRadius",
        "elementOpacity",
        "referenceIndex"
    ]


    property string imageSource: "../../assets/images/crosshair.svg"
    property int imageWidth: 100
    property int imageHeight: 100


    width: imageWidth
    height: imageHeight
    opacity: elementOpacity / 100.0


    Image {
        anchors.fill: parent
        source: root.imageSource
        fillMode: Image.PreserveAspectFit
    }

    Rectangle {
        id: dotShape

        width: root.dotRadius * 2
        height: root.dotRadius * 2
        radius: root.dotRadius
        color: root.shapeColor
        anchors.centerIn: parent
    }
}
