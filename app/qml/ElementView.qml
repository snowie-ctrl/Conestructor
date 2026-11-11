import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Conestructor
import "logic/elements.mjs" as Elements

// One track element drawn from data, in photo pixels: a translucent band in its colour as wide as the track, a
// dashed centreline, a ring at each open end, a green dot at each joined end, and white arrows along the centreline
// pointing the way it is driven (entry to exit). An element driven against its chain shows a warning sign. Selected: a
// white outline and the rotate handle. Draws only; CanvasView handles every click and drag.
Item {
    id: view

    property var element: null
    property real zoom: 1
    property bool selected: false
    property bool single: true        // the only thing selected: it shows the rotate handle
    property bool dimmed: false
    property bool backwards: false

    readonly property real mpp: TrackStore.mpp
    readonly property bool drawable: element !== null && mpp > 0
    readonly property color colour: element ? Elements.COLOURS[element.type] : "white"
    readonly property var points: drawable ? Elements.pathWorld(element).map(p => Qt.point(p.x / mpp, p.y / mpp)) : []
    readonly property var ends: drawable ? Elements.endsWorld(element) : null
    readonly property var band: {
        if (!drawable)
            return []
        const ring = Elements.bandPolygon(Elements.pathWorld(element), element.props.trackWidth / 2)
                     .map(p => Qt.point(p.x / mpp, p.y / mpp))
        return ring.length > 0 ? ring.concat([ring[0]]) : ring
    }
    readonly property var arrows: drawable ? Elements.arrowMarks(element, 8) : []
    // The middle of the centreline (canvas metres), where the warning sits.
    readonly property var middle: drawable ? Elements.pointsAlong(element, [0.5])[0] : null
    readonly property var handle: drawable && selected && single ? Elements.rotateHandle(element, 24 / zoom * mpp) : null

    visible: drawable
    opacity: dimmed ? 0.3 : 1

    Shape {
        preferredRendererType: Shape.CurveRenderer

        // The band as a filled outline (a thick translucent stroke would darken where its segments overlap).
        ShapePath {
            strokeColor: view.selected ? "#ffffff" : "transparent"
            strokeWidth: 2 / view.zoom
            fillColor: Qt.rgba(view.colour.r, view.colour.g, view.colour.b, 0.45)
            fillRule: ShapePath.WindingFill
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: view.band }
        }
        ShapePath {
            strokeColor: view.colour
            strokeWidth: 1.5 / view.zoom
            strokeStyle: ShapePath.DashLine
            dashPattern: [6, 4]
            fillColor: "transparent"
            PathPolyline { path: view.points }
        }
        ShapePath {
            strokeColor: view.handle ? "#ffffff" : "transparent"
            strokeWidth: 1.5 / view.zoom
            fillColor: "transparent"
            startX: view.drawable ? view.element.x / view.mpp : 0
            startY: view.drawable ? view.element.y / view.mpp : 0
            PathLine {
                x: view.handle ? view.handle.x / view.mpp : 0
                y: view.handle ? view.handle.y / view.mpp : 0
            }
        }
    }

    // Arrows: chevrons a fixed size on screen, pointing along the centreline.
    Repeater {
        model: view.arrows
        Shape {
            required property var modelData
            x: modelData.x / view.mpp
            y: modelData.y / view.mpp
            rotation: modelData.heading
            scale: 1 / view.zoom
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#ffffff"
                strokeWidth: 2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: -4
                startY: -6
                PathLine { x: 4; y: 0 }
                PathLine { x: -4; y: 6 }
            }
        }
    }

    Label {
        visible: view.backwards && view.middle !== null
        text: "⚠"
        color: "#ffb300"
        font.pixelSize: 20
        style: Text.Outline
        styleColor: "#000000"
        scale: 1 / view.zoom
        x: view.middle ? view.middle.x / view.mpp - width / 2 : 0
        y: view.middle ? view.middle.y / view.mpp - height / 2 : 0
    }

    Repeater {
        model: view.drawable ? 2 : 0
        Rectangle {
            required property int index
            readonly property string end: index === 0 ? "A" : "B"
            readonly property bool joined: view.element.joins[end] !== null
            readonly property var at: view.ends[end]
            width: (joined ? 8 : 10) / view.zoom
            height: width
            radius: width / 2
            x: at.x / view.mpp - width / 2
            y: at.y / view.mpp - height / 2
            color: joined ? "#4caf50" : "transparent"
            border.color: joined ? "#4caf50" : "#ffffff"
            border.width: 1.5 / view.zoom
        }
    }

    Rectangle {
        visible: view.handle !== null
        width: 12 / view.zoom
        height: width
        radius: width / 2
        x: view.handle ? view.handle.x / view.mpp - width / 2 : 0
        y: view.handle ? view.handle.y / view.mpp - height / 2 : 0
        color: "#ffffff"
        border.color: "#202020"
        border.width: 1 / view.zoom
    }
}
