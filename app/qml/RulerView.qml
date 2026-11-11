import QtQuick
import QtQuick.Shapes
import Conestructor

// The ruler in photo pixels: a line with end ticks and a round handle at each end. Its length label is drawn by
// CanvasView in screen pixels.
Item {
    id: view
    property real zoom: 1

    readonly property var ruler: TrackStore.track.ruler
    readonly property bool selected: TrackStore.selectedId === "ruler"
    readonly property real angle: ruler ? Math.atan2(ruler.b.y - ruler.a.y, ruler.b.x - ruler.a.x) : 0
    readonly property real tickX: -Math.sin(angle) * 8 / zoom
    readonly property real tickY: Math.cos(angle) * 8 / zoom

    visible: ruler !== null

    Shape {
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#f5cb42"
            strokeWidth: (view.selected ? 3 : 2) / view.zoom
            fillColor: "transparent"
            startX: view.ruler ? view.ruler.a.x : 0
            startY: view.ruler ? view.ruler.a.y : 0
            PathLine { x: view.ruler ? view.ruler.b.x : 0; y: view.ruler ? view.ruler.b.y : 0 }
            PathMove { x: view.ruler ? view.ruler.a.x - view.tickX : 0; y: view.ruler ? view.ruler.a.y - view.tickY : 0 }
            PathLine { x: view.ruler ? view.ruler.a.x + view.tickX : 0; y: view.ruler ? view.ruler.a.y + view.tickY : 0 }
            PathMove { x: view.ruler ? view.ruler.b.x - view.tickX : 0; y: view.ruler ? view.ruler.b.y - view.tickY : 0 }
            PathLine { x: view.ruler ? view.ruler.b.x + view.tickX : 0; y: view.ruler ? view.ruler.b.y + view.tickY : 0 }
        }
    }

    Repeater {
        model: view.ruler ? 2 : 0
        Rectangle {
            required property int index
            readonly property var at: index === 0 ? view.ruler.a : view.ruler.b
            width: 12 / view.zoom
            height: width
            radius: width / 2
            x: at.x - width / 2
            y: at.y - height / 2
            color: "#f5cb42"
            border.color: view.selected ? "#ffffff" : "#202020"
            border.width: 1.5 / view.zoom
        }
    }
}
