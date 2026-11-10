// Post-processing: every cone of the track, in driving order, in the export frame. Ported from the prototype's
// qml/PostProcessor.qml and qml/elements/ConeUtils.js at 2c79b60: cones per element, duplicates at joins removed,
// joined chains walked from an open end, separate chains stitched nearest end first. Tests:
// tests/qml/tst_postprocess.qml and the port check (tests/qml/tst_portcheck.qml).
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

// Each element's cones in canvas metres, in the element's own order (entry A to exit B).
export function coneGroups(elements) {
    return elements.map(el => ({ id: el.id, cones: Elements.conesWorld(el) }))
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

function walk(elements, groups, start, startEnd, visited) {
    const out = []
    let current = start
    let enter = startEnd
    while (current && visited.indexOf(current.id) < 0) {
        visited.push(current.id)
        const cones = groups.find(g => g.id === current.id).cones
        if (enter === "B")
            for (let i = cones.length - 1; i >= 0; i--) out.push(cones[i])
        else
            for (const c of cones) out.push(c)
        const exit = enter === "A" ? "B" : "A"
        const mate = current.joins[exit]
        if (mate && visited.indexOf(mate.id) < 0) {
            current = elements.find(e => e.id === mate.id)
            enter = mate.end
        } else {
            current = null
        }
    }
    return out
}

// Cone lists, one per joined chain: chains with an open end are walked from it; closed loops from their first element.
export function buildChains(elements, groups) {
    const visited = []
    const chains = []
    for (const el of elements) {
        if (visited.indexOf(el.id) >= 0)
            continue
        const hasA = el.joins.A !== null
        const hasB = el.joins.B !== null
        if (hasA && hasB)
            continue
        const cones = walk(elements, groups, el, hasA ? "B" : "A", visited)
        if (cones.length > 0)
            chains.push(cones)
    }
    for (const el of elements) {
        if (visited.indexOf(el.id) >= 0)
            continue
        const cones = walk(elements, groups, el, "A", visited)
        if (cones.length > 0)
            chains.push(cones)
    }
    return chains
}

function distance(a, b) {
    return Math.hypot(a.x - b.x, a.y - b.y)
}

// Chains joined into one list: from the first, each next chain is whichever start or end is nearest, reversed if
// its end was nearer.
export function stitch(chains) {
    if (chains.length === 0)
        return []
    const remaining = chains.slice()
    let ordered = remaining.shift().slice()
    while (remaining.length > 0) {
        const end = ordered[ordered.length - 1]
        let best = -1
        let reversed = false
        let bestDistance = Infinity
        remaining.forEach((chain, i) => {
            const dStart = distance(end, chain[0])
            const dEnd = distance(end, chain[chain.length - 1])
            if (dStart < bestDistance) { bestDistance = dStart; best = i; reversed = false }
            if (dEnd < bestDistance) { bestDistance = dEnd; best = i; reversed = true }
        })
        const chosen = remaining.splice(best, 1)[0]
        ordered = ordered.concat(reversed ? chosen.slice().reverse() : chosen)
    }
    return ordered
}

export function run(track) {
    const error = check(track)
    if (error)
        return { error: error }
    const frame = Frame.makeFrame(track.targets.origin, track.targets.direction, track.photo.metresPerPixel)
    const groups = coneGroups(track.elements)
    dedupe(groups, DEDUPE_METRES)
    const ordered = stitch(buildChains(track.elements, groups))
    const cones = []
    const canvasCones = []
    ordered.forEach((c, index) => {
        const q = Frame.toFrame(frame, c)
        cones.push({ index: index, type: c.type, x: q.x, y: q.y, heading: Frame.headingToFrame(frame, c.heading) })
        canvasCones.push({ index: index, type: c.type, x: c.x, y: c.y, heading: c.heading })
    })
    return { cones: cones, canvasCones: canvasCones, targetDistance: frame.distance }
}
