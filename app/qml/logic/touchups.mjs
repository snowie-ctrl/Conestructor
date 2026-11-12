// Touch-ups: hand changes to placed cones before the track is saved or uploaded (delete, move, standing or leaning, where
// a leaning cone points, add). They belong to one round of Place cones. The first touch-up freezes the placed cones into
// the track as `touchUps`; while it exists the track is locked (commands.mjs) so the list never has to be matched to a
// changed track. touchUps = { placed, cones: [{ type, x, y, heading, element, edited }] }: `placed` is how many cones
// were frozen; positions in canvas metres and headings clockwise on screen, like elements. Tests:
// tests/qml/tst_touchups.qml.
import * as Frame from "./frame.mjs"
import * as Post from "./postprocess.mjs"

// Half a cone's footprint: a standing cone's base is 10.5 in across; a leaning cone is 18 in long.
export const STANDING_RADIUS = 10.5 / 2 * 0.0254
export const LEANING_RADIUS = 18 / 2 * 0.0254

export function radius(cone) {
    return cone.type === "leaning" ? LEANING_RADIUS : STANDING_RADIUS
}

function copy(c) {
    return { type: c.type, x: c.x, y: c.y, heading: c.heading, element: c.element, edited: c.edited === true }
}

// The placed cones as touch-ups start from, or null when the track cannot be processed.
export function freeze(track) {
    const result = Post.run(track)
    if (result.error)
        return null
    return { placed: result.canvasCones.length, cones: result.canvasCones.map(copy) }
}

function valid(u, indices) {
    return indices.filter(i => i >= 0 && i < u.cones.length)
}

// Each change returns new touch-ups and leaves `u` as it was. `indices` are positions in u.cones.
export function removeCones(u, indices) {
    const gone = valid(u, indices)
    return { placed: u.placed, cones: u.cones.filter((c, i) => gone.indexOf(i) < 0).map(copy) }
}

function changed(u, indices, change) {
    const which = valid(u, indices)
    return { placed: u.placed,
             cones: u.cones.map((c, i) => which.indexOf(i) < 0 ? copy(c) : Object.assign(copy(c), change, { edited: true })) }
}

export function moveCone(u, index, x, y) {
    return changed(u, [index], { x: x, y: y })
}

// Only cones of the other type change; a cone made leaning keeps its heading.
export function setType(u, indices, type) {
    return changed(u, valid(u, indices).filter(i => u.cones[i].type !== type), { type: type })
}

export function pointCone(u, index, heading) {
    return changed(u, [index], { heading: heading })
}

// A standing cone added by hand, after every other cone in the driving order.
export function addCone(u, x, y) {
    return { placed: u.placed,
             cones: u.cones.map(copy).concat([{ type: "standing", x: x, y: y, heading: 0, element: null, edited: true }]) }
}

// How many changes the touch-ups hold: cones deleted, plus cones moved, retyped, turned or added (0 for none).
export function changes(u) {
    if (!u)
        return 0
    const kept = u.cones.filter(c => c.element !== null).length
    return (u.placed - kept) + u.cones.filter(c => c.edited).length
}

// The nearest cone whose footprint, grown by `extra` metres, covers p (canvas metres); -1 when none does.
export function coneAt(cones, p, extra) {
    let best = -1
    let bestDistance = Infinity
    cones.forEach((c, i) => {
        const d = Math.hypot(c.x - p.x, c.y - p.y)
        if (d <= radius(c) + extra && d < bestDistance) {
            best = i
            bestDistance = d
        }
    })
    return best
}

// The cones inside a box (corners in canvas metres, either way round).
export function inBox(cones, a, b) {
    const x0 = Math.min(a.x, b.x)
    const x1 = Math.max(a.x, b.x)
    const y0 = Math.min(a.y, b.y)
    const y1 = Math.max(a.y, b.y)
    const out = []
    cones.forEach((c, i) => {
        if (c.x >= x0 && c.x <= x1 && c.y >= y0 && c.y <= y1)
            out.push(i)
    })
    return out
}

// What Place cones shows and the file holds while touched up, in Post.run's shape: { cones (export frame),
// canvasCones, targetDistance }, each cone with its index and `edited`; or { error } when the track cannot be processed.
export function result(track) {
    const error = Post.check(track)
    if (error)
        return { error: error }
    const frame = Frame.makeFrame(track.targets.origin, track.targets.direction, track.photo.metresPerPixel)
    const canvasCones = track.touchUps.cones.map((c, index) => Object.assign({ index: index }, copy(c)))
    const cones = canvasCones.map(c => {
        const q = Frame.toFrame(frame, c)
        return { index: c.index, type: c.type, x: q.x, y: q.y, heading: Frame.headingToFrame(frame, c.heading),
                 element: c.element, edited: c.edited }
    })
    return { cones: cones, canvasCones: canvasCones, targetDistance: frame.distance }
}
