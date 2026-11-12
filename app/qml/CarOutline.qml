import QtQuick
import QtQuick.Shapes
import Conestructor

// The true-size car outline (Tools › Car outline): a white rectangle with a triangle at the front, the top-down car
// picture from Preferences inside it (its top is the car's front), and a rotate handle past the nose. In photo pixels,
// under the canvas's zoom. CanvasView handles every press on it.
Item {
    id: outline
    objectName: "carOutline"
    required property CanvasView canvas

    readonly property var car: canvas.car
    readonly property real mpp: TrackStore.mpp
    readonly property real lengthPx: mpp > 0 ? Settings.carLength / mpp : 0
    readonly property real widthPx: mpp > 0 ? Settings.carWidth / mpp : 0

    visible: canvas.carShown && car !== null && mpp > 0
    x: car && mpp > 0 ? car.x / mpp : 0
    y: car && mpp > 0 ? car.y / mpp : 0
    rotation: car ? car.rotation : 0

    Item {
        x: -outline.lengthPx / 2
        y: -outline.widthPx / 2
        width: outline.lengthPx
        height: outline.widthPx

        Image {
            objectName: "carImage"
            visible: Settings.carImage !== "" && status === Image.Ready
            // Turned a quarter clockwise so the picture's top points along the car's front (+x).
            anchors.centerIn: parent
            width: parent.height
            height: parent.width
            rotation: 90
            source: Settings.carImage !== "" ? TrackFile.fileUrl(Settings.carImage) : ""
            fillMode: Image.Stretch
            asynchronous: true
            smooth: true
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#ffffff"
            border.width: 2 / outline.canvas.zoom
        }
        Shape {
            id: nose
            readonly property real size: Math.min(outline.lengthPx, outline.widthPx) / 3
            ShapePath {
                fillColor: "#ffffff"
                strokeColor: "transparent"
                startX: outline.lengthPx - nose.size
                startY: outline.widthPx / 2 - nose.size / 2
                PathLine { x: outline.lengthPx; y: outline.widthPx / 2 }
                PathLine { x: outline.lengthPx - nose.size; y: outline.widthPx / 2 + nose.size / 2 }
                PathLine { x: outline.lengthPx - nose.size; y: outline.widthPx / 2 - nose.size / 2 }
            }
        }
    }
    Rectangle {
        width: 12 / outline.canvas.zoom
        height: width
        radius: width / 2
        x: outline.lengthPx / 2 + 24 / outline.canvas.zoom - width / 2
        y: -height / 2
        color: "#ffffff"
        border.color: "#202020"
        border.width: 1 / outline.canvas.zoom
    }
}
