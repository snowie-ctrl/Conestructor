import QtQuick
import QtTest
import "../../qml/logic/elements.mjs" as Elements

TestCase {
    name: "Elements"

    function el(id, type, props, x, y, rotation) {
        return { id: id, type: type, x: x || 0, y: y || 0, rotation: rotation || 0,
                 props: Object.assign(Elements.defaults(type), props || {}), joins: { A: null, B: null } }
    }

    function near(actual, expected, tolerance, what) {
        verify(Math.abs(actual - expected) <= tolerance, what + ": " + actual + " should be " + expected)
    }

    function test_defaultsMatchTheSpec() {
        compare(JSON.stringify(Elements.defaults("straight")), JSON.stringify({ length: 20, trackWidth: 4 }))
        compare(JSON.stringify(Elements.defaults("slalom")), JSON.stringify(
            { leadIn: 6, leadOut: 6, coneCount: 4, coneSpacing: 10, weaveOffset: 1.5, firstTurn: "left", trackWidth: 4 }))
        compare(JSON.stringify(Elements.defaults("chicane")), JSON.stringify(
            { leadIn: 6, leadOut: 6, shiftLength: 12, shift: 6, direction: "left", trackWidth: 4 }))
        compare(JSON.stringify(Elements.defaults("turn")), JSON.stringify(
            { leadIn: 6, leadOut: 6, angle: 180, radius: 6, radiusType: "constant", exitRadius: 10, direction: "right", trackWidth: 4 }))
        compare(Elements.TIPS.turn, "Turn: anything from a sweeper to a hairpin.")
    }

    function test_defaultsAreFreshCopies() {
        const a = Elements.defaults("straight")
        a.length = 99
        compare(Elements.defaults("straight").length, 20)
    }

    function test_aTwentyMetreStraightEndsTenMetresEitherSide() {
        const g = Elements.geometry("straight", Elements.defaults("straight"))
        compare(JSON.stringify(g.ends), JSON.stringify({ A: { x: -10, y: 0, heading: 180 }, B: { x: 10, y: 0, heading: 0 } }))
    }

    function test_aHairpinExitsTwelveMetresToTheSideHeadingBack() {
        const g = Elements.geometry("turn", Elements.defaults("turn"))
        near(g.ends.B.x - g.ends.A.x, 0, 0.05, "level with the entry")
        near(g.ends.B.y - g.ends.A.y, 12, 0.05, "12 m to the right, down the screen")
        compare(g.ends.A.heading, 180)
        compare(g.ends.B.heading, 180)
    }

    function test_aLeftQuarterTurn() {
        const g = Elements.geometry("turn", Object.assign(Elements.defaults("turn"),
                                    { angle: 90, radius: 10, leadIn: 0, leadOut: 0, direction: "left" }))
        near(g.ends.B.x - g.ends.A.x, 10, 0.05, "forward")
        near(g.ends.B.y - g.ends.A.y, -10, 0.05, "left, up the screen")
        compare(g.ends.B.heading, -90)
    }

    function test_slalomAndChicaneEnds() {
        const s = Elements.geometry("slalom", Elements.defaults("slalom"))
        compare(JSON.stringify(s.ends), JSON.stringify({ A: { x: -31, y: 0, heading: 180 }, B: { x: 31, y: 0, heading: 0 } }))
        const c = Elements.geometry("chicane", Elements.defaults("chicane"))
        compare(JSON.stringify(c.ends), JSON.stringify({ A: { x: -12, y: 3, heading: 180 }, B: { x: 12, y: -3, heading: 0 } }))
        const r = Elements.geometry("chicane", Object.assign(Elements.defaults("chicane"), { direction: "right" }))
        compare(r.ends.A.y, -3)
        compare(r.ends.B.y, 3)
    }

    function test_pathsStartAndEndOnTheirEnds_data() {
        return [
            { tag: "straight", type: "straight", props: {} },
            { tag: "slalom", type: "slalom", props: {} },
            { tag: "slalom, one cone, no leads", type: "slalom", props: { coneCount: 1, leadIn: 0, leadOut: 0 } },
            { tag: "slalom, no weave, right first", type: "slalom", props: { weaveOffset: 0, firstTurn: "right" } },
            { tag: "chicane", type: "chicane", props: {} },
            { tag: "chicane, no shift, right", type: "chicane", props: { shift: 0, direction: "right" } },
            { tag: "chicane, no leads", type: "chicane", props: { leadIn: 0, leadOut: 0 } },
            { tag: "turn", type: "turn", props: {} },
            { tag: "turn of 0 degrees", type: "turn", props: { angle: 0 } },
            { tag: "turn, changing radius, left", type: "turn",
              props: { radiusType: "changing", exitRadius: 15, direction: "left", angle: 120 } },
            { tag: "turn, no leads", type: "turn", props: { leadIn: 0, leadOut: 0 } }
        ]
    }

    function test_pathsStartAndEndOnTheirEnds(row) {
        const g = Elements.geometry(row.type, Object.assign(Elements.defaults(row.type), row.props))
        const first = g.path[0]
        const last = g.path[g.path.length - 1]
        near(first.x, g.ends.A.x, 1e-9, "start x")
        near(first.y, g.ends.A.y, 1e-9, "start y")
        near(last.x, g.ends.B.x, 1e-9, "end x")
        near(last.y, g.ends.B.y, 1e-9, "end y")
        for (const p of g.path)
            verify(isFinite(p.x) && isFinite(p.y), "finite path point")
        verify(g.cones.length > 0, "has cones")
        for (const c of g.cones)
            verify(isFinite(c.x) && isFinite(c.y) && isFinite(c.heading), "finite cone")
    }

    function test_aTwentyMetreStraightHasThreePairs() {
        const cones = Elements.geometry("straight", Elements.defaults("straight")).cones
        const rounded = cones.map(c => [Math.round(c.x * 1000) / 1000, Math.round(c.y * 1000) / 1000, c.type])
        compare(JSON.stringify(rounded), JSON.stringify([[-10, 2, "standing"], [-10, -2, "standing"], [0, 2, "standing"],
                                                         [0, -2, "standing"], [10, 2, "standing"], [10, -2, "standing"]]))
    }

    function test_aSlalomHasSixteenCones() {
        const cones = Elements.geometry("slalom", Elements.defaults("slalom")).cones
        compare(cones.length, 16)
        compare(cones.filter(c => c.type === "leaning").length, 4)
    }

    // Each pointer (leaning) cone lies on the centreline side of its apex cone, pointing at it.
    function test_slalomPointersLieInsideTheirApexCones() {
        for (const firstTurn of ["left", "right"]) {
            const cones = Elements.geometry("slalom", Object.assign(Elements.defaults("slalom"), { firstTurn: firstTurn })).cones
            const standing = cones.filter(c => c.type === "standing" && Math.abs(c.y) > 1e-9 && Math.abs(Math.abs(c.y) - 2) > 1e-9)
            const leaning = cones.filter(c => c.type === "leaning")
            compare(leaning.length, 4)
            compare(standing.length, 4)
            for (let i = 0; i < 4; i++) {
                const apex = standing[i]
                const pointer = leaning[i]
                compare(pointer.x, apex.x)
                verify(Math.abs(pointer.y) < Math.abs(apex.y), firstTurn + " " + i + ": pointer nearer the centreline")
                const towardApex = Math.atan2(apex.y - pointer.y, apex.x - pointer.x) * 180 / Math.PI
                verify(Math.abs(pointer.heading - towardApex) < 1e-9, firstTurn + " " + i + ": heading " + pointer.heading)
            }
        }
    }

    function test_endsInTheWorld() {
        const e = Elements.endsWorld(el("a", "straight", {}, 5, 5, 90))
        near(e.A.x, 5, 1e-9, "A x")
        near(e.A.y, -5, 1e-9, "A y")
        compare(e.A.heading, 270)
        near(e.B.x, 5, 1e-9, "B x")
        near(e.B.y, 15, 1e-9, "B y")
        compare(e.B.heading, 90)
    }

    function test_conesInTheWorldTurnWithTheElement() {
        const cones = Elements.conesWorld(el("a", "straight", {}, 100, 50, 90))
        near(cones[0].x, 98, 1e-9, "first cone x")
        near(cones[0].y, 40, 1e-9, "first cone y")
        compare(cones[0].heading, 90)
    }

    function test_clamp_data() {
        return [
            { tag: "too wide", type: "straight", key: "trackWidth", value: 25, expected: 20, clamped: true },
            { tag: "too narrow", type: "straight", key: "trackWidth", value: 0.5, expected: 1, clamped: true },
            { tag: "fine", type: "straight", key: "trackWidth", value: 4, expected: 4, clamped: false },
            { tag: "counts are whole", type: "slalom", key: "coneCount", value: 4.6, expected: 5, clamped: false },
            { tag: "unknown choice", type: "slalom", key: "firstTurn", value: "up", expected: "left", clamped: true },
            { tag: "angle over 180", type: "turn", key: "angle", value: 270, expected: 180, clamped: true },
            { tag: "not a number", type: "turn", key: "radius", value: NaN, expected: 1, clamped: true }
        ]
    }

    function test_clamp(row) {
        const c = Elements.clampProp(row.type, row.key, row.value)
        compare(c.value, row.expected)
        compare(c.clamped, row.clamped)
    }

    function test_exitRadiusShowsOnlyWhenTheRadiusChanges() {
        const keys = props => Elements.propList("turn", props).map(p => p.key)
        verify(keys(Elements.defaults("turn")).indexOf("exitRadius") < 0)
        verify(keys(Object.assign(Elements.defaults("turn"), { radiusType: "changing" })).indexOf("exitRadius") >= 0)
    }

    function test_hitTestFindsTheTopmostElement() {
        const a = el("a", "straight", {}, 0, 0, 0)
        const b = el("b", "straight", {}, 0, 0, 90)
        compare(Elements.hitTest([a, b], { x: 0, y: 0 }, 0.1), "b")
        compare(Elements.hitTest([a, b], { x: 8, y: 1.9 }, 0.1), "a")
        compare(Elements.hitTest([a, b], { x: 8, y: 2.5 }, 0.1), "")
    }

    function test_theRotateHandleSitsAboveTheBand() {
        const h = Elements.rotateHandle(el("a", "straight", {}, 0, 0, 0), 1)
        near(h.x, 0, 1e-9, "x")
        near(h.y, -3, 1e-9, "y")
        const turned = Elements.rotateHandle(el("a", "straight", {}, 0, 0, 90), 1)
        near(turned.x, 3, 1e-9, "turned x")
        near(turned.y, 0, 1e-9, "turned y")
    }

    function test_theBandIsAPolygonAroundTheCentreline() {
        const ring = Elements.bandPolygon([{ x: -10, y: 0 }, { x: 10, y: 0 }], 2)
        compare(JSON.stringify(ring), JSON.stringify([{ x: -10, y: 2 }, { x: 10, y: 2 }, { x: 10, y: -2 }, { x: -10, y: -2 }]))
        const bent = Elements.bandPolygon([{ x: 0, y: 0 }, { x: 10, y: 0 }, { x: 10, y: 10 }], 1)
        compare(bent.length, 6)
        for (const p of bent)
            verify(isFinite(p.x) && isFinite(p.y), "finite")
        compare(Elements.bandPolygon([{ x: 0, y: 0 }], 1).length, 0)
    }

    function test_normalizeAngle() {
        compare(Elements.normalizeAngle(190), -170)
        compare(Elements.normalizeAngle(-190), 170)
        compare(Elements.normalizeAngle(180), 180)
        compare(Elements.normalizeAngle(-180), -180)
        compare(Elements.normalizeAngle(720), 0)
    }
}
