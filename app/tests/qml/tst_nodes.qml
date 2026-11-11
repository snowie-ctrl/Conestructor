import QtQuick
import QtTest
import "../../qml/logic/elements.mjs" as Elements
import "../../qml/logic/nodes.mjs" as Nodes

TestCase {
    name: "Nodes"

    function el(id, type, props, x, y, rotation) {
        return { id: id, type: type, x: x || 0, y: y || 0, rotation: rotation || 0,
                 props: Object.assign(Elements.defaults(type), props || {}), joins: { A: null, B: null } }
    }

    // The element with a drag's result applied.
    function apply(e, r) {
        const props = Object.assign({}, e.props)
        props[r.key] = r.value
        return Object.assign({}, e, { x: r.x, y: r.y, rotation: r.rotation, props: props })
    }

    function near(p, q) {
        return Math.hypot(p.x - q.x, p.y - q.y) < 1e-6
    }

    function unit(degrees) {
        return { x: Math.cos(degrees * Math.PI / 180), y: Math.sin(degrees * Math.PI / 180) }
    }

    function test_whichSettingStretches() {
        compare(Nodes.stretchKey(el("e1", "straight"), "A"), "length")
        compare(Nodes.stretchKey(el("e1", "line"), "B"), "length")
        compare(Nodes.stretchKey(el("e1", "turn"), "A"), "leadIn")
        compare(Nodes.stretchKey(el("e1", "slalom"), "B"), "leadOut")
    }

    function test_aFreeStraightPivotsAboutItsOtherEnd() {
        const s = el("e1", "straight")                         // A at (-10, 0), B at (10, 0)
        const r = Nodes.drag(s, "B", { x: -10, y: 15 }, { pivot: true, step: 0 })
        const after = Elements.endsWorld(apply(s, r))
        verify(near(after.A, { x: -10, y: 0 }), JSON.stringify(after.A))
        verify(near(after.B, { x: -10, y: 15 }), JSON.stringify(after.B))
        compare(r.key, "length")
        fuzzyCompare(r.value, 15, 1e-9)
        fuzzyCompare(r.rotation, 90, 1e-9)
        const back = Nodes.drag(s, "A", { x: 10, y: -5 }, { pivot: true, step: 0 })
        const turned = Elements.endsWorld(apply(s, back))
        verify(near(turned.B, { x: 10, y: 0 }))
        verify(near(turned.A, { x: 10, y: -5 }))
    }

    function test_everyTypeSwingsRoundItsOtherEnd_data() {
        return [
            { tag: "turn exit", type: "turn", end: "B" },
            { tag: "turn entry", type: "turn", end: "A" },
            { tag: "slalom exit", type: "slalom", end: "B" },
            { tag: "chicane entry", type: "chicane", end: "A" },
            { tag: "line exit", type: "line", end: "B" }
        ]
    }

    function test_everyTypeSwingsRoundItsOtherEnd(row) {
        const e = el("e1", row.type, {}, 5, 5, 10)
        const other = row.end === "A" ? "B" : "A"
        const before = Elements.endsWorld(e)
        // Swing the dragged end 20 degrees about the other end, and pull it 3 m further out.
        const arm = { x: before[row.end].x - before[other].x, y: before[row.end].y - before[other].y }
        const length = Math.hypot(arm.x, arm.y)
        const k = (length + 3) / length
        const c = Math.cos(20 * Math.PI / 180)
        const s = Math.sin(20 * Math.PI / 180)
        const point = { x: before[other].x + (arm.x * c - arm.y * s) * k, y: before[other].y + (arm.x * s + arm.y * c) * k }
        const r = Nodes.drag(e, row.end, point, { pivot: true, step: 0 })
        const after = Elements.endsWorld(apply(e, r))
        verify(near(after[other], before[other]), "the other end stays")
        verify(near(after[row.end], point), JSON.stringify(after[row.end]) + " vs " + JSON.stringify(point))
        verify(r.value > e.props[r.key], "it stretched")
    }

    function test_aMouseTooCloseLeavesTheShortestElementFacingIt() {
        const s = el("e1", "straight")
        const r = Nodes.drag(s, "B", { x: -10, y: -0.3 }, { pivot: true, step: 0 })
        compare(r.value, 1)
        fuzzyCompare(r.rotation, -90, 1e-9)
        verify(near(Elements.endsWorld(apply(s, r)).A, { x: -10, y: 0 }))
    }

    function test_aJoinedOtherEndOnlyStretches() {
        const t = el("e1", "turn")
        const before = Elements.endsWorld(t)
        const u = unit(before.B.heading)
        // 4 m further along the exit and 3 m off to the side: only the 4 m counts.
        const point = { x: before.B.x + 4 * u.x - 3 * u.y, y: before.B.y + 4 * u.y + 3 * u.x }
        const r = Nodes.drag(t, "B", point, { pivot: false, step: 0 })
        compare(r.rotation, t.rotation)
        fuzzyCompare(r.value, 10, 1e-9)
        const after = Elements.endsWorld(apply(t, r))
        verify(near(after.A, before.A))
        verify(near(after.B, { x: before.B.x + 4 * u.x, y: before.B.y + 4 * u.y }))
    }

    function test_settingsStayWithinTheirLimits() {
        compare(Nodes.drag(el("e1", "straight"), "B", { x: 300, y: 0 }, { pivot: true, step: 0 }).value, 200)
        const t = el("e2", "turn")
        const ends = Elements.endsWorld(t)
        const u = unit(ends.B.heading)
        // Pulled back 10 m past where its lead-out starts: the lead-out stops at zero.
        compare(Nodes.drag(t, "B", { x: ends.B.x - 10 * u.x, y: ends.B.y - 10 * u.y }, { pivot: false, step: 0 }).value, 0)
    }

    function test_shiftTurnsInFifteenDegreeSteps() {
        const s = el("e1", "straight")                         // A at (-10, 0)
        const point = { x: -10 + 10 * Math.cos(37 * Math.PI / 180), y: 10 * Math.sin(37 * Math.PI / 180) }
        const r = Nodes.drag(s, "B", point, { pivot: true, step: 15, frameTheta: 0 })
        fuzzyCompare(r.rotation, 30, 1e-9)
        fuzzyCompare(r.value, 10 * Math.cos(7 * Math.PI / 180), 1e-9)   // the mouse projected onto the 30° line
        verify(near(Elements.endsWorld(apply(s, r)).A, { x: -10, y: 0 }))
        // Steps count from the Origin -> Direction axis.
        fuzzyCompare(Nodes.drag(s, "B", point, { pivot: true, step: 15, frameTheta: 10 }).rotation, 40, 1e-9)
    }

    // Review focus 3: a node never snaps onto its own element's other end, a joined end, or nothing in reach.
    function test_nodesSnapOnlyOntoOtherOpenEnds() {
        const a = el("e1", "straight")                         // ends at x -10 and 10
        const b = el("e2", "straight", {}, 30, 0, 0)           // ends at x 20 and 40
        const wall = el("e3", "line", {}, 0, 20, 0)            // ends at (-10, 20) and (10, 20)
        const loop = el("e4", "turn", { angle: 360, leadIn: 0, leadOut: 0 }, 0, -40, 0)
        const list = [a, b, wall, loop]
        compare(JSON.stringify(Nodes.snapPoint(list, "e1", { x: 20.5, y: 0.3 }, 1)), JSON.stringify({ x: 20, y: 0 }))
        compare(Nodes.snapPoint(list, "e1", { x: 10.2, y: 0 }, 1), null)
        compare(JSON.stringify(Nodes.snapPoint(list, "e1", { x: 9.5, y: 19.8 }, 1)), JSON.stringify({ x: 10, y: 20 }))
        const loopEnds = Elements.endsWorld(loop)
        compare(Nodes.snapPoint(list, "e4", loopEnds.A, 1), null)
        b.joins.A = { id: "e9", end: "B" }
        compare(Nodes.snapPoint(list, "e1", { x: 20.5, y: 0.3 }, 1), null)
    }
}
