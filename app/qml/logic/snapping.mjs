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

const TOUCH_METRES = 1e-6

function facesAway(a, b) {
    const turn = (((a.heading - b.heading) % 360) + 360) % 360
    return Math.abs(turn - 180) < 1e-6
}

// Joins every open end of element `id` that already meets another element's open end, facing the opposite way.
// After a snap this restores the far side too: an element dropped back into its gap joins both neighbours.
export function joinTouching(elements, id) {
    const self = byId(elements, id)
    for (const ownEnd of ["A", "B"]) {
        if (self.joins[ownEnd])
            continue
        const own = Elements.endsWorld(self)[ownEnd]
        for (const el of elements) {
            if (el.id === id || self.joins[ownEnd])
                continue
            const ends = Elements.endsWorld(el)
            for (const end of ["A", "B"]) {
                if (!el.joins[end] && Math.hypot(own.x - ends[end].x, own.y - ends[end].y) < TOUCH_METRES
                        && facesAway(own, ends[end])) {
                    join(elements, id, ownEnd, el.id, end)
                    break
                }
            }
        }
    }
}

// Unjoins every joint whose ends no longer meet (a closed loop that an edit made impossible to close), so the
// canvas shows the gap as open ends instead of a join that is not there.
export function unjoinApart(elements) {
    for (const el of elements) {
        for (const end of ["A", "B"]) {
            const mate = el.joins[end]
            if (!mate)
                continue
            const other = byId(elements, mate.id)
            const a = Elements.endsWorld(el)[end]
            const b = other ? Elements.endsWorld(other)[mate.end] : null
            if (!b || Math.hypot(a.x - b.x, a.y - b.y) >= TOUCH_METRES)
                unjoin(elements, el.id, end)
        }
    }
}

// Every element joined to `id`, directly or through others; `id` first.
export function chainOf(elements, id) {
    const out = [id]
    for (let i = 0; i < out.length; i++) {
        const el = byId(elements, out[i])
        for (const end of ["A", "B"]) {
            const mate = el.joins[end]
            if (mate && out.indexOf(mate.id) < 0)
                out.push(mate.id)
        }
    }
    return out
}

// Turns elements `ids` as one about `pivot` (canvas metres) by `degrees` (clockwise on screen). Changes them.
export function turnAbout(elements, ids, pivot, degrees) {
    const r = degrees * Math.PI / 180
    const c = Math.cos(r)
    const s = Math.sin(r)
    for (const id of ids) {
        const el = byId(elements, id)
        const dx = el.x - pivot.x
        const dy = el.y - pivot.y
        el.x = pivot.x + dx * c - dy * s
        el.y = pivot.y + dx * s + dy * c
        el.rotation = Elements.normalizeAngle(el.rotation + degrees)
    }
}

// The nearest pairing, within maxDistance, of an open end of `group` (elements as they would land) with an open end of
// an element outside it: { ownId, ownEnd, targetId, targetEnd, distance } or null. Ends joined inside the group are not
// open; an outside end joined to a group member counts as open (the drag unjoins it).
export function findGroupSnap(elements, group, maxDistance) {
    const ids = group.map(g => g.id)
    let best = null
    let bestDistance = maxDistance
    for (const g of group) {
        const own = Elements.endsWorld(g)
        for (const ownEnd of ["A", "B"]) {
            const mate = g.joins[ownEnd]
            if (mate && ids.indexOf(mate.id) >= 0)
                continue
            for (const el of elements) {
                if (ids.indexOf(el.id) >= 0)
                    continue
                const ends = Elements.endsWorld(el)
                for (const targetEnd of ["A", "B"]) {
                    const theirs = el.joins[targetEnd]
                    if (theirs && ids.indexOf(theirs.id) < 0)
                        continue
                    const d = Math.hypot(own[ownEnd].x - ends[targetEnd].x, own[ownEnd].y - ends[targetEnd].y)
                    if (d < bestDistance) {
                        bestDistance = d
                        best = { ownId: g.id, ownEnd: ownEnd, targetId: el.id, targetEnd: targetEnd, distance: d }
                    }
                }
            }
        }
    }
    return best
}

// Copies of `group`, turned and shifted as one so that `ownEnd` of member `ownId` meets `target`'s `targetEnd`,
// facing the opposite way.
export function groupToJoin(group, ownId, ownEnd, target, targetEnd) {
    const own = group.find(g => g.id === ownId)
    const placed = placeToJoin(own, ownEnd, target, targetEnd)
    const copies = group.map(g => Object.assign({}, g))
    turnAbout(copies, copies.map(c => c.id), { x: own.x, y: own.y }, Elements.normalizeAngle(placed.rotation - own.rotation))
    const dx = placed.x - own.x
    const dy = placed.y - own.y
    for (const c of copies) {
        c.x += dx
        c.y += dy
    }
    Object.assign(copies.find(c => c.id === ownId), placed)
    return copies
}
