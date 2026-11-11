// Editing several elements at once: the settings they share and the elements a box touches. Elements are plain data
// (see commands.mjs). Tests: tests/qml/tst_selection.qml.
import * as Elements from "./elements.mjs"

// The settings every one of `elements` shows now, in the first element's order, each with the value they all have
// or `mixed: true`: [{ def, value, mixed }].
export function sharedProps(elements) {
    if (elements.length === 0)
        return []
    const lists = elements.map(el => Elements.propList(el.type, el.props))
    return lists[0]
        .filter(def => lists.every(list => list.some(d => d.key === def.key)))
        .map(def => {
            const values = elements.map(el => el.props[def.key])
            const mixed = values.some(v => v !== values[0])
            return { def: def, value: mixed ? null : values[0], mixed: mixed }
        })
}

// Whether segment a-b meets the rectangle r ({ x0, y0, x1, y1 }, x0 <= x1, y0 <= y1): Liang-Barsky clipping.
function segmentMeetsRect(a, b, r) {
    let t0 = 0
    let t1 = 1
    const dx = b.x - a.x
    const dy = b.y - a.y
    for (const [p, q] of [[-dx, a.x - r.x0], [dx, r.x1 - a.x], [-dy, a.y - r.y0], [dy, r.y1 - a.y]]) {
        if (p === 0) {
            if (q < 0)
                return false
        } else {
            const t = q / p
            if (p < 0) {
                if (t > t1)
                    return false
                t0 = Math.max(t0, t)
            } else {
                if (t < t0)
                    return false
                t1 = Math.min(t1, t)
            }
        }
    }
    return true
}

// The ids of the elements whose band (as wide as the track) a box touches. Corners in canvas metres, either way round.
export function boxHits(elements, cornerA, cornerB) {
    const out = []
    for (const el of elements) {
        const h = Elements.reach(el)
        const r = { x0: Math.min(cornerA.x, cornerB.x) - h, y0: Math.min(cornerA.y, cornerB.y) - h,
                    x1: Math.max(cornerA.x, cornerB.x) + h, y1: Math.max(cornerA.y, cornerB.y) + h }
        const path = Elements.pathWorld(el)
        for (let i = 1; i < path.length; i++) {
            if (segmentMeetsRect(path[i - 1], path[i], r)) {
                out.push(el.id)
                break
            }
        }
    }
    return out
}
