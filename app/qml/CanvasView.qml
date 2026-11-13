import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Conestructor
import "logic/car.mjs" as Car
import "logic/elements.mjs" as Elements
import "logic/frame.mjs" as Frame
import "logic/nodes.mjs" as Nodes
import "logic/selection.mjs" as Selection
import "logic/setup.mjs" as Setup
import "logic/snapping.mjs" as Snapping
import "logic/touchups.mjs" as Touchups
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
    property string placingBy: ""     // "drag": a tile is being dragged; "click": picked up, the next click puts it down
    property var placingPoint: null   // the photo pixel under the mouse while placing the ruler or a target
    property var rulerFirst: null     // the ruler's first end, once clicked
    property bool lengthBoxOpen: false
    property int lengthBoxAsks: 0     // goes up each time the length box is asked for: an open box takes the focus back
    // A track piece in hand is dropped when setup comes undone (the track tiles lock again).
    readonly property bool setupDone: Setup.status(TrackStore.track).done
    onSetupDoneChanged: if (!setupDone && Elements.TYPES.indexOf(placingKind) >= 0) cancelPlacing()
    // Touch-ups lock the track: a track piece, the ruler or a target in hand is put back (part 4's minor 1), since the
    // next click would be refused and selectLast would pick an unrelated element. An added cone stays in hand.
    readonly property bool trackLocked: TrackStore.locked
    onTrackLockedChanged: if (trackLocked && placingKind !== "" && placingKind !== "cone") cancelPlacing()

    // A tile in hand, a ruler's first click or the length box belong to the track they were started on.
    Connections {
        target: TrackStore
        function onTrackReplaced() {
            canvas.cancelPlacing()
            canvas.lengthBoxOpen = false
        }
    }
    // The ruler as it would land: between the first click and the mouse, or (dragged) 160 screen pixels centred there.
    readonly property var rulerGhost: {
        const p = placingPoint
        if (placingKind !== "ruler" || p === null)
            return null
        if (rulerFirst)
            return { a: rulerFirst, b: p }
        const half = placingBy === "drag" ? 80 / zoom : 0
        return { a: { x: p.x - half, y: p.y }, b: { x: p.x + half, y: p.y } }
    }
    property var box: null            // the selection box being dragged, in screen pixels
    property var hoverNode: null      // the open end under the mouse ({ id, end }), or null
    // Placed cones are showing: they can be picked for touch-ups.
    readonly property bool conesShown: TrackStore.previewOn && TrackStore.showCones && TrackStore.preview !== null
    property var menuPoint: null      // where the canvas menu was opened (photo pixels)

    // The true-size car outline (Tools › Car outline): shown or not, and where ({ x, y, rotation } in canvas metres). Kept
    // until the app closes; never part of the track or the undo history. It needs a scale.
    property bool carShown: false
    property var car: null
    onMppChanged: if (!(mpp > 0)) carShown = false

    function setCarShown(on) {
        if (on && !(mpp > 0))
            return
        if (on && car === null) {
            const c = toWorld(width / 2, height / 2)
            car = { x: c.x * mpp, y: c.y * mpp, rotation: TrackStore.frame ? Frame.headingFromFrame(TrackStore.frame, 0) : 0 }
        }
        carShown = on
    }
    onConesShownChanged: if (!conesShown && placingKind === "cone") cancelPlacing()

    // The rotate handle of the one selected leaning cone (canvas metres), 24 screen pixels past its tip, or null.
    readonly property var coneHandle: {
        if (!conesShown || TrackStore.coneSelection.length !== 1 || !(mpp > 0))
            return null
        const index = TrackStore.coneSelection[0]
        const c = TrackStore.preview.canvasCones[index]
        if (!c || c.type !== "leaning")
            return null
        const r = c.heading * Math.PI / 180
        const reach = Touchups.LEANING_RADIUS + 24 / zoom * mpp
        return { index: index, x: c.x + Math.cos(r) * reach, y: c.y + Math.sin(r) * reach }
    }

    // The backwards element whose warning is under the cursor ("" when none), for its tip.
    readonly property string hoverWarning: {
        if (!hover || !(mpp > 0))
            return ""
        const h = toScreen(hover.x, hover.y)
        for (const id of TrackStore.backwardIds.concat(TrackStore.foldedIds)) {
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

    // The open end (a gate node) within 10 screen pixels of photo pixel w, topmost element first, or null.
    function nodeAt(w) {
        if (!(mpp > 0))
            return null
        const list = TrackStore.track.elements
        for (let i = list.length - 1; i >= 0; i--) {
            const el = list[i]
            const ends = Elements.endsWorld(el)
            for (const end of ["A", "B"])
                if (!el.joins[end] && distance({ x: ends[end].x / mpp, y: ends[end].y / mpp }, w) < 10 / zoom)
                    return { kind: "node", id: el.id, end: end }
        }
        return null
    }

    // The placed cone under photo pixel w (the nearest whose footprint, grown by 4 screen pixels, covers it), or -1.
    function coneAt(w) {
        if (!conesShown || !(mpp > 0))
            return -1
        return Touchups.coneAt(TrackStore.preview.canvasCones, { x: w.x * mpp, y: w.y * mpp }, 4 / zoom * mpp)
    }

    // What is under a screen point, most specific first.
    function hitAt(sx, sy) {
        const w = toWorld(sx, sy)
        const reach = 10 / zoom
        const t = TrackStore.track
        if (carShown && car && mpp > 0) {
            const h = Car.handle(car, Settings.carLength, 24 / zoom * mpp)
            if (distance({ x: h.x / mpp, y: h.y / mpp }, w) < reach)
                return { kind: "carRotate" }
            if (Car.contains(car, Settings.carLength, Settings.carWidth, { x: w.x * mpp, y: w.y * mpp }))
                return { kind: "car" }
        }
        const selected = TrackStore.selectedElement
        if (selected && mpp > 0) {
            const h = Elements.rotateHandle(selected, 24 / zoom * mpp)
            if (distance({ x: h.x / mpp, y: h.y / mpp }, w) < reach)
                return { kind: "rotate", id: selected.id }
        }
        if (coneHandle && distance({ x: coneHandle.x / mpp, y: coneHandle.y / mpp }, w) < reach)
            return { kind: "coneRotate", index: coneHandle.index }
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
        const cone = coneAt(w)
        if (cone >= 0)
            return { kind: "cone", index: cone }
        const node = nodeAt(w)
        if (node)
            return node
        if (mpp > 0) {
            const id = Elements.hitTest(t.elements, { x: w.x * mpp, y: w.y * mpp }, 4 / zoom * mpp)
            if (id !== "")
                return { kind: "element", id: id }
        }
        if (t.ruler && Elements.pointSegmentDistance(w, t.ruler.a, t.ruler.b) < 6 / zoom)
            return { kind: "ruler" }
        return null
    }

    // What an element's warning says: driven backwards, folding in on itself, or both (one line each).
    function warningText(id) {
        const el = TrackStore.element(id)
        if (!el)
            return ""
        const lines = []
        if (TrackStore.backwardIds.indexOf(id) >= 0)
            lines.push(qsTr("Runs against the track: right-click › Reverse direction"))
        const fold = Elements.foldAdvice(el, m => Units.format(m, Settings.units))
        if (fold !== "")
            lines.push(fold)
        return lines.join("\n")
    }

    // A tile dragged onto the canvas.
    function beginPlacing(kind) {
        cancelPlacing()
        placingKind = kind
        placingBy = "drag"
    }

    // A tile clicked: it is picked up and follows the mouse until a canvas click puts it down.
    function pickUp(kind) {
        cancelPlacing()
        placingKind = kind
        placingBy = "click"
        canvas.forceActiveFocus()
        TrackStore.message = placingHint(kind)
    }

    // Clicking the tile that is picked up drops it; any other tile is picked up instead.
    function clickTile(kind) {
        if (placingBy === "click" && placingKind === kind)
            cancelPlacing()
        else
            pickUp(kind)
    }

    // Process › Add cone: a standing cone follows the mouse until a click puts it down (choosing it again drops it).
    function addCone() {
        if (conesShown)
            clickTile("cone")
    }

    function cancelPlacing() {
        if (placingBy === "click")
            TrackStore.message = ""
        placingKind = ""
        placingBy = ""
        ghost = null
        placingPoint = null
        rulerFirst = null
    }

    function placingHint(kind) {
        if (kind === "cone")
            return qsTr("Click where the cone goes · Esc to cancel")
        if (kind === "ruler")
            return rulerFirst ? qsTr("Click the other end · Esc to cancel")
                              : qsTr("Click one end of something you know the length of · Esc to cancel")
        if (kind === "origin")
            return qsTr("Click where Origin goes · Esc to cancel")
        if (kind === "direction")
            return qsTr("Click where Direction goes · Esc to cancel")
        return qsTr("Click where the %1 goes · Esc to cancel").arg(Elements.NAMES[kind])
    }

    function openLengthBox() {
        lengthBoxOpen = true
        lengthBoxAsks += 1
    }

    function insideCanvas(sx, sy) {
        return sx >= 0 && sy >= 0 && sx <= width && sy <= height
    }

    function updatePlacing(sx, sy, ctrl) {
        if (!insideCanvas(sx, sy)) {
            ghost = null
            placingPoint = null
            return
        }
        if (Elements.TYPES.indexOf(placingKind) < 0) {
            placingPoint = toWorld(sx, sy)
            return
        }
        if (!(mpp > 0)) {
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

    // A dragged tile let go.
    function finishPlacing(sx, sy) {
        const kind = placingKind
        const g = ghost
        cancelPlacing()
        if (insideCanvas(sx, sy))
            putDown(kind, toWorld(sx, sy), g, null)
    }

    // A canvas click while a tile is picked up. The ruler's first click only sets its first end.
    function clickPlace(sx, sy, ctrl) {
        const kind = placingKind
        const w = toWorld(sx, sy)
        if (kind === "ruler" && !rulerFirst) {
            rulerFirst = w
            TrackStore.message = placingHint(kind)
            return
        }
        if (kind === "ruler" && distance(rulerFirst, w) * zoom < 3)
            return                          // the other end must be somewhere else
        updatePlacing(sx, sy, ctrl)
        const g = ghost
        const ends = kind === "ruler" ? { a: rulerFirst, b: w } : null
        cancelPlacing()
        putDown(kind, w, g, ends)
    }

    // Puts a tile down at photo pixel w. A dragged ruler lands centred there, 160 screen pixels long; a clicked one
    // between its two clicks. A ruler without a length opens the length box.
    function putDown(kind, w, g, rulerEnds) {
        if (kind === "ruler") {
            const half = 80 / zoom
            const ends = rulerEnds || { a: { x: w.x - half, y: w.y }, b: { x: w.x + half, y: w.y } }
            TrackStore.run("setRuler", { a: ends.a, b: ends.b, realLength: 0 })
            TrackStore.select("ruler")
            lengthBoxOpen = true
        } else if (kind === "origin" || kind === "direction") {
            TrackStore.run("setTarget", { which: kind, point: { x: w.x, y: w.y } })
            TrackStore.select(kind)
        } else if (kind === "cone") {
            TrackStore.addConeAt(w.x * mpp, w.y * mpp)
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
        if (placingBy === "click" && (e.button === Qt.LeftButton || e.button === Qt.RightButton)) {
            if (e.button === Qt.LeftButton)
                clickPlace(e.x, e.y, (e.modifiers & Qt.ControlModifier) !== 0)
            else
                cancelPlacing()
            return
        }
        gestureKey = TrackStore.newGestureKey()
        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0
        const shift = (e.modifiers & Qt.ShiftModifier) !== 0
        press = { sx: e.x, sy: e.y, panX: panX, panY: panY, ctrl: ctrl }
        if (e.button === Qt.MiddleButton || (e.button === Qt.LeftButton && spaceHeld)) {
            mode = "pan"
            return
        }
        let hit = hitAt(e.x, e.y)
        // An open end is a gate node only for a plain left press: right-click and Ctrl+click act on its element.
        if (hit && hit.kind === "node" && (e.button !== Qt.LeftButton || (e.modifiers & Qt.ControlModifier) !== 0))
            hit = { kind: "element", id: hit.id }
        if (e.button === Qt.RightButton) {
            if (hit && hit.kind === "cone") {
                if (!TrackStore.isConeSelected(hit.index))
                    TrackStore.selectCones([hit.index], false)
                coneMenu.popup()
                return
            }
            if (hit && hit.kind === "element") {
                if (!TrackStore.isSelected(hit.id))
                    TrackStore.select(hit.id)
                elementMenu.popup()
            }
            if (!hit && conesShown) {
                menuPoint = toWorld(e.x, e.y)
                canvasMenu.popup()
            }
            return
        }
        if (e.button !== Qt.LeftButton)
            return
        // The car outline works on a locked track too, and never changes the selection.
        if (hit && (hit.kind === "car" || hit.kind === "carRotate")) {
            press.car = Object.assign({}, car)
            mode = hit.kind
            return
        }
        // A locked track (touch-ups) only selects: nothing on it moves, and the status bar says how to unlock it.
        if (TrackStore.locked && hit && ["element", "node", "rotate", "rulerA", "rulerB", "ruler", "target"].indexOf(hit.kind) >= 0) {
            const id = hit.kind === "target" ? hit.which : hit.kind.indexOf("ruler") === 0 ? "ruler" : hit.id
            if (hit.kind === "element" && ctrl)
                TrackStore.toggle(id)
            else
                TrackStore.select(id)
            TrackStore.lockedNote()
            mode = ""
            return
        }
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
        if (hit.kind === "cone") {
            if (ctrl) {
                TrackStore.toggleCone(hit.index)
                return
            }
            if (!TrackStore.isConeSelected(hit.index))
                TrackStore.selectCones([hit.index], false)
            press.cone = hit.index
            press.c = Object.assign({}, TrackStore.preview.canvasCones[hit.index])
            mode = "cone"
            return
        }
        if (hit.kind === "coneRotate") {
            press.cone = hit.index
            press.c = Object.assign({}, TrackStore.preview.canvasCones[hit.index])
            mode = "coneRotate"
            return
        }
        const t = TrackStore.track
        if (hit.kind === "node") {
            TrackStore.select(hit.id)
            press.el = JSON.parse(JSON.stringify(TrackStore.element(hit.id)))
            press.end = hit.end
            press.pivot = press.el.joins[hit.end === "A" ? "B" : "A"] === null
            mode = "node"
            return
        }
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
        if (!mouse.pressed)
            hoverNode = placingKind === "" && !TrackStore.locked ? nodeAt(hover) : null
        if (placingBy === "click")
            updatePlacing(e.x, e.y, (e.modifiers & Qt.ControlModifier) !== 0)
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
        } else if (mode === "node") {
            const ctrl = (e.modifiers & Qt.ControlModifier) !== 0
            const shift = (e.modifiers & Qt.ShiftModifier) !== 0
            const w = toWorld(e.x, e.y)
            let p = { x: w.x * mpp, y: w.y * mpp }
            if (press.pivot && !ctrl && !shift) {
                const s = Nodes.snapPoint(TrackStore.track.elements, press.el.id, p, snapMetres())
                if (s)
                    p = s
            }
            const r = Nodes.drag(press.el, press.end, p, { pivot: press.pivot, step: shift ? 15 : 0,
                                                           frameTheta: TrackStore.frame ? TrackStore.frame.theta : 0 })
            TrackStore.run("stretch", { id: press.el.id, x: r.x, y: r.y, rotation: r.rotation, key: r.key, value: r.value,
                                        mergeKey: gestureKey })
        } else if (mode === "car") {
            car = Object.assign({}, press.car, { x: press.car.x + dx * mpp, y: press.car.y + dy * mpp })
        } else if (mode === "carRotate") {
            const w = toWorld(e.x, e.y)
            car = Object.assign({}, press.car, { rotation: Car.facing(press.car, { x: w.x * mpp, y: w.y * mpp },
                                                                      (e.modifiers & Qt.ShiftModifier) !== 0 ? 15 : 0) })
        } else if (mode === "cone") {
            TrackStore.run("moveCone", { index: press.cone, x: press.c.x + dx * mpp, y: press.c.y + dy * mpp,
                                         mergeKey: gestureKey })
        } else if (mode === "coneRotate") {
            const w = toWorld(e.x, e.y)
            let heading = Math.atan2(w.y * mpp - press.c.y, w.x * mpp - press.c.x) * 180 / Math.PI
            if ((e.modifiers & Qt.ShiftModifier) !== 0)
                heading = Math.round(heading / 15) * 15
            TrackStore.run("pointCone", { index: press.cone, heading: Frame.normalize(heading), mergeKey: gestureKey })
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
            const ma = { x: a.x * mpp, y: a.y * mpp }
            const mb = { x: b.x * mpp, y: b.y * mpp }
            if (conesShown)
                TrackStore.selectCones(Touchups.inBox(TrackStore.preview.canvasCones, ma, mb), press.add)
            else
                TrackStore.selectMany(Selection.boxHits(TrackStore.track.elements, ma, mb), press.add)
        } else if (mode === "cone" && !press.dragging && !press.ctrl && TrackStore.coneSelection.length > 1) {
            TrackStore.selectCones([press.cone], false)        // a plain click on one of several selects only it
        } else if (mode === "moveGroup" && !press.dragging && !press.ctrl) {
            TrackStore.select(press.el.id)       // a plain click on one of several selects only it
        }
        if (mode !== "" && mode !== "pan" && mode !== "box")
            TrackStore.seal()
        mode = ""
        press = null
        box = null
    }

    // The system took the mouse away mid-gesture: end it as a release would, without its click.
    function cancelGesture() {
        if (mode !== "" && mode !== "pan" && mode !== "box")
            TrackStore.seal()
        mode = ""
        press = null
        box = null
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape && placingBy !== "") {
            cancelPlacing()
            e.accepted = true
        } else if (e.key === Qt.Key_Escape && lengthBoxOpen) {
            lengthBoxOpen = false           // as the box's own Esc: the length stays unset
            e.accepted = true
        }
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
                folded: element !== null && TrackStore.foldedIds.indexOf(element.id) >= 0
                hoverEnd: element !== null && canvas.hoverNode !== null && canvas.hoverNode.id === element.id
                          ? canvas.hoverNode.end : ""
            }
        }
        ElementView {
            element: canvas.ghost
            zoom: canvas.zoom
            opacity: 0.6
        }
        ConePreview { zoom: canvas.zoom }
        // The selected leaning cone's rotate handle.
        Rectangle {
            objectName: "coneHandle"
            visible: canvas.coneHandle !== null
            width: 12 / canvas.zoom
            height: width
            radius: width / 2
            x: canvas.coneHandle ? canvas.coneHandle.x / canvas.mpp - width / 2 : 0
            y: canvas.coneHandle ? canvas.coneHandle.y / canvas.mpp - height / 2 : 0
            color: "#ffffff"
            border.color: "#202020"
            border.width: 1 / canvas.zoom
        }
        RulerView { zoom: canvas.zoom }
        TargetsView { zoom: canvas.zoom }
        CarOutline { canvas: canvas }

        // A ruler, target or cone being placed, where it would land.
        Item {
            visible: canvas.placingPoint !== null
            opacity: 0.6
            Image {
                visible: canvas.placingKind === "cone"
                source: "qrc:/qt/qml/Conestructor/assets/images/upright-cone.png"
                width: 2 * Touchups.STANDING_RADIUS / canvas.mpp
                height: width
                x: canvas.placingPoint ? canvas.placingPoint.x - width / 2 : 0
                y: canvas.placingPoint ? canvas.placingPoint.y - height / 2 : 0
                sourceSize: Qt.size(64, 64)
            }
            Image {
                visible: canvas.placingKind === "origin" || canvas.placingKind === "direction"
                source: "qrc:/qt/qml/Conestructor/assets/images/crosshair.svg"
                width: 32 / canvas.zoom
                height: width
                x: canvas.placingPoint ? canvas.placingPoint.x - width / 2 : 0
                y: canvas.placingPoint ? canvas.placingPoint.y - height / 2 : 0
                sourceSize: Qt.size(64, 64)
            }
            Shape {
                visible: canvas.rulerGhost !== null
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "#f5cb42"
                    strokeWidth: 2 / canvas.zoom
                    fillColor: "transparent"
                    startX: canvas.rulerGhost ? canvas.rulerGhost.a.x : 0
                    startY: canvas.rulerGhost ? canvas.rulerGhost.a.y : 0
                    PathLine {
                        x: canvas.rulerGhost ? canvas.rulerGhost.b.x : 0
                        y: canvas.rulerGhost ? canvas.rulerGhost.b.y : 0
                    }
                }
            }
            Repeater {
                model: canvas.rulerGhost ? [canvas.rulerGhost.a, canvas.rulerGhost.b] : []
                Rectangle {
                    required property var modelData
                    width: 12 / canvas.zoom
                    height: width
                    radius: width / 2
                    x: modelData.x - width / 2
                    y: modelData.y - height / 2
                    color: "#f5cb42"
                }
            }
        }
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
            text: canvas.warningText(canvas.hoverWarning)
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
        cursorShape: canvas.mode === "node" || (canvas.mode === "" && canvas.hoverNode !== null) ? Qt.CrossCursor
                     : canvas.mode === "pan" ? Qt.ClosedHandCursor
                     : canvas.mode === "move" || canvas.mode === "moveGroup" || canvas.mode === "target" || canvas.mode === "cone" || canvas.mode === "car" ? Qt.SizeAllCursor
                     : Qt.ArrowCursor
        onPressed: (e) => canvas.pressAt(e)
        onPositionChanged: (e) => canvas.moveTo(e)
        onReleased: (e) => canvas.releaseAt(e)
        onExited: {
            canvas.hover = null
            canvas.hoverNode = null
            if (canvas.placingBy === "click") {
                canvas.ghost = null             // it comes back when the mouse does
                canvas.placingPoint = null
            }
        }
        onCanceled: canvas.cancelGesture()
        onWheel: (w) => canvas.zoomBy(Math.pow(1.0015, w.angleDelta.y), w.x, w.y)
    }

    Menu {
        id: elementMenu
        objectName: "elementMenu"
        MenuItem { text: qsTr("Duplicate"); enabled: !TrackStore.locked; onTriggered: TrackStore.duplicateSelected() }
        MenuItem { text: qsTr("Delete"); enabled: !TrackStore.locked; onTriggered: TrackStore.deleteSelected() }
        MenuItem {
            objectName: "reverseItem"
            text: qsTr("Reverse direction")
            // A line is never driven: there is nothing to reverse.
            visible: TrackStore.selectedElements.some(e => e.type !== "line")
            height: visible ? implicitHeight : 0
            enabled: !TrackStore.locked
            onTriggered: TrackStore.reverseSelected()
        }
    }

    Menu {
        id: coneMenu
        objectName: "coneMenu"
        MenuItem {
            text: TrackStore.coneSelection.length > 1 ? qsTr("Delete %1 cones").arg(TrackStore.coneSelection.length)
                                                      : qsTr("Delete cone")
            onTriggered: TrackStore.deleteSelected()
        }
        MenuItem { text: qsTr("Make leaning"); onTriggered: TrackStore.setConeTypes("leaning") }
        MenuItem { text: qsTr("Make standing"); onTriggered: TrackStore.setConeTypes("standing") }
    }

    Menu {
        id: canvasMenu
        objectName: "canvasMenu"
        MenuItem {
            text: qsTr("Add a cone here")
            onTriggered: TrackStore.addConeAt(canvas.menuPoint.x * canvas.mpp, canvas.menuPoint.y * canvas.mpp)
        }
    }

    // After the MouseArea, so clicks in the box reach it.
    RulerLengthBox { canvas: canvas }
}
