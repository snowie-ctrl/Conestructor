import QtQuick
import QtTest
import "../../qml/logic/commands.mjs" as Commands
import "../../qml/logic/elements.mjs" as Elements
import "../../qml/logic/snapping.mjs" as Snapping

TestCase {
    name: "Snapping"

    function el(id, type, props, x, y, rotation) {
        return { id: id, type: type, x: x || 0, y: y || 0, rotation: rotation || 0,
                 props: Object.assign(Elements.defaults(type), props || {}), joins: { A: null, B: null } }
    }

    // Ends meet, facing opposite ways.
    function joinedWell(a, aEnd, b, bEnd) {
        const pa = Elements.endsWorld(a)[aEnd]
        const pb = Elements.endsWorld(b)[bEnd]
        const turn = (((pa.heading - pb.heading) % 360) + 360) % 360
        return Math.hypot(pa.x - pb.x, pa.y - pb.y) < 1e-9 && Math.abs(turn - 180) < 1e-9
    }

    // Elements joined B to A in order, each placed against the one before.
    function chain(specs) {
        const list = []
        for (const s of specs) {
            const e = el(s[0], s[1], s[2], 0, 0, 0)
            if (list.length > 0) {
                const prev = list[list.length - 1]
                Object.assign(e, Snapping.placeToJoin(e, "A", prev, "B"))
                list.push(e)
                Snapping.join(list, prev.id, "B", e.id, "A")
            } else {
                list.push(e)
            }
        }
        return list
    }

    function test_aStraightAfterAStraightLandsTwentyMetresOn() {
        const a = el("a", "straight", {}, 0, 0, 0)
        const b = el("b", "straight", {}, 50, 50, 33)
        const placed = Snapping.placeToJoin(b, "A", a, "B")
        fuzzyCompare(placed.x, 20, 1e-9)
        fuzzyCompare(placed.y, 0, 1e-9)
        compare(placed.rotation, 0)
    }

    function test_placeToJoinMeetsEndToEnd_data() {
        return [
            { tag: "straight onto a rotated straight", target: ["straight", {}, 0, 0, 90], targetEnd: "B",
              moving: ["straight", {}, 50, 50, 33], ownEnd: "A" },
            { tag: "slalom after a hairpin", target: ["turn", {}, 10, 10, 20], targetEnd: "B",
              moving: ["slalom", {}, 0, 0, 0], ownEnd: "A" },
            { tag: "chicane entered at its exit", target: ["straight", {}, 0, 0, 0], targetEnd: "B",
              moving: ["chicane", {}, 0, 0, 0], ownEnd: "B" },
            { tag: "onto the entry of a left turn", target: ["turn", { direction: "left", angle: 75 }, 0, 0, -40],
              targetEnd: "A", moving: ["straight", {}, 0, 0, 0], ownEnd: "A" }
        ]
    }

    function test_placeToJoinMeetsEndToEnd(row) {
        const target = el("t", row.target[0], row.target[1], row.target[2], row.target[3], row.target[4])
        const moving = el("m", row.moving[0], row.moving[1], row.moving[2], row.moving[3], row.moving[4])
        const placed = Object.assign({}, moving, Snapping.placeToJoin(moving, row.ownEnd, target, row.targetEnd))
        verify(joinedWell(placed, row.ownEnd, target, row.targetEnd))
    }

    function test_findSnapFindsTheNearestOpenEnd() {
        const a = el("a", "straight", {}, 0, 0, 0)          // B at (10, 0)
        const b = el("b", "straight", {}, 20.5, 0.5, 0)     // A at (10.5, 0.5)
        const snap = Snapping.findSnap([a, b], b, 1)
        compare(snap.targetId, "a")
        compare(snap.targetEnd, "B")
        compare(snap.ownEnd, "A")
        compare(Snapping.findSnap([a, b], b, 0.5), null)
    }

    function test_findSnapSkipsEndsJoinedToSomethingElse() {
        const a = el("a", "straight", {}, 0, 0, 0)
        const b = el("b", "straight", {}, 20.5, 0.5, 0)
        a.joins.B = { id: "c", end: "A" }
        compare(Snapping.findSnap([a, b], b, 1), null)
        a.joins.B = { id: "b", end: "A" }
        compare(Snapping.findSnap([a, b], b, 1).targetId, "a")
    }

    function test_findSnapIgnoresTheMovingElement() {
        const b = el("b", "straight", {}, 0, 0, 0)
        compare(Snapping.findSnap([b], b, 100), null)
    }

    function test_joinAndUnjoin() {
        const list = [el("a", "straight"), el("b", "straight")]
        Snapping.join(list, "a", "B", "b", "A")
        compare(JSON.stringify(list[0].joins.B), JSON.stringify({ id: "b", end: "A" }))
        compare(JSON.stringify(list[1].joins.A), JSON.stringify({ id: "a", end: "B" }))
        Snapping.unjoinAll(list, "b")
        compare(list[0].joins.B, null)
        compare(list[1].joins.A, null)
    }

    function test_joiningAnEndThatWasJoinedFreesItsOldPartner() {
        const list = [el("a", "straight"), el("b", "straight"), el("c", "straight")]
        Snapping.join(list, "a", "B", "b", "A")
        Snapping.join(list, "c", "A", "a", "B")
        compare(list[1].joins.A, null)
        compare(list[0].joins.B.id, "c")
    }

    function test_settleKeepsAChainGluedAfterAnEdit() {
        const list = chain([["a", "straight", {}], ["b", "straight", {}], ["c", "turn", {}]])
        const aBefore = JSON.stringify(list[0])
        list[1].props.length = 30
        Snapping.settle(list, "b")
        verify(joinedWell(list[0], "B", list[1], "A"), "a-b")
        verify(joinedWell(list[1], "B", list[2], "A"), "b-c")
        compare(JSON.stringify(list[0]), aBefore)
    }

    function test_settleMovesTheShorterSide() {
        // b sits between a (one element) and c-d (two): the longer side stays put.
        const list = chain([["a", "straight", {}], ["b", "straight", {}], ["c", "straight", {}], ["d", "straight", {}]])
        const cBefore = JSON.stringify(list[2])
        list[1].props.length = 5
        Snapping.settle(list, "b")
        compare(JSON.stringify(list[2]), cBefore)
        verify(joinedWell(list[0], "B", list[1], "A"), "a-b")
        verify(joinedWell(list[1], "B", list[2], "A"), "b-c")
    }

    function test_settleWithOneNeighbourMovesOnlyItself() {
        const list = chain([["a", "straight", {}], ["b", "slalom", {}]])
        const aBefore = JSON.stringify(list[0])
        list[1].props.leadIn = 15
        Snapping.settle(list, "b")
        compare(JSON.stringify(list[0]), aBefore)
        verify(joinedWell(list[0], "B", list[1], "A"))
    }

    function test_glueAllRejoinsChainsAfterScaling() {
        const list = chain([["a", "straight", {}], ["b", "turn", {}], ["c", "chicane", {}]])
        list.push(el("lonely", "straight", {}, 70, 70, 10))
        for (const e of list) { e.x *= 0.5; e.y *= 0.5 }
        const lonely = JSON.stringify(list[3])
        const a = JSON.stringify(list[0])
        Snapping.glueAll(list)
        verify(joinedWell(list[0], "B", list[1], "A"), "a-b")
        verify(joinedWell(list[1], "B", list[2], "A"), "b-c")
        compare(JSON.stringify(list[0]), a)
        compare(JSON.stringify(list[3]), lonely)
    }

    function test_aClosedLoopSettles() {
        const turn = { angle: 90, radius: 6, leadIn: 0, leadOut: 0 }
        const list = chain([["a", "turn", turn], ["b", "turn", turn], ["c", "turn", turn], ["d", "turn", turn]])
        Snapping.join(list, "d", "B", "a", "A")
        list[1].props.radius = 8
        Snapping.settle(list, "b")       // must return, not walk the ring for ever
        Snapping.glueAll(list)
        // A ring with one bigger turn cannot close, so one joint (b's entry) stays open; the walk from a glues the rest.
        verify(joinedWell(list[3], "B", list[0], "A"), "d-a")
        verify(joinedWell(list[2], "B", list[3], "A"), "c-d")
        verify(joinedWell(list[1], "B", list[2], "A"), "b-c")
    }

    // e1 and e2 joined along the screen at y 5 (0 to 40 m); e3 alone, pointing down the screen from (70, 20).
    function groupTrack() {
        const s = new Commands.UndoStack()
        let t = Commands.run(s, Commands.emptyTrack(), "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 })
        t = Commands.run(s, t, "add", { type: "straight", x: 10, y: 5 })
        t = Commands.run(s, t, "add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } })
        t = Commands.run(s, t, "add", { type: "straight", x: 70, y: 30, rotation: 90 })
        return t
    }

    function shifted(t, ids, dx, dy) {
        return ids.map(id => {
            const e = Commands.clone(t).elements.find(x => x.id === id)
            e.x += dx
            e.y += dy
            return e
        })
    }

    // Ends meet within 1e-6 m, facing opposite ways (a turned group carries a little rounding).
    function meetWell(a, aEnd, b, bEnd) {
        const pa = Elements.endsWorld(a)[aEnd]
        const pb = Elements.endsWorld(b)[bEnd]
        const turn = (((pa.heading - pb.heading) % 360) + 360) % 360
        return Math.hypot(pa.x - pb.x, pa.y - pb.y) < 1e-6 && Math.abs(turn - 180) < 1e-6
    }

    function test_aGroupSnapsAsOne() {
        const t = groupTrack()
        const group = shifted(t, ["e1", "e2"], 25, 5)
        const s = Snapping.findGroupSnap(t.elements, group, 15)
        compare(s.ownId, "e2")
        compare(s.ownEnd, "B")
        compare(s.targetId, "e3")
        compare(s.targetEnd, "A")
        const e3 = t.elements.find(e => e.id === "e3")
        const placed = Snapping.groupToJoin(group, s.ownId, s.ownEnd, e3, s.targetEnd)
        const p1 = placed.find(e => e.id === "e1")
        const p2 = placed.find(e => e.id === "e2")
        verify(meetWell(p2, "B", e3, "A"), "the open end of the group meets e3")
        verify(meetWell(p1, "B", p2, "A"), "the join inside the group still meets")
        compare(Math.round(p2.rotation), 90)
        compare(group[1].x, t.elements[1].x + 25)     // the group passed in is not changed
    }

    function test_endsJoinedInsideTheGroupDoNotSnap() {
        const lone = Commands.clone(groupTrack())
        lone.elements = lone.elements.filter(e => e.id !== "e3")
        compare(Snapping.findGroupSnap(lone.elements, shifted(lone, ["e1", "e2"], 1, 1), 15), null)
    }

    // A full loop with no leads has both ends on one spot: it must never join itself.
    function test_aLoopNeverJoinsItself() {
        const loop = el("e1", "turn", { angle: 360, leadIn: 0, leadOut: 0 })
        const ends = Elements.endsWorld(loop)
        verify(Math.hypot(ends.A.x - ends.B.x, ends.A.y - ends.B.y) < 1e-6, "both ends on one spot")
        compare(Snapping.findSnap([loop], loop, 5), null)
        Snapping.joinTouching([loop], "e1")
        compare(loop.joins.A, null)
        compare(loop.joins.B, null)
    }
}
