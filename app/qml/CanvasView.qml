import QtQuick
import QtQuick.Controls
import Conestructor
import "logic/viewport.mjs" as Viewport

// The canvas: the lot photo with the track over it, under one zoom and pan. World coordinates are photo pixels;
// elements are stored in metres and drawn at metres ÷ metresPerPixel. All pointer input is handled here in one
// place, so redrawing an element never interrupts a drag. Window size changes what is visible, never the scale.
Item {
    id: canvas
    clip: true
    focus: true

    property real zoom: 1
    property real panX: 0
    property real panY: 0
    readonly property var view: ({ zoom: canvas.zoom, panX: canvas.panX, panY: canvas.panY })
    readonly property real mpp: TrackStore.mpp
    readonly property string blueprint: "qrc:/qt/qml/Conestructor/assets/images/blueprintBackground.png"
    readonly property string photoPath: TrackStore.track.photo.path
    property bool fitPending: true
    property bool spaceHeld: false
    property var hover: null          // the photo pixel under the cursor, or null

    property string mode: ""          // the gesture in progress: "pan" (later tasks add more)
    property var press: null          // where the gesture started and what it started on
    property string gestureKey: ""

    onPhotoPathChanged: fitPending = true
    onWidthChanged: tryFit()
    onHeightChanged: tryFit()

    function toWorld(sx, sy) { return Viewport.toWorld(view, sx, sy) }
    function toScreen(wx, wy) { return Viewport.toScreen(view, wx, wy) }

    function fitToPhoto() {
        const v = Viewport.fit(width, height, photo.implicitWidth, photo.implicitHeight)
        zoom = v.zoom
        panX = v.panX
        panY = v.panY
    }

    function tryFit() {
        if (fitPending && photo.status === Image.Ready && width > 0 && height > 0) {
            fitPending = false
            fitToPhoto()
        }
    }

    function zoomBy(factor, sx, sy) {
        const l = Viewport.limits(Viewport.fit(width, height, photo.implicitWidth, photo.implicitHeight).zoom, mpp)
        const v = Viewport.zoomAt(view, factor, sx, sy, l.min, l.max)
        zoom = v.zoom
        panX = v.panX
        panY = v.panY
    }

    function centreOn(wx, wy) {
        panX = width / 2 - wx * zoom
        panY = height / 2 - wy * zoom
    }

    // "Show me" from the error banner: pan to the thing at fault and select it.
    function showTarget(target) {
        if (!target)
            return
        const t = TrackStore.track
        if (target.kind === "ruler" && t.ruler) {
            centreOn((t.ruler.a.x + t.ruler.b.x) / 2, (t.ruler.a.y + t.ruler.b.y) / 2)
            TrackStore.select("ruler")
        } else if ((target.kind === "origin" || target.kind === "direction") && t.targets[target.kind]) {
            centreOn(t.targets[target.kind].x, t.targets[target.kind].y)
            TrackStore.select(target.kind)
        } else if (target.kind === "element" && mpp > 0) {
            const el = TrackStore.element(target.id)
            if (el) {
                centreOn(el.x / mpp, el.y / mpp)
                TrackStore.select(el.id)
            }
        }
    }

    function pressAt(e) {
        canvas.forceActiveFocus()
        press = { sx: e.x, sy: e.y, panX: panX, panY: panY }
        if (e.button === Qt.MiddleButton || e.button === Qt.LeftButton) {
            if (e.button === Qt.LeftButton && !spaceHeld)
                TrackStore.select("")
            mode = "pan"
        }
    }

    function moveTo(e) {
        hover = toWorld(e.x, e.y)
        if (!mouse.pressed || mode === "")
            return
        if (mode === "pan") {
            panX = press.panX + e.x - press.sx
            panY = press.panY + e.y - press.sy
        }
    }

    function releaseAt(e) {
        if (mode !== "" && mode !== "pan")
            TrackStore.seal()
        mode = ""
        press = null
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Space && !e.isAutoRepeat) {
            spaceHeld = true
            e.accepted = true
        }
    }
    Keys.onReleased: (e) => {
        if (e.key === Qt.Key_Space && !e.isAutoRepeat) {
            spaceHeld = false
            e.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#010426"
    }

    // Everything in photo pixels, under the zoom and pan.
    Item {
        id: world
        x: canvas.panX
        y: canvas.panY
        scale: canvas.zoom
        transformOrigin: Item.TopLeft

        Image {
            id: photo
            source: canvas.photoPath !== "" ? canvas.photoPath : canvas.blueprint
            asynchronous: true
            smooth: true
            mipmap: true
            onStatusChanged: canvas.tryFit()
        }

        Repeater {
            model: TrackStore.elementCount
            ElementView {
                required property int index
                element: TrackStore.track.elements[index] || null
                zoom: canvas.zoom
                selected: element !== null && TrackStore.selectedId === element.id
                dimmed: TrackStore.previewOn
            }
        }
    }

    // Labels drawn in screen pixels, so text stays sharp and the same size at any zoom.
    Item {
        id: overlay
        anchors.fill: parent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: canvas.mode === "pan" ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onPressed: (e) => canvas.pressAt(e)
        onPositionChanged: (e) => canvas.moveTo(e)
        onReleased: (e) => canvas.releaseAt(e)
        onExited: canvas.hover = null
        onWheel: (w) => canvas.zoomBy(Math.pow(1.0015, w.angleDelta.y), w.x, w.y)
    }
}
