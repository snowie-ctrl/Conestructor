// The track, and every edit to it. A track is plain data:
//   { photo: { kind, ref, metresPerPixel },  kind "none" (not chosen), "blueprint" or "image"; ref a PhotoStore id
//                                            (image only, else null); metresPerPixel comes from the ruler
//     ruler: null | { a: {x, y}, b: {x, y}, realLength },   ends in photo pixels, realLength in metres (0 = not set)
//     targets: { origin: null | {x, y}, direction: null | {x, y} },  photo pixels
//     elements: [ { id, type, x, y, rotation, props, joins: { A: null | {id, end}, B: ... } } ],  canvas metres
//     nextId }
// Every command is a pure function from the old track to a new one; `run` records each on an UndoStack, which keeps
// the track before and after each step, so undo is exact. Tests: tests/qml/tst_commands.qml.
import * as Elements from "./elements.mjs"
import * as Snapping from "./snapping.mjs"

export function emptyTrack() {
    return { photo: { kind: "none", ref: null, metresPerPixel: 0 }, ruler: null, targets: { origin: null, direction: null },
             elements: [], nextId: 1 }
}

export function clone(track) {
    return JSON.parse(JSON.stringify(track))
}

export function rulerMetresPerPixel(ruler) {
    if (!ruler || !(ruler.realLength > 0))
        return 0
    const pixels = Math.hypot(ruler.b.x - ruler.a.x, ruler.b.y - ruler.a.y)
    return pixels > 0 ? ruler.realLength / pixels : 0
}

function find(track, id) {
    const el = track.elements.find(e => e.id === id)
    if (!el)
        throw new Error("No element " + id)
    return el
}

function attach(track, el, snap) {
    if (!snap)
        return
    Object.assign(el, Snapping.placeToJoin(el, snap.ownEnd, find(track, snap.id), snap.end))
    Snapping.join(track.elements, el.id, snap.ownEnd, snap.id, snap.end)
    Snapping.joinTouching(track.elements, el.id)
}

function point(p) {
    return p ? { x: p.x, y: p.y } : null
}

// Each takes a copy of the track (theirs to change) and the arguments, and returns the new track.
const COMMANDS = {
    newTrack() {
        return emptyTrack()
    },
    setPhoto(t, a) {
        t.photo.kind = a.kind
        t.photo.ref = a.kind === "image" ? a.ref : null
        return t
    },
    setRuler(t, a) {
        const oldScale = t.photo.metresPerPixel
        t.ruler = { a: point(a.a), b: point(a.b), realLength: a.realLength || 0 }
        const newScale = rulerMetresPerPixel(t.ruler)
        if (t.elements.length > 0 && !(newScale > 0))
            return null                                    // refused: the elements' sizes need a scale
        if (oldScale > 0 && newScale > 0 && newScale !== oldScale) {
            // Elements stay on the same spots of the photo; their sizes in metres do not change.
            const k = newScale / oldScale
            for (const el of t.elements) {
                el.x *= k
                el.y *= k
            }
            Snapping.glueAll(t.elements)
            Snapping.unjoinApart(t.elements)
        }
        t.photo.metresPerPixel = newScale
        return t
    },
    removeRuler(t) {
        if (t.elements.length > 0)
            return null
        t.ruler = null
        t.photo.metresPerPixel = 0
        return t
    },
    setTarget(t, a) {
        t.targets[a.which] = point(a.point)
        return t
    },
    add(t, a) {
        const el = { id: "e" + t.nextId, type: a.type, x: a.x, y: a.y, rotation: a.rotation || 0,
                     props: Object.assign(Elements.defaults(a.type), a.props || {}), joins: { A: null, B: null } }
        t.nextId += 1
        t.elements.push(el)
        attach(t, el, a.snap)
        return t
    },
    place(t, a) {
        const el = find(t, a.id)
        Snapping.unjoinAll(t.elements, el.id)
        el.x = a.x
        el.y = a.y
        el.rotation = a.rotation
        attach(t, el, a.snap)
        return t
    },
    setProp(t, a) {
        const el = find(t, a.id)
        el.props[a.key] = Elements.clampProp(el.type, a.key, a.value).value
        Snapping.settle(t.elements, el.id)
        Snapping.unjoinApart(t.elements)
        return t
    },
    remove(t, a) {
        find(t, a.id)
        Snapping.unjoinAll(t.elements, a.id)
        t.elements = t.elements.filter(e => e.id !== a.id)
        return t
    },
    duplicate(t, a) {
        const source = find(t, a.id)
        t.elements.push({ id: "e" + t.nextId, type: source.type, x: source.x + 2, y: source.y + 2,
                          rotation: source.rotation, props: Object.assign({}, source.props), joins: { A: null, B: null } })
        t.nextId += 1
        return t
    },
    // Drives each element the other way, in place: same footprint, entry and exit swapped, joins kept.
    reverse(t, a) {
        for (const id of a.ids) {
            const el = find(t, id)
            Object.assign(el, Elements.reversed(el))
            el.joins = { A: el.joins.B, B: el.joins.A }
            for (const end of ["A", "B"]) {
                const mate = el.joins[end]
                if (mate)
                    find(t, mate.id).joins[mate.end] = { id: el.id, end: end }
            }
        }
        return t
    },
    // A typed rotation: the element's whole joined chain turns about the element's middle and stays joined.
    rotateChain(t, a) {
        const el = find(t, a.id)
        const rotation = Elements.normalizeAngle(a.rotation)
        const turn = Elements.normalizeAngle(rotation - el.rotation)
        Snapping.turnAbout(t.elements, Snapping.chainOf(t.elements, el.id), { x: el.x, y: el.y }, turn)
        el.rotation = rotation
        return t
    }
}

function capitalised(text) {
    return text.charAt(0).toUpperCase() + text.slice(1)
}

// The step's name in the Edit menu ("Undo Move Straight"), worked out from the track before the step.
export function label(track, name, a) {
    const named = id => {
        const el = track.elements.find(e => e.id === id)
        return el ? Elements.NAMES[el.type] : ""
    }
    switch (name) {
    case "newTrack": return "New track"
    case "setPhoto": return a.kind === "blueprint" ? "Use blueprint" : "Load photo"
    case "setRuler": return "Set ruler"
    case "removeRuler": return "Delete ruler"
    case "setTarget":
        return (a.point ? (track.targets[a.which] ? "Move " : "Place ") : "Delete ") + capitalised(a.which)
    case "add": return "Add " + Elements.NAMES[a.type]
    case "place": return (a.verb || "Move") + " " + named(a.id)
    case "setProp": {
        const el = track.elements.find(e => e.id === a.id)
        const def = el ? Elements.PROPS[el.type].find(p => p.key === a.key) : null
        return "Change " + (def ? def.label : a.key)
    }
    case "remove": return "Delete " + named(a.id)
    case "duplicate": return "Duplicate " + named(a.id)
    case "reverse": return "Reverse " + (a.ids.length === 1 ? named(a.ids[0]) : a.ids.length + " elements")
    case "rotateChain": return "Rotate " + named(a.id)
    }
    return name
}

function mergeKeyFor(name, a) {
    if (a.mergeKey)
        return a.mergeKey
    return name === "setProp" ? "prop:" + a.id + ":" + a.key : ""
}

// Runs one command and records it. Returns the new track, or `track` itself when nothing changed (or the command
// was refused), in which case nothing is recorded.
export function run(stack, track, name, args) {
    const command = COMMANDS[name]
    if (!command)
        throw new Error("Unknown command " + name)
    const a = args || {}
    const after = command(clone(track), a)
    if (after === null || JSON.stringify(after) === JSON.stringify(track))
        return track
    stack.push(label(track, name, a), track, after, mergeKeyFor(name, a))
    return after
}

// Steps of { label, before, after, mergeKey }. A step whose mergeKey matches the last one, with no seal in between,
// replaces that step's `after`: typing into one field, or one drag, is one step. seal() ends the merging.
export class UndoStack {
    constructor(limit) {
        this.limit = limit || 200
        this.clear()
    }
    clear() {
        this.done = []
        this.undone = []
        this.sealed = true
    }
    push(label, before, after, mergeKey) {
        const top = this.done[this.done.length - 1]
        if (!this.sealed && top && mergeKey && top.mergeKey === mergeKey) {
            top.after = after
        } else {
            this.done.push({ label: label, before: before, after: after, mergeKey: mergeKey })
            if (this.done.length > this.limit)
                this.done.shift()
        }
        this.undone = []
        this.sealed = !mergeKey
    }
    seal() { this.sealed = true }
    canUndo() { return this.done.length > 0 }
    canRedo() { return this.undone.length > 0 }
    undoLabel() { return this.done.length > 0 ? this.done[this.done.length - 1].label : "" }
    redoLabel() { return this.undone.length > 0 ? this.undone[this.undone.length - 1].label : "" }
    undo() {
        const step = this.done.pop()
        if (!step)
            return null
        this.undone.push(step)
        this.sealed = true
        return step.before
    }
    redo() {
        const step = this.undone.pop()
        if (!step)
            return null
        this.done.push(step)
        this.sealed = true
        return step.after
    }
}
