import QtQuick 2.15
import QtQuick.Shapes


Element {
    id: root

    property color dotColor: "#FF0000"
    property int dotRadius: 4
    property double elementOpacity: 1.0


    property url imageSource: ""
    property real imageWidth: 200
    property real imageHeight: 200


    hasGate: false
    hitShape: dotShape
    shapeName: "target"

    width: imageWidth
    height: imageHeight
    opacity: elementOpacity


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
        color: root.dotColor
        anchors.centerIn: parent
    }
}
