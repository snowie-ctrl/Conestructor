import QtQuick
import QtQuick.Controls
import Conestructor
import "logic/elements.mjs" as Elements
import "logic/snapping.mjs" as Snapping
import "logic/units.mjs" as Units
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
    property string placingKind: ""   // a palette tile being dragged: a track type, "ruler", "origin" or "direction"
    property var ghost: null          // the track element being placed, as it would land

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

    // Snapping reaches 30 screen pixels, whatever the zoom.
    function snapMetres() {
        return 30 / zoom * mpp
    }

    function distance(a, b) {
        return Math.hypot(a.x - b.x, a.y - b.y)
    }

    // What is under a screen point, most specific first.
    function hitAt(sx, sy) {
        const w = toWorld(sx, sy)
        const reach = 10 / zoom
        const t = TrackStore.track
        if (t.ruler) {
            if (distance(t.ruler.a, w) < reach)
                return { kind: "rulerA" }
            if (distance(t.ruler.b, w) < reach)
                return { kind: "rulerB" }
        }
        for (const which of ["origin", "direction"]) {
            const p = t.targets[which]
            if (p && distance(p, w) < 16 / zoom)
                return { kind: "target", which: which }
        }
        if (t.ruler && Elements.pointSegmentDistance(w, t.ruler.a, t.ruler.b) < 6 / zoom)
            return { kind: "ruler" }
        return null
    }

    function beginPlacing(kind) {
        placingKind = kind
        ghost = null
    }

    function insideCanvas(sx, sy) {
        return sx >= 0 && sy >= 0 && sx <= width && sy <= height
    }

    function updatePlacing(sx, sy, ctrl) {
        if (Elements.TYPES.indexOf(placingKind) < 0 || !insideCanvas(sx, sy) || !(mpp > 0)) {
            ghost = null
            return
        }
        const w = toWorld(sx, sy)
        let g = { id: "ghost", type: placingKind, x: w.x * mpp, y: w.y * mpp, rotation: 0,
                  props: Elements.defaults(placingKind), joins: { A: null, B: null }, snap: null }
        const snap = ctrl ? null : Snapping.findSnap(TrackStore.track.elements, g, snapMetres())
        if (snap) {
            Object.assign(g, Snapping.placeToJoin(g, snap.ownEnd, TrackStore.element(snap.targetId), snap.targetEnd))
            g.snap = { ownEnd: snap.ownEnd, id: snap.targetId, end: snap.targetEnd }
        }
        ghost = g
    }

    function finishPlacing(sx, sy) {
        const kind = placingKind
        const g = ghost
        placingKind = ""
        ghost = null
        if (!insideCanvas(sx, sy))
            return
        const w = toWorld(sx, sy)
        if (kind === "ruler") {
            const half = 80 / zoom
            TrackStore.run("setRuler", { a: { x: w.x - half, y: w.y }, b: { x: w.x + half, y: w.y }, realLength: 0 })
            TrackStore.select("ruler")
        } else if (kind === "origin" || kind === "direction") {
            TrackStore.run("setTarget", { which: kind, point: { x: w.x, y: w.y } })
            TrackStore.select(kind)
        } else if (g) {
            TrackStore.run("add", { type: kind, x: g.x, y: g.y, rotation: g.rotation, snap: g.snap })
            TrackStore.selectLast()
        }
        TrackStore.seal()
    }

    function pressAt(e) {
        canvas.forceActiveFocus()
        gestureKey = TrackStore.newGestureKey()
        press = { sx: e.x, sy: e.y, panX: panX, panY: panY }
        if (e.button === Qt.MiddleButton || (e.button === Qt.LeftButton && spaceHeld)) {
            mode = "pan"
            return
        }
        if (e.button !== Qt.LeftButton)
            return
        const hit = hitAt(e.x, e.y)
        if (!hit) {
            TrackStore.select("")
            mode = "pan"
            return
        }
        const t = TrackStore.track
        if (hit.kind === "rulerA" || hit.kind === "rulerB" || hit.kind === "ruler") {
            TrackStore.select("ruler")
            press.ruler = t.ruler
            mode = hit.kind
        } else if (hit.kind === "target") {
            TrackStore.select(hit.which)
            press.which = hit.which
            press.target = t.targets[hit.which]
            mode = "target"
        }
    }

    function moveTo(e) {
        hover = toWorld(e.x, e.y)
        if (!mouse.pressed || mode === "")
            return
        const dx = (e.x - press.sx) / zoom
        const dy = (e.y - press.sy) / zoom
        if (mode === "pan") {
            panX = press.panX + e.x - press.sx
            panY = press.panY + e.y - press.sy
        } else if (mode === "rulerA" || mode === "rulerB" || mode === "ruler") {
            const r = press.ruler
            const a = mode === "rulerB" ? r.a : { x: r.a.x + dx, y: r.a.y + dy }
            const b = mode === "rulerA" ? r.b : { x: r.b.x + dx, y: r.b.y + dy }
            TrackStore.run("setRuler", { a: a, b: b, realLength: r.realLength, mergeKey: gestureKey })
        } else if (mode === "target") {
            TrackStore.run("setTarget", { which: press.which, point: { x: press.target.x + dx, y: press.target.y + dy },
                                          mergeKey: gestureKey })
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
        ElementView {
            element: canvas.ghost
            zoom: canvas.zoom
            opacity: 0.6
        }
        RulerView { zoom: canvas.zoom }
        TargetsView { zoom: canvas.zoom }
    }

    // Labels drawn in screen pixels, so text stays sharp and the same size at any zoom.
    Item {
        id: overlay
        anchors.fill: parent

        Repeater {
            model: ["origin", "direction"]
            Label {
                required property string modelData
                readonly property var at: TrackStore.track.targets[modelData]
                visible: at !== null
                x: at ? canvas.toScreen(at.x, at.y).x + 14 : 0
                y: at ? canvas.toScreen(at.x, at.y).y - 24 : 0
                text: modelData === "origin" ? qsTr("Origin") : qsTr("Direction")
                color: "#00ffff"
                font.bold: true
                style: Text.Outline
                styleColor: "#000000"
            }
        }
        Label {
            readonly property var o: TrackStore.track.targets.origin
            readonly property var d: TrackStore.track.targets.direction
            // o and d are checked too: while a track loads, frame can still hold the old targets.
            visible: TrackStore.frame !== null && o !== null && d !== null
            x: visible ? canvas.toScreen((o.x + d.x) / 2, (o.y + d.y) / 2).x - width / 2 : 0
            y: visible ? canvas.toScreen((o.x + d.x) / 2, (o.y + d.y) / 2).y + 8 : 0
            text: TrackStore.frame ? Units.format(TrackStore.frame.distance, Settings.units) : ""
            color: "#00ffff"
            style: Text.Outline
            styleColor: "#000000"
        }
        Label {
            readonly property var r: TrackStore.track.ruler
            visible: r !== null
            x: r ? canvas.toScreen((r.a.x + r.b.x) / 2, (r.a.y + r.b.y) / 2).x - width / 2 : 0
            y: r ? canvas.toScreen((r.a.x + r.b.x) / 2, (r.a.y + r.b.y) / 2).y - height - 10 : 0
            text: !r ? "" : r.realLength > 0 ? Units.format(r.realLength, Settings.units) : qsTr("Set real length")
            color: "#f5cb42"
            font.bold: true
            style: Text.Outline
            styleColor: "#000000"
        }
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
