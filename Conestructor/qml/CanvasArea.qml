import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

import Conestructor


Rectangle {
    id: root

    property string imagePath: ""


    property var elements: []
    property int snapRadius: 60 // in px

    property var conePreviewMarkers: []
    property real conePixelsPerFoot: 1
    property bool conesVisible: true
    property bool routeLinesVisible: true

    function showConePreview(markers, pixelsPerFoot) {
        root.conePreviewMarkers = markers
        root.conePixelsPerFoot = pixelsPerFoot

        for (const element of elements) {

            if (element.shapeName !== "Target") // Keep the targets visible
                element.visible = false
        }
    }

    function clearConePreview() {
        root.conePreviewMarkers = []

        for (const element of elements) {
            element.visible = true
        }
    }

    function toggleConeDots() { root.conesVisible = !root.conesVisible }
    function toggleRouteLines() { root.routeLinesVisible = !root.routeLinesVisible }




    color: "#010426"


    Component.onCompleted: {
        AppState.canvasArea = root
    }



    Image {
        id: backgroundImage

        anchors.fill: parent

        z: 0

        source: root.imagePath !== ""
            ? root.imagePath
            : "../assets/images/blueprintBackground.png"
        fillMode: Image.PreserveAspectCrop
        clip: true
    }

    // Route lines — drawn first so dots render on top
    Repeater {
        model: Math.max(0, root.conePreviewMarkers.length - 1)
        visible: root.routeLinesVisible

        Rectangle {
            property var p0: root.conePreviewMarkers[index]
            property var p1: root.conePreviewMarkers[index + 1]
            property real segLength: Math.sqrt(Math.pow(p1.x - p0.x, 2) + Math.pow(p1.y - p0.y, 2))

            width: segLength
            height: 2
            color: "#ffff00"
            x: p0.x
            y: p0.y - height / 2
            transformOrigin: Item.Left
            rotation: Math.atan2(p1.y - p0.y, p1.x - p0.x) * 180 / Math.PI
        }
    }

    // Cone dots
    Repeater {
        model: root.conePreviewMarkers
        visible: root.coneDotsVisible

        Image {
            // Real-world cone dimensions, in inches, converted to pixels via
            // the same pixelsPerFoot ratio the Ruler element establishes.
            readonly property real standingWidthFt: 10.5 / 12
            readonly property real standingHeightFt: 10.5 / 12
            readonly property real leaningWidthFt: 10.5 / 12
            readonly property real leaningHeightFt: 18.0 / 12

            source: modelData.coneType === "leaning"
                ? "../assets/images/sideways-cone.png"
                : "../assets/images/upright-cone.png"

            width: (modelData.coneType === "leaning" ? leaningWidthFt : standingWidthFt) * root.conePixelsPerFoot
            height: (modelData.coneType === "leaning" ? leaningHeightFt : standingHeightFt) * root.conePixelsPerFoot

            x: modelData.x - width / 2
            y: modelData.y - height / 2

            rotation: modelData.heading
            transformOrigin: Item.Center

            sourceSize.width: width
            sourceSize.height: height

            smooth: true
        }
    }


    MouseArea {
        anchors.fill: parent

        onClicked: {
            console.log("Canvas clicked")

            AppState.deselectElements()
        }

    }


    function containsGlobalPoint(point) {
        var topLeft = root.mapToItem(
            Overlay.overlay,
            0,
            0
        )

        return (
            point.x >= topLeft.x &&
            point.x <= topLeft.x + root.width &&

            point.y >= topLeft.y &&
            point.y <= topLeft.y + root.height
        )
    }

    function registerElement(element) {
        if (root.elements.indexOf(element) !== -1) return // Element is already registered with canvas

        root.elements.push(element)
    }

    function unregisterElement(element) {
        var index = root.elements.indexOf(element)

        if (index !== -1) {
            root.elements.splice(index, 1)
        }

        root.elements = root.elements
    }

    function findNearestGate(element) {

        var nearest =
            null


        var nearestDistance =
            root.snapRadius


        for (
            var i = 0;
            i < root.elements.length;
            i++
        ) {

            var other =
                root.elements[i]


            if (
                other === element ||
                !other.hasGates
            ) {
                continue
            }


            var targetGates =
                ["A", "B"]


            for (
                var j = 0;
                j < targetGates.length;
                j++
            ) {

                var targetGate =
                    targetGates[j]


                var targetMate =
                    targetGate === "A"
                    ? other.gateAMate
                    : other.gateBMate


                if (
                    targetMate !== null
                ) {
                    continue
                }


                var targetPosition =
                    other.getGateGlobalPosition(
                        targetGate
                    )


                var draggedGates =
                    ["A", "B"]


                for (
                    var k = 0;
                    k < draggedGates.length;
                    k++
                ) {

                    var draggedGate =
                        draggedGates[k]


                    var draggedPosition =
                        element.getGateGlobalPosition(
                            draggedGate
                        )


                    var dx =
                        draggedPosition.x -
                        targetPosition.x


                    var dy =
                        draggedPosition.y -
                        targetPosition.y


                    var distance =
                        Math.sqrt(
                            dx * dx +
                            dy * dy
                        )


                    if (
                        distance <
                        nearestDistance
                    ) {

                        nearestDistance =
                            distance


                        nearest = {
                            element:
                                other,

                            elementGate:
                                targetGate,

                            draggedElementGate:
                                draggedGate
                        }
                    }
                }
            }
        }


        return nearest
    }

}
