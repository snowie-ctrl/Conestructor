// Joining track elements end to end, and keeping joined chains together after an edit. Ported from the prototype's
// qml/elements/Element.qml (snapToGate, propagateFromSelf, cascadeGate, chainLength, createMate, breakMate) and
// CanvasArea.findNearestGate at 2c79b60. Elements are plain data (see commands.mjs). Every function here except
// findSnap, placeToJoin and otherEnd changes the element objects in the array it is given, so callers pass a copy.
import * as Elements from "./elements.mjs"

export function otherEnd(end) {
    return end === "A" ? "B" : "A"
}

function byId(elements, id) {
    return elements.find(e => e.id === id)
}

// The nearest open end of another element within maxDistance (metres) of either end of `moving`, as
// { targetId, targetEnd, ownEnd, distance }, or null. An end joined to `moving` itself counts as open, so an
// element being dragged can stay where it snapped.
export function findSnap(elements, moving, maxDistance) {
    const own = Elements.endsWorld(moving)
    let best = null
    let bestDistance = maxDistance
    for (const el of elements) {
        if (el.id === moving.id)
            continue
        const ends = Elements.endsWorld(el)
        for (const targetEnd of ["A", "B"]) {
            const mate = el.joins[targetEnd]
            if (mate && mate.id !== moving.id)
                continue
            for (const ownEnd of ["A", "B"]) {
                const d = Math.hypot(own[ownEnd].x - ends[targetEnd].x, own[ownEnd].y - ends[targetEnd].y)
                if (d < bestDistance) {
                    bestDistance = d
                    best = { targetId: el.id, targetEnd: targetEnd, ownEnd: ownEnd, distance: d }
                }
            }
        }
    }
    return best
}

// Where `moving` must sit so that its `ownEnd` meets `target`'s `targetEnd`, facing the opposite way.
export function placeToJoin(moving, ownEnd, target, targetEnd) {
    const goal = Elements.endsWorld(target)[targetEnd]
    const ownLocalHeading = Elements.geometry(moving.type, moving.props).ends[ownEnd].heading
    const rotation = Elements.normalizeAngle(goal.heading + 180 - ownLocalHeading)
    const own = Elements.endsWorld(Object.assign({}, moving, { rotation: rotation }))[ownEnd]
    return { x: moving.x + goal.x - own.x, y: moving.y + goal.y - own.y, rotation: rotation }
}

export function unjoin(elements, id, end) {
    const el = byId(elements, id)
    const mate = el.joins[end]
    if (!mate)
        return
    const other = byId(elements, mate.id)
    if (other)
        other.joins[mate.end] = null
    el.joins[end] = null
}

export function unjoinAll(elements, id) {
    unjoin(elements, id, "A")
    unjoin(elements, id, "B")
}

export function join(elements, aId, aEnd, bId, bEnd) {
    unjoin(elements, aId, aEnd)
    unjoin(elements, bId, bEnd)
    byId(elements, aId).joins[aEnd] = { id: bId, end: bEnd }
    byId(elements, bId).joins[bEnd] = { id: aId, end: aEnd }
}

// How many elements hang off `end` of `el`, not counting any already in `visited`.
function chainLength(elements, el, end, visited) {
    const mate = el.joins[end]
    if (!mate || visited.indexOf(mate.id) >= 0)
        return 0
    visited.push(mate.id)
    return 1 + chainLength(elements, byId(elements, mate.id), otherEnd(mate.end), visited)
}

function moveToMate(elements, el, end) {
    const mate = el.joins[end]
    Object.assign(el, placeToJoin(el, end, byId(elements, mate.id), mate.end))
}

// Moves everything joined beyond `end` of `el` so each element meets the one before it.
function cascade(elements, el, end, visited) {
    const mate = el.joins[end]
    if (!mate || visited.indexOf(mate.id) >= 0)
        return
    const other = byId(elements, mate.id)
    Object.assign(other, placeToJoin(other, mate.end, el, end))
    visited.push(other.id)
    cascade(elements, other, otherEnd(mate.end), visited)
}

// After element `id` changed shape: it moves to meet its neighbour on the longer side of the chain, and the
// shorter side follows it.
export function settle(elements, id) {
    const self = byId(elements, id)
    const hasA = self.joins.A !== null
    const hasB = self.joins.B !== null
    if (!hasA && !hasB)
        return
    if (hasA && hasB) {
        const anchor = chainLength(elements, self, "A", [id]) >= chainLength(elements, self, "B", [id]) ? "A" : "B"
        moveToMate(elements, self, anchor)
        cascade(elements, self, otherEnd(anchor), [id])
    } else {
        moveToMate(elements, self, hasA ? "A" : "B")
    }
}

// Re-glues every joined chain from its first element in the list (which stays where it is).
export function glueAll(elements) {
    const done = []
    for (const el of elements) {
        if (done.indexOf(el.id) >= 0 || (!el.joins.A && !el.joins.B))
            continue
        const visited = [el.id]
        cascade(elements, el, "A", visited)
        cascade(elements, el, "B", visited)
        for (const id of visited)
            done.push(id)
    }
}
