import QtQuick
import QtQuick.Shapes
import Conestructor

// Placed cones at true size (10.5 in base; a leaning cone is 18 in long), in photo pixels, and the yellow route line
// through them in driving order. View > Show cones (C) and Show route line (R) toggle each.
Item {
    id: conePreview     // not "layer": inside each cone picture that name means the picture's own layer property
    property real zoom: 1

    readonly property real mpp: TrackStore.mpp
    readonly property var cones: TrackStore.previewOn && TrackStore.preview ? TrackStore.preview.canvasCones : []
    readonly property var routePoints: mpp > 0 ? cones.map(c => Qt.point(c.x / mpp, c.y / mpp)) : []
    readonly property real baseMetres: 10.5 * 0.0254
    readonly property real leaningMetres: 18 * 0.0254

    visible: cones.length > 0 && mpp > 0

    Shape {
        visible: TrackStore.showRoute && conePreview.routePoints.length > 1
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#ffff00"
            strokeWidth: 2 / conePreview.zoom
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: conePreview.routePoints }
        }
    }

    Repeater {
        model: TrackStore.showCones ? conePreview.cones : []
        Image {
            required property var modelData
            readonly property bool leaning: modelData.type === "leaning"
            source: leaning ? "qrc:/qt/qml/Conestructor/assets/images/sideways-cone.png"
                            : "qrc:/qt/qml/Conestructor/assets/images/upright-cone.png"
            width: conePreview.baseMetres / conePreview.mpp
            height: (leaning ? conePreview.leaningMetres : conePreview.baseMetres) / conePreview.mpp
            x: modelData.x / conePreview.mpp - width / 2
            y: modelData.y / conePreview.mpp - height / 2
            rotation: modelData.heading
            sourceSize: Qt.size(64, 64)
            smooth: true
        }
    }
}
