import QtQuick
import QtQuick.Controls
import Conestructor
import "logic/elements.mjs" as Elements
import "logic/frame.mjs" as Frame
import "logic/selection.mjs" as Selection
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
    // The lot photo from PhotoStore, or the blueprint when there is none.
    readonly property string photoSource: {
        const p = TrackStore.track.photo
        return p.kind === "image" && p.ref !== null ? PhotoStore.url(p.ref) : blueprint
    }
    property bool fitPending: true
    property bool spaceHeld: false
    property var hover: null          // the photo pixel under the cursor, or null

    property string mode: ""          // the gesture in progress: "pan" (later tasks add more)
    property var press: null          // where the gesture started and what it started on
    property string gestureKey: ""
    property string placingKind: ""   // a palette tile being dragged: a track type, "ruler", "origin" or "direction"
    property var ghost: null          // the track element being placed, as it would land
    property var box: null            // the selection box being dragged, in screen pixels

    // The backwards element whose warning is under the cursor ("" when none), for its tip.
    readonly property string hoverWarning: {
        if (!hover || !(mpp > 0))
            return ""
        const h = toScreen(hover.x, hover.y)
        for (const id of TrackStore.backwardIds) {
            const el = TrackStore.element(id)
            if (!el)
                continue
            const m = Elements.pointsAlong(el, [0.5])[0]
            const s = toScreen(m.x / mpp, m.y / mpp)
            if (Math.hypot(s.x - h.x, s.y - h.y) < 14)
                return id
        }
        return ""
    }

    onPhotoSourceChanged: fitPending = true
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
        const selected = TrackStore.selectedElement
        if (selected && mpp > 0) {
            const h = Elements.rotateHandle(selected, 24 / zoom * mpp)
            if (distance({ x: h.x / mpp, y: h.y / mpp }, w) < reach)
                return { kind: "rotate", id: selected.id }
        }
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
        if (mpp > 0) {
            const id = Elements.hitTest(t.elements, { x: w.x * mpp, y: w.y * mpp }, 4 / zoom * mpp)
            if (id !== "")
                return { kind: "element", id: id }
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

    // Puts the element where the drag says, snapped to the nearest open end unless Ctrl is held. The element
    // unjoins as it moves and joins again wherever it lands snapped.
    function placeDragged(moved, ctrl) {
        const snap = ctrl ? null : Snapping.findSnap(TrackStore.track.elements, moved, snapMetres())
        TrackStore.run("place", {
            id: moved.id, x: moved.x, y: moved.y, rotation: moved.rotation,
            snap: snap ? { ownEnd: snap.ownEnd, id: snap.targetId, end: snap.targetEnd } : null,
            verb: "Move", mergeKey: gestureKey
        })
    }

    function pressAt(e) {
        canvas.forceActiveFocus()
        gestureKey = TrackStore.newGestureKey()
        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0
        const shift = (e.modifiers & Qt.ShiftModifier) !== 0
        press = { sx: e.x, sy: e.y, panX: panX, panY: panY, ctrl: ctrl }
        if (e.button === Qt.MiddleButton || (e.button === Qt.LeftButton && spaceHeld)) {
            mode = "pan"
            return
        }
        const hit = hitAt(e.x, e.y)
        if (e.button === Qt.RightButton) {
            if (hit && hit.kind === "element") {
                if (!TrackStore.isSelected(hit.id))
                    TrackStore.select(hit.id)
                elementMenu.popup()
            }
            return
        }
        if (e.button !== Qt.LeftButton)
            return
        if (!hit) {
            if (shift) {
                press.w = toWorld(e.x, e.y)
                press.add = ctrl
                mode = "box"
                return
            }
            TrackStore.select("")
            mode = "pan"
            return
        }
        const t = TrackStore.track
        if (hit.kind === "element" || hit.kind === "rotate") {
            if (hit.kind === "element" && ctrl) {
                const removing = TrackStore.isSelected(hit.id)
                TrackStore.toggle(hit.id)
                if (removing)
                    return            // a Ctrl+click that takes an element out starts no drag
            } else if (!TrackStore.isSelected(hit.id)) {
                TrackStore.select(hit.id)
            }
            press.el = TrackStore.element(hit.id)
            press.group = TrackStore.selectedElements.map(el => JSON.parse(JSON.stringify(el)))
            press.w = toWorld(e.x, e.y)
            mode = hit.kind === "rotate" ? "rotate" : press.group.length > 1 ? "moveGroup" : "move"
            return
        }
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
        // Nothing but a pan moves until the pointer has travelled a drag's distance: a click that wobbles a pixel
        // only selects, and never unjoins anything.
        if (mode !== "pan" && !press.dragging) {
            if (Math.hypot(e.x - press.sx, e.y - press.sy) < Qt.styleHints.startDragDistance)
                return
            press.dragging = true
        }
        const dx = (e.x - press.sx) / zoom
        const dy = (e.y - press.sy) / zoom
        if (mode === "pan") {
            panX = press.panX + e.x - press.sx
            panY = press.panY + e.y - press.sy
        } else if (mode === "move") {
            const ctrl = (e.modifiers & Qt.ControlModifier) !== 0
            placeDragged(Object.assign({}, press.el, { x: press.el.x + dx * mpp, y: press.el.y + dy * mpp }), ctrl)
        } else if (mode === "moveGroup") {
            const ctrl = (e.modifiers & Qt.ControlModifier) !== 0
            const moved = press.group.map(g => Object.assign({}, g, { x: g.x + dx * mpp, y: g.y + dy * mpp }))
            let placed = moved
            let snap = null
            const found = ctrl ? null : Snapping.findGroupSnap(TrackStore.track.elements, moved, snapMetres())
            if (found) {
                placed = Snapping.groupToJoin(moved, found.ownId, found.ownEnd, TrackStore.element(found.targetId),
                                              found.targetEnd)
                snap = { ownId: found.ownId, ownEnd: found.ownEnd, id: found.targetId, end: found.targetEnd }
            }
            TrackStore.run("placeMany", { moves: placed.map(p => ({ id: p.id, x: p.x, y: p.y, rotation: p.rotation })),
                                          snap: snap, verb: "Move", mergeKey: gestureKey })
        } else if (mode === "box") {
            box = { x: Math.min(press.sx, e.x), y: Math.min(press.sy, e.y),
                    width: Math.abs(e.x - press.sx), height: Math.abs(e.y - press.sy) }
        } else if (mode === "rotate") {
            const cx = press.el.x / mpp
            const cy = press.el.y / mpp
            const w = toWorld(e.x, e.y)
            let rotation = press.el.rotation
                + (Math.atan2(w.y - cy, w.x - cx) - Math.atan2(press.w.y - cy, press.w.x - cx)) * 180 / Math.PI
            if ((e.modifiers & Qt.ShiftModifier) !== 0)
                rotation = Math.round(rotation / 15) * 15
            TrackStore.run("place", { id: press.el.id, x: press.el.x, y: press.el.y, rotation: Frame.normalize(rotation),
                                      snap: null, verb: "Rotate", mergeKey: gestureKey })
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
        if (mode === "box" && press.dragging && mpp > 0) {
            const a = press.w
            const b = toWorld(e.x, e.y)
            TrackStore.selectMany(Selection.boxHits(TrackStore.track.elements, { x: a.x * mpp, y: a.y * mpp },
                                                    { x: b.x * mpp, y: b.y * mpp }), press.add)
        } else if (mode === "moveGroup" && !press.dragging && !press.ctrl) {
            TrackStore.select(press.el.id)       // a plain click on one of several selects only it
        }
        if (mode !== "" && mode !== "pan" && mode !== "box")
            TrackStore.seal()
        mode = ""
        press = null
        box = null
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
            objectName: "photo"
            source: canvas.photoSource
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
                selected: element !== null && TrackStore.selection.indexOf(element.id) >= 0
                single: TrackStore.selection.length === 1
                dimmed: TrackStore.previewOn
                backwards: element !== null && TrackStore.backwardIds.indexOf(element.id) >= 0
            }
        }
        ElementView {
            element: canvas.ghost
            zoom: canvas.zoom
            opacity: 0.6
        }
        ConePreview { zoom: canvas.zoom }
        RulerView { zoom: canvas.zoom }
        TargetsView { zoom: canvas.zoom }
    }

    // Labels drawn in screen pixels, so text stays sharp and the same size at any zoom.
    Item {
        id: overlay
        anchors.fill: parent

        Rectangle {
            objectName: "selectionBox"
            visible: canvas.box !== null
            x: canvas.box ? canvas.box.x : 0
            y: canvas.box ? canvas.box.y : 0
            width: canvas.box ? canvas.box.width : 0
            height: canvas.box ? canvas.box.height : 0
            color: Qt.rgba(0.18, 0.44, 0.84, 0.15)
            border.color: "#2f6fd6"
        }

        Label {
            objectName: "warningTip"
            z: 1
            visible: canvas.hoverWarning !== "" && canvas.hover !== null
            x: canvas.hover ? canvas.toScreen(canvas.hover.x, canvas.hover.y).x + 16 : 0
            y: canvas.hover ? canvas.toScreen(canvas.hover.x, canvas.hover.y).y + 12 : 0
            text: qsTr("Runs against the track: right-click › Reverse direction")
            color: "#f0f0f0"
            padding: 6
            background: Rectangle { color: "#333333"; radius: 4; border.color: "#ffb300" }
        }

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
        cursorShape: canvas.mode === "pan" ? Qt.ClosedHandCursor
                     : canvas.mode === "move" || canvas.mode === "moveGroup" || canvas.mode === "target" ? Qt.SizeAllCursor
                     : Qt.ArrowCursor
        onPressed: (e) => canvas.pressAt(e)
        onPositionChanged: (e) => canvas.moveTo(e)
        onReleased: (e) => canvas.releaseAt(e)
        onExited: canvas.hover = null
        onWheel: (w) => canvas.zoomBy(Math.pow(1.0015, w.angleDelta.y), w.x, w.y)
    }

    Menu {
        id: elementMenu
        MenuItem { text: qsTr("Duplicate"); onTriggered: TrackStore.duplicateSelected() }
        MenuItem { text: qsTr("Delete"); onTriggered: TrackStore.deleteSelected() }
        MenuItem { text: qsTr("Reverse direction"); onTriggered: TrackStore.reverseSelected() }
    }
}
