// Gate nodes: dragging an element's open end. With the other end open too, the element pivots about its other end and
// stretches (a straight's or line's length, otherwise the lead at the dragged end) so the dragged end lands on the
// mouse. With the other end joined it only stretches, along its own direction, so the chain stays joined.
// Tests: tests/qml/tst_nodes.qml.
import * as Elements from "./elements.mjs"

const DEG = Math.PI / 180

// The setting a drag on `end` stretches.
export function stretchKey(el, end) {
    if (el.type === "straight" || el.type === "line")
        return "length"
    return end === "A" ? "leadIn" : "leadOut"
}

function turned(v, degrees) {
    const c = Math.cos(degrees * DEG)
    const s = Math.sin(degrees * DEG)
    return { x: v.x * c - v.y * s, y: v.x * s + v.y * c }
}

function dot(a, b) {
    return a.x * b.x + a.y * b.y
}

// Where `el` goes when its `end` is dragged to `point` (canvas metres): { x, y, rotation, key, value }. opts.pivot: the
// other end is open, so the element may turn as well as stretch. opts.step: degrees to snap the rotation to (0 for
// none), counted from the export frame's axis, whose angle on the canvas is opts.frameTheta.
export function drag(el, end, point, opts) {
    const other = end === "A" ? "B" : "A"
    const key = stretchKey(el, end)
    const def = Elements.PROPS[el.type].find(p => p.key === key)
    const keep = v => Elements.clamp(def, v).value
    const current = el.props[key]
    const g = Elements.geometry(el.type, el.props)
    // In the element's own frame the dragged end sits at c + L·u from the other end, L being the stretched setting:
    // stretching moves that end straight out along its own heading.
    const u = { x: Math.cos(g.ends[end].heading * DEG), y: Math.sin(g.ends[end].heading * DEG) }
    const c = { x: g.ends[end].x - g.ends[other].x - current * u.x, y: g.ends[end].y - g.ends[other].y - current * u.y }
    const fixed = Elements.endsWorld(el)[other]
    const want = { x: point.x - fixed.x, y: point.y - fixed.y }

    let rotation = el.rotation
    let value = current
    if (opts.pivot) {
        // |c + L·u| = |want|: the setting that puts the end as far from the other end as the mouse is.
        const cu = dot(c, u)
        const disc = cu * cu - dot(c, c) + dot(want, want)
        if (disc < 0) {
            value = keep(-cu)                    // the mouse is nearer than the end can come: as near as it gets
        } else {
            const far = -cu + Math.sqrt(disc)
            const close = -cu - Math.sqrt(disc)
            const closeFits = close >= def.min && close <= def.max
            value = closeFits && Math.abs(close - current) < Math.abs(far - current) ? close : keep(far)
        }
        const v = { x: c.x + value * u.x, y: c.y + value * u.y }
        rotation = Math.atan2(want.y, want.x) / DEG - Math.atan2(v.y, v.x) / DEG
        if (opts.step > 0) {
            const theta = opts.frameTheta || 0
            rotation = theta - Math.round(Elements.normalizeAngle(theta - rotation) / opts.step) * opts.step
        }
        rotation = Elements.normalizeAngle(rotation)
    }
    if (!opts.pivot || opts.step > 0) {
        // Stretch only, at this rotation: the mouse projected onto the line the end moves along.
        const q = turned(want, -rotation)
        value = keep(dot({ x: q.x - c.x, y: q.y - c.y }, u))
    }
    const props = Object.assign({}, el.props)
    props[key] = value
    const moved = Elements.endsWorld(Object.assign({}, el, { rotation: rotation, props: props }))[other]
    return { x: el.x + fixed.x - moved.x, y: el.y + fixed.y - moved.y, rotation: rotation, key: key, value: value }
}

// The nearest open end of another element within maxDistance (metres) of `point`, as { x, y }, or null. A node lands
// on it exactly but does not join it.
export function snapPoint(elements, id, point, maxDistance) {
    let best = null
    let bestDistance = maxDistance
    for (const el of elements) {
        if (el.id === id)
            continue
        const ends = Elements.endsWorld(el)
        for (const end of ["A", "B"]) {
            if (el.joins[end])
                continue
            const d = Math.hypot(ends[end].x - point.x, ends[end].y - point.y)
            if (d < bestDistance) {
                bestDistance = d
                best = { x: ends[end].x, y: ends[end].y }
            }
        }
    }
    return best
}
