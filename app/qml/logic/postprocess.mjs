// Post-processing: every cone of the track, in driving order, in the export frame. Ported from the prototype's
// qml/PostProcessor.qml and qml/elements/ConeUtils.js at 2c79b60: cones per element, duplicates at joins removed.
// Since part 2, joined chains are walked the way most of their elements point and separate chains are stitched by the
// nearest start. Since part 3, cones on another element's driving surface are left out before duplicates are merged,
// and line cones (walls) come after the course. Tests: tests/qml/tst_postprocess.qml and the port check (tests/qml/tst_portcheck.qml).
import * as Elements from "./elements.mjs"
import * as Frame from "./frame.mjs"
import { FOOT } from "./units.mjs"

export const DEDUPE_METRES = 0.4 * FOOT
export const MIN_TARGET_DISTANCE = 1
export const MESSAGES = {
    noRuler: "Place the ruler on something of known length, then set its real length",
    noLength: "Set the ruler's real length",
    noOrigin: "Place the Origin target",
    noDirection: "Place the Direction target",
    tooClose: "Origin and Direction are closer than 1 m: move Direction further away",
    noTrack: "Nothing to process yet: add some track"
}

// What stops post-processing, or null when the track is ready.
export function check(track) {
    const scale = track.photo.metresPerPixel
    if (!track.ruler)
        return { message: MESSAGES.noRuler, target: null }
    if (!(scale > 0))
        return { message: MESSAGES.noLength, target: { kind: "ruler" } }
    if (!track.targets.origin)
        return { message: MESSAGES.noOrigin, target: null }
    if (!track.targets.direction)
        return { message: MESSAGES.noDirection, target: null }
    const frame = Frame.makeFrame(track.targets.origin, track.targets.direction, scale)
    if (!frame || frame.distance < MIN_TARGET_DISTANCE)
        return { message: MESSAGES.tooClose, target: { kind: "direction" } }
    if (track.elements.length === 0)
        return { message: MESSAGES.noTrack, target: null }
    return null
}

// Each element's cones in canvas metres, in the element's own order (entry A to exit B), each naming its element.
export function coneGroups(elements) {
    return elements.map(el => ({ id: el.id, cones: Elements.conesWorld(el).map(c => Object.assign(c, { element: el.id })) }))
}

// A cone more than this far inside any element's band is on the driving surface and is left out.
export const ON_TRACK_METRES = 0.15

// The bands of the driven elements (lines have none): centreline in canvas metres, half the track width, and a box
// around the band for a quick first test.
function bands(elements) {
    return elements.filter(e => e.type !== "line").map(e => {
        const path = Elements.pathWorld(e)
        const half = e.props.trackWidth / 2
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
        for (const p of path) {
            x0 = Math.min(x0, p.x); y0 = Math.min(y0, p.y)
            x1 = Math.max(x1, p.x); y1 = Math.max(y1, p.y)
        }
        return { path: path, half: half, x0: x0 - half, y0: y0 - half, x1: x1 + half, y1: y1 + half }
    })
}

function onTrack(cone, band) {
    if (cone.x < band.x0 || cone.x > band.x1 || cone.y < band.y0 || cone.y > band.y1)
        return false
    const limit = band.half - ON_TRACK_METRES
    for (let i = 1; i < band.path.length; i++)
        if (Elements.pointSegmentDistance(cone, band.path[i - 1], band.path[i]) < limit)
            return true
    return false
}

// Leaves out every cone (a line's too) on the driving surface of any element, its own or another's: folds, a loop over
// its own leads, overlaps and crossings. Cones on a band's edge stay. Changes `groups`.
export function removeOnTrack(groups, elements) {
    const list = bands(elements)
    for (const g of groups)
        g.cones = g.cones.filter(c => !list.some(b => onTrack(c, b)))
}

// Removes the later of any two cones closer than epsilon (they meet at joins). Changes `groups`.
export function dedupe(groups, epsilon) {
    const flat = []
    groups.forEach((g, gi) => g.cones.forEach(c => flat.push({ group: gi, cone: c })))
    const removed = new Array(flat.length).fill(false)
    for (let i = 0; i < flat.length; i++) {
        if (removed[i])
            continue
        for (let j = i + 1; j < flat.length; j++) {
            if (removed[j])
                continue
            const dx = flat[i].cone.x - flat[j].cone.x
            const dy = flat[i].cone.y - flat[j].cone.y
            if (Math.sqrt(dx * dx + dy * dy) < epsilon)
                removed[j] = true
        }
    }
    groups.forEach((g, gi) => {
        g.cones = flat.filter((f, k) => f.group === gi && !removed[k]).map(f => f.cone)
    })
}

function byId(elements, id) {
    return elements.find(e => e.id === id)
}

// One joined chain from `start`, entered at `enter`: [{ id, forward }] in walking order (forward = entered at A).
function walkSteps(elements, start, enter) {
    const steps = []
    const seen = []
    let current = start
    let at = enter
    while (current && seen.indexOf(current.id) < 0) {
        seen.push(current.id)
        steps.push({ id: current.id, forward: at === "A" })
        const mate = current.joins[at === "A" ? "B" : "A"]
        if (mate && seen.indexOf(mate.id) < 0) {
            current = byId(elements, mate.id)
            at = mate.end
        } else {
            current = null
        }
    }
    return steps
}

// The same chain walked the other way. A closed loop keeps its first element first.
function turnedAround(steps, loop) {
    const order = loop ? [steps[0]].concat(steps.slice(1).reverse()) : steps.slice().reverse()
    return order.map(s => ({ id: s.id, forward: !s.forward }))
}

// Walked the way most of its elements point; on a tie, the way its earliest element in the list points.
function oriented(elements, steps, loop) {
    const forward = steps.filter(s => s.forward).length
    const backward = steps.length - forward
    let turn = backward > forward
    if (backward === forward) {
        const index = id => elements.findIndex(e => e.id === id)
        const earliest = steps.reduce((a, b) => index(b.id) < index(a.id) ? b : a)
        turn = !earliest.forward
    }
    return turn ? turnedAround(steps, loop) : steps
}

// Every joined chain in driving order: chains with an open end in the order their first element appears in the list,
// then closed loops from their earliest element.
export function chains(elements) {
    const visited = []
    const out = []
    for (const el of elements) {
        if (el.type === "line" || visited.indexOf(el.id) >= 0 || (el.joins.A !== null && el.joins.B !== null))
            continue
        const steps = walkSteps(elements, el, el.joins.A === null ? "A" : "B")
        steps.forEach(s => visited.push(s.id))
        out.push(oriented(elements, steps, false))
    }
    for (const el of elements) {
        if (el.type === "line" || visited.indexOf(el.id) >= 0)
            continue
        const steps = walkSteps(elements, el, "A")
        steps.forEach(s => visited.push(s.id))
        out.push(oriented(elements, steps, true))
    }
    return out
}

// The elements driven exit to entry: against the rest of their chain.
export function backwards(elements) {
    const out = []
    for (const steps of chains(elements))
        for (const s of steps)
            if (!s.forward)
                out.push(s.id)
    return out
}

// Cone lists, one per joined chain, in driving order.
export function buildChains(elements, groups) {
    const out = []
    for (const steps of chains(elements)) {
        const cones = []
        for (const s of steps) {
            const own = groups.find(g => g.id === s.id).cones
            if (s.forward)
                for (const c of own) cones.push(c)
            else
                for (let i = own.length - 1; i >= 0; i--) cones.push(own[i])
        }
        if (cones.length > 0)
            out.push(cones)
    }
    return out
}

function distance(a, b) {
    return Math.hypot(a.x - b.x, a.y - b.y)
}

// Chains joined into one list: from the first, the next chain is the one whose start is nearest the end so far.
// Chains are never reversed: each is driven the way its arrows point.
export function stitch(chains) {
    if (chains.length === 0)
        return []
    const remaining = chains.slice()
    let ordered = remaining.shift().slice()
    while (remaining.length > 0) {
        const end = ordered[ordered.length - 1]
        let best = 0
        for (let i = 1; i < remaining.length; i++)
            if (distance(end, remaining[i][0]) < distance(end, remaining[best][0]))
                best = i
        ordered = ordered.concat(remaining.splice(best, 1)[0])
    }
    return ordered
}

// Line cones (walls and boundaries) after the course: one line at a time, the nearest first, each from whichever of
// its ends is nearer the last cone so far.
export function appendLines(ordered, lines, groups) {
    const rows = lines.map(l => groups.find(g => g.id === l.id).cones).filter(r => r.length > 0)
    let out = ordered.slice()
    while (rows.length > 0) {
        const last = out.length > 0 ? out[out.length - 1] : null
        let best = 0
        let flip = false
        if (last) {
            let bestDistance = Infinity
            rows.forEach((r, i) => {
                const toStart = distance(last, r[0])
                const toEnd = distance(last, r[r.length - 1])
                if (toStart < bestDistance) {
                    bestDistance = toStart
                    best = i
                    flip = false
                }
                if (toEnd < bestDistance) {
                    bestDistance = toEnd
                    best = i
                    flip = true
                }
            })
        }
        const row = rows.splice(best, 1)[0]
        out = out.concat(flip ? row.slice().reverse() : row)
    }
    return out
}

export function run(track) {
    const error = check(track)
    if (error)
        return { error: error }
    const frame = Frame.makeFrame(track.targets.origin, track.targets.direction, track.photo.metresPerPixel)
    const groups = coneGroups(track.elements)
    removeOnTrack(groups, track.elements)
    dedupe(groups, DEDUPE_METRES)
    const course = stitch(buildChains(track.elements, groups))
    const ordered = appendLines(course, track.elements.filter(e => e.type === "line"), groups)
    const cones = []
    const canvasCones = []
    ordered.forEach((c, index) => {
        const q = Frame.toFrame(frame, c)
        cones.push({ index: index, type: c.type, x: q.x, y: q.y, heading: Frame.headingToFrame(frame, c.heading),
                     element: c.element })
        canvasCones.push({ index: index, type: c.type, x: c.x, y: c.y, heading: c.heading, element: c.element })
    })
    return { cones: cones, canvasCones: canvasCones, targetDistance: frame.distance }
}
