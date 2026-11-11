import QtQuick
import QtQuick.Shapes
import Conestructor

// Origin and Direction in photo pixels: a crosshair each, and with both placed a dashed arrow from Origin through
// Direction. Their names and the distance between them are drawn by CanvasView in screen pixels.
Item {
    id: view
    property real zoom: 1

    readonly property var origin: TrackStore.track.targets.origin
    readonly property var direction: TrackStore.track.targets.direction
    readonly property bool both: origin !== null && direction !== null
    readonly property real length: both ? Math.hypot(direction.x - origin.x, direction.y - origin.y) : 0
    readonly property real ux: length > 0 ? (direction.x - origin.x) / length : 1
    readonly property real uy: length > 0 ? (direction.y - origin.y) / length : 0
    readonly property var tip: both ? Qt.point(direction.x + ux * 40 / zoom, direction.y + uy * 40 / zoom) : Qt.point(0, 0)

    Shape {
        visible: view.both && view.length > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#00ffff"
            strokeWidth: 1.5 / view.zoom
            strokeStyle: ShapePath.DashLine
            dashPattern: [6, 4]
            fillColor: "transparent"
            startX: view.origin ? view.origin.x : 0
            startY: view.origin ? view.origin.y : 0
            PathLine { x: view.tip.x; y: view.tip.y }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: "#00ffff"
            startX: view.tip.x
            startY: view.tip.y
            PathLine { x: view.tip.x - view.ux * 12 / view.zoom - view.uy * 6 / view.zoom; y: view.tip.y - view.uy * 12 / view.zoom + view.ux * 6 / view.zoom }
            PathLine { x: view.tip.x - view.ux * 12 / view.zoom + view.uy * 6 / view.zoom; y: view.tip.y - view.uy * 12 / view.zoom - view.ux * 6 / view.zoom }
            PathLine { x: view.tip.x; y: view.tip.y }
        }
    }

    Repeater {
        model: ["origin", "direction"]
        Item {
            required property string modelData
            readonly property var at: TrackStore.track.targets[modelData]
            readonly property bool selected: TrackStore.selectedId === modelData
            visible: at !== null
            x: at ? at.x : 0
            y: at ? at.y : 0

            Image {
                source: "qrc:/qt/qml/Conestructor/assets/images/crosshair.svg"
                width: 32 / view.zoom
                height: width
                x: -width / 2
                y: -height / 2
                sourceSize: Qt.size(64, 64)
            }
            Rectangle {
                width: (parent.selected ? 9 : 6) / view.zoom
                height: width
                radius: width / 2
                x: -width / 2
                y: -height / 2
                color: parent.selected ? "#ffffff" : "#00ffff"
            }
        }
    }
}
