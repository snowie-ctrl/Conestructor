// The .cone track file: one UTF-8 JSON document per track (docs/cone-format.md, docs/cone-format.schema.json). This
// module builds the document's text from the track, every field but the photo, which C++ (TrackFile) adds last as
// base64; and reads a parsed document back into a track, refusing anything it cannot use. Tests:
// tests/qml/tst_conefile.qml.
import * as Commands from "./commands.mjs"
import * as Elements from "./elements.mjs"
import * as Frame from "./frame.mjs"
import * as Post from "./postprocess.mjs"

export const FORMAT = "conestructor-track"
export const VERSION = 1
export const UNITS = "m"
export const AXES = "x toward Direction target, y to the left, heading degrees counter-clockwise from +x"
export const MESSAGES = {
    notTrack: "That file isn't a Conestructor track.",
    newer: "That track was made with a newer Conestructor.",
    damaged: "That track file is damaged.",
    photo: "The photo in that file couldn't be read; the blueprint is shown instead."
}
// Element ids the canvas uses for the ruler and the targets: an element may not take them.
const RESERVED_IDS = ["ruler", "origin", "direction"]
// Joined ends further apart than this in a hand-edited file are unjoined on open.
export const JOIN_SLACK = 0.05

// Rounded to `places` decimals; adding 0 turns -0 into 0 so the file never says "-0".
function round(value, places) {
    const f = Math.pow(10, places)
    return Math.round(value * f) / f + 0
}

// ISO 8601 UTC to the second: "2026-11-10T14:03:00Z".
export function timestamp(date) {
    return date.toISOString().replace(/\.\d{3}Z$/, "Z")
}

// The document for `track` as an object whose keys are in file order, without the photo.
// `info`: { name, app, saved }.
export function toDocument(track, info) {
    const scale = track.photo.metresPerPixel
    const frame = Frame.makeFrame(track.targets.origin, track.targets.direction, scale)
    const targets = {
        origin: track.targets.origin ? { x: 0, y: 0 } : null,
        direction: frame ? { x: round(frame.distance, 3), y: 0 } : null,
        distance: frame ? round(frame.distance, 3) : null
    }
    const result = Post.run(track)
    const cones = result.error ? [] : result.cones.map(c => ({
        index: c.index, type: c.type, x: round(c.x, 3), y: round(c.y, 3),
        heading: c.type === "standing" ? 0 : round(c.heading, 2), element: c.element
    }))
    const design = Commands.clone(track)
    design.photo = { kind: track.photo.kind, metresPerPixel: scale }
    return { format: FORMAT, version: VERSION, name: info.name, app: info.app, saved: info.saved, units: UNITS,
             axes: AXES, targets: targets, cones: cones, design: design }
}

// The document's text, two-space indented, without the photo (TrackFile adds it last).
export function documentText(track, info) {
    return JSON.stringify(toDocument(track, info), null, 2)
}

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function isNumber(v) {
    return typeof v === "number" && isFinite(v)
}

// A point, or undefined when `v` is not one.
function point(v) {
    return isObject(v) && isNumber(v.x) && isNumber(v.y) ? { x: v.x, y: v.y } : undefined
}

// null for a target not placed; undefined when `v` is neither.
function target(v) {
    return v === null || v === undefined ? null : point(v)
}

// One element in the app's own shape, or null when it cannot be read. Settings outside their limits are kept within
// them; missing settings take their defaults.
function readElement(v) {
    if (!isObject(v) || typeof v.id !== "string" || Elements.TYPES.indexOf(v.type) < 0)
        return null
    if (!isNumber(v.x) || !isNumber(v.y) || !isNumber(v.rotation) || !isObject(v.props) || !isObject(v.joins))
        return null
    const props = Elements.defaults(v.type)
    for (const def of Elements.PROPS[v.type]) {
        const value = v.props[def.key]
        if (value === undefined)
            continue
        if (def.kind === "choice" ? def.choices.indexOf(value) < 0 : !isNumber(value))
            return null
        props[def.key] = Elements.clamp(def, value).value
    }
    const joins = {}
    for (const end of ["A", "B"]) {
        const j = v.joins[end]
        if (j === null || j === undefined)
            joins[end] = null
        else if (isObject(j) && typeof j.id === "string" && (j.end === "A" || j.end === "B"))
            joins[end] = { id: j.id, end: j.end }
        else
            return null
    }
    return { id: v.id, type: v.type, x: v.x, y: v.y, rotation: v.rotation, props: props, joins: joins }
}

// Joins a hand edit has made impossible: ends more than JOIN_SLACK apart, or a line (lines are never joined). Both
// sides are unjoined, quietly.
function repairJoins(elements) {
    for (const el of elements) {
        for (const end of ["A", "B"]) {
            const j = el.joins[end]
            if (!j)
                continue
            const other = elements.find(e => e.id === j.id)
            const a = Elements.endsWorld(el)[end]
            const b = Elements.endsWorld(other)[j.end]
            if (el.type === "line" || other.type === "line" || Math.hypot(a.x - b.x, a.y - b.y) > JOIN_SLACK) {
                el.joins[end] = null
                other.joins[j.end] = null
            }
        }
    }
}

// The track from a document's `design`, or null when it is damaged.
function readDesign(d) {
    if (!isObject(d) || !isObject(d.photo) || !isObject(d.targets) || !Array.isArray(d.elements))
        return null
    if (["none", "blueprint", "image"].indexOf(d.photo.kind) < 0)
        return null
    let ruler = null
    if (d.ruler !== null && d.ruler !== undefined) {
        if (!isObject(d.ruler))
            return null
        const a = point(d.ruler.a)
        const b = point(d.ruler.b)
        if (!a || !b || !isNumber(d.ruler.realLength) || d.ruler.realLength < 0)
            return null
        ruler = { a: a, b: b, realLength: d.ruler.realLength }
    }
    const origin = target(d.targets.origin)
    const direction = target(d.targets.direction)
    if (origin === undefined || direction === undefined)
        return null
    const elements = []
    for (const v of d.elements) {
        const el = readElement(v)
        if (!el || RESERVED_IDS.indexOf(el.id) >= 0 || elements.some(e => e.id === el.id))
            return null
        elements.push(el)
    }
    for (const el of elements) {
        for (const end of ["A", "B"]) {
            const j = el.joins[end]
            if (!j)
                continue
            if (j.id === el.id)
                return null                                  // an element joined to itself
            const other = elements.find(e => e.id === j.id)
            const back = other ? other.joins[j.end] : null
            if (!back || back.id !== el.id || back.end !== end)
                return null
        }
    }
    const scale = Commands.rulerMetresPerPixel(ruler)
    if (elements.length > 0 && !(scale > 0))
        return null
    repairJoins(elements)
    let nextId = isNumber(d.nextId) ? Math.max(1, Math.floor(d.nextId)) : 1
    for (const el of elements) {
        const m = /^e(\d+)$/.exec(el.id)
        if (m)
            nextId = Math.max(nextId, Number(m[1]) + 1)
    }
    return { photo: { kind: d.photo.kind, ref: null, metresPerPixel: scale }, ruler: ruler,
             targets: { origin: origin, direction: direction }, elements: elements, nextId: nextId }
}

// A track from a parsed document whose photo TrackFile has already taken out: { track, warning } or { error }.
// `photoRef` is the photo's PhotoStore ref, or -1 when the file had none or it could not be read.
export function fromDocument(doc, photoRef) {
    if (!isObject(doc) || doc.format !== FORMAT)
        return { error: MESSAGES.notTrack }
    if (!isNumber(doc.version))
        return { error: MESSAGES.damaged }
    if (doc.version > VERSION)
        return { error: MESSAGES.newer }
    const track = readDesign(doc.design)
    if (!track)
        return { error: MESSAGES.damaged }
    let warning = ""
    if (track.photo.kind === "image") {
        if (photoRef >= 0) {
            track.photo.ref = photoRef
        } else {
            track.photo.kind = "none"
            warning = MESSAGES.photo
        }
    }
    return { track: track, warning: warning }
}
