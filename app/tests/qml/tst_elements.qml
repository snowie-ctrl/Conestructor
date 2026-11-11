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
            { tag: "angle over 360", type: "turn", key: "angle", value: 400, expected: 360, clamped: true },
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

    function samePoint(a, b, tolerance, what) {
        verify(Math.hypot(a.x - b.x, a.y - b.y) <= tolerance,
               what + ": (" + a.x + ", " + a.y + ") vs (" + b.x + ", " + b.y + ")")
    }

    function sameHeading(a, b, what) {
        const d = ((((a - b) % 360) + 540) % 360) - 180
        verify(Math.abs(d) < 1e-6, what + ": " + a + " vs " + b)
    }

    function test_reversedKeepsTheFootprint_data() {
        return [
            { tag: "straight", type: "straight", props: {} },
            { tag: "slalom, 4 cones", type: "slalom", props: { leadIn: 3, leadOut: 9 } },
            { tag: "slalom, 3 cones, right first", type: "slalom", props: { coneCount: 3, firstTurn: "right" } },
            { tag: "chicane, uneven leads", type: "chicane", props: { leadIn: 2, leadOut: 11 } },
            { tag: "chicane right", type: "chicane", props: { direction: "right" } },
            { tag: "turn", type: "turn", props: {} },
            { tag: "turn, changing, left", type: "turn",
              props: { radiusType: "changing", radius: 6, exitRadius: 14, angle: 135, direction: "left", leadIn: 2 } },
            { tag: "turn of 0 degrees", type: "turn", props: { angle: 0 } },
            { tag: "turn, wide", type: "turn", props: { radius: 100, angle: 180 } }
        ]
    }

    function test_reversedKeepsTheFootprint(row) {
        const a = el("e1", row.type, row.props, 12, -7, 33)
        const b = Object.assign({}, a, Elements.reversed(a))
        const ea = Elements.endsWorld(a)
        const eb = Elements.endsWorld(b)
        samePoint(eb.A, ea.B, 1e-6, "new entry at the old exit")
        samePoint(eb.B, ea.A, 1e-6, "new exit at the old entry")
        sameHeading(eb.A.heading, ea.B.heading, "entry faces where the exit did")
        sameHeading(eb.B.heading, ea.A.heading, "exit faces where the entry did")
        const p = Elements.pathWorld(a)
        const q = Elements.pathWorld(b).slice().reverse()
        compare(q.length, p.length)
        for (let i = 0; i < p.length; i++)
            samePoint(q[i], p[i], 1e-6, "path point " + i)
    }

    function test_reversedPropsSaysTheSameThingTheOtherWay() {
        const t = Elements.reversedProps("turn", Object.assign(Elements.defaults("turn"),
                                         { leadIn: 2, leadOut: 8, radiusType: "changing", radius: 6, exitRadius: 12 }))
        compare(t.direction, "left")
        compare(t.leadIn, 8)
        compare(t.leadOut, 2)
        compare(t.radius, 12)
        compare(t.exitRadius, 6)
        compare(Elements.reversedProps("turn", Elements.defaults("turn")).exitRadius, 10)   // constant: untouched
        compare(Elements.reversedProps("slalom", Elements.defaults("slalom")).firstTurn, "left")    // 4 cones
        compare(Elements.reversedProps("slalom", Object.assign(Elements.defaults("slalom"), { coneCount: 3 })).firstTurn,
                "right")
        compare(Elements.reversedProps("chicane", Elements.defaults("chicane")).direction, "left")
    }

    function test_pointsAlongAStraight() {
        const s = el("e1", "straight", {}, 5, 5, 0)
        const p = Elements.pointsAlong(s, [0, 0.5, 1])
        samePoint(p[0], { x: -5, y: 5 }, 1e-9, "start")
        samePoint(p[1], { x: 5, y: 5 }, 1e-9, "middle")
        samePoint(p[2], { x: 15, y: 5 }, 1e-9, "end")
        compare(p[1].heading, 0)
        compare(Elements.pointsAlong(el("e2", "straight", {}, 0, 0, 90), [0.5])[0].heading, 90)
        fuzzyCompare(Elements.pathLength(s), 20, 1e-9)
    }

    function test_pointsAlongSkipsAnEmptyLead() {
        const t = el("e1", "turn", { leadIn: 0, leadOut: 0 }, 0, 0, 0)
        verify(Math.abs(Elements.pointsAlong(t, [0])[0].heading) < 1, "starts heading along +x")
    }

    function test_arrowMarks() {
        compare(Elements.arrowMarks(el("e1", "straight", {}), 8).length, 3)               // 20 m
        compare(Elements.arrowMarks(el("e1", "straight", { length: 4 }), 8).length, 2)    // at least two
        const marks = Elements.arrowMarks(el("e1", "straight", {}, 0, 0, 0), 8)
        fuzzyCompare(marks[0].x, -10 + 20 / 6, 1e-9)
    }

    function test_aHalfTurnIsATrueArc() {
        const g = Elements.geometry("turn", Object.assign(Elements.defaults("turn"), { leadIn: 0, leadOut: 0 }))
        near(g.ends.B.x - g.ends.A.x, 0, 1e-3, "level with the entry")
        near(g.ends.B.y - g.ends.A.y, 12, 1e-3, "exactly a 12 m diameter")
    }

    function test_aTurnGoesUpToAFullCircle() {
        const full = Elements.clampProp("turn", "angle", 360)
        compare(full.value, 360)
        verify(!full.clamped)
        compare(Elements.clampProp("turn", "angle", 400).value, 360)
    }

    function test_aFullLoopLeavesTheWayItCameIn() {
        const g = Elements.geometry("turn", Object.assign(Elements.defaults("turn"), { angle: 360 }))
        fuzzyCompare(g.ends.B.heading, 0, 1e-9)
        fuzzyCompare(g.ends.B.x - g.ends.A.x, 12, 1e-6)      // lead-in 6 m and lead-out 6 m along the entry line
        fuzzyCompare(g.ends.B.y - g.ends.A.y, 0, 1e-6)
    }

    function test_aFullLoopReversesInPlace() {
        const el = { id: "e1", type: "turn", x: 10, y: 20, rotation: 30,
                     props: Object.assign(Elements.defaults("turn"), { angle: 360, leadOut: 2 }), joins: { A: null, B: null } }
        const r = Object.assign({}, el, Elements.reversed(el))
        const before = Elements.endsWorld(el)
        const after = Elements.endsWorld(r)
        fuzzyCompare(after.A.x, before.B.x, 1e-6)
        fuzzyCompare(after.A.y, before.B.y, 1e-6)
        fuzzyCompare(after.B.x, before.A.x, 1e-6)
        fuzzyCompare(after.B.y, before.A.y, 1e-6)
    }

    function test_aLineIsARowOfStandingCones() {
        compare(JSON.stringify(Elements.defaults("line")), JSON.stringify({ length: 20, spacing: 3 }))
        compare(Elements.NAMES.line, "Line")
        compare(Elements.TIPS.line, "Line: a straight row of cones, for walls and boundaries.")
        const g = Elements.geometry("line", Elements.defaults("line"))
        compare(g.cones.length, 8)                       // 20 m at most 3 m apart: 7 gaps of 2.857 m
        fuzzyCompare(g.cones[0].x, -10, 1e-9)
        fuzzyCompare(g.cones[7].x, 10, 1e-9)
        fuzzyCompare(g.cones[1].x - g.cones[0].x, 20 / 7, 1e-9)
        verify(g.cones.every(c => c.type === "standing" && c.y === 0 && c.heading === 0))
        compare(Elements.geometry("line", { length: 21, spacing: 3 }).cones.length, 8)   // exactly 3 m apart
        fuzzyCompare(g.ends.A.x, -10, 1e-9)
        compare(g.ends.A.heading, 180)
        compare(g.ends.B.heading, 0)
    }

    function test_aLineIsPickedWithinHalfAMetre() {
        const line = { id: "e1", type: "line", x: 0, y: 0, rotation: 0, props: Elements.defaults("line"),
                       joins: { A: null, B: null } }
        compare(Elements.hitTest([line], { x: 3, y: 0.4 }, 0), "e1")
        compare(Elements.hitTest([line], { x: 3, y: 0.6 }, 0), "")
        compare(Elements.reach(line), 0.5)
        compare(Elements.reach({ type: "straight", props: { trackWidth: 4 } }), 2)
        const handle = Elements.rotateHandle(line, 1)
        fuzzyCompare(handle.y, -1.5, 1e-9)               // half a metre of reach plus the 1 m asked for
    }

    function typed(type, props) {
        return { id: "e1", type: type, x: 0, y: 0, rotation: 0, props: Object.assign(Elements.defaults(type), props || {}),
                 joins: { A: null, B: null } }
    }

    function test_tightestRadiusOfACircle() {
        const points = []
        for (let i = 0; i <= 12; i++)
            points.push({ x: 5 * Math.cos(i * Math.PI / 6), y: 5 * Math.sin(i * Math.PI / 6) })
        fuzzyCompare(Elements.tightestRadius(points), 5, 1e-9)
        // Repeated points (an empty lead) are skipped; points in a line are no curve at all.
        compare(Elements.tightestRadius([{ x: 0, y: 0 }, { x: 0, y: 0 }, { x: 1, y: 0 }, { x: 2, y: 0 }]), Infinity)
    }

    function test_noDefaultElementFolds() {
        for (const type of Elements.TYPES)
            verify(!Elements.folds(typed(type)), type)
        verify(!Elements.folds(typed("straight", { trackWidth: 20 })))
    }

    function test_aTurnFoldsBelowHalfItsWidth() {
        verify(!Elements.folds(typed("turn", { radius: 2 })), "at half the width it does not fold")
        verify(Elements.folds(typed("turn", { radius: 1.9 })))
        verify(Elements.folds(typed("turn", { radiusType: "changing", radius: 6, exitRadius: 1.5 })))
        verify(!Elements.folds(typed("turn", { radiusType: "constant", radius: 6, exitRadius: 1.5 })), "exit radius unused")
        verify(!Elements.folds(typed("turn", { radius: 1, angle: 0 })), "no turn, no fold")
    }

    function test_tightChicanesAndSlalomsFold() {
        verify(Elements.folds(typed("chicane", { shiftLength: 2, shift: 6 })))
        verify(Elements.folds(typed("slalom", { coneSpacing: 2, weaveOffset: 3 })))
    }

    function test_foldAdviceNamesTheFix() {
        const metres = m => m.toFixed(1) + " m"
        compare(Elements.foldAdvice(typed("turn", { radius: 1 }), metres),
                "Folds in on itself: make the radius at least 2.0 m, or the track narrower.")
        compare(Elements.foldAdvice(typed("chicane", { shiftLength: 2 }), metres),
                "Folds in on itself: make the shift length longer or the sideways shift smaller, or the track narrower.")
        compare(Elements.foldAdvice(typed("slalom", { coneSpacing: 2, weaveOffset: 3 }), metres),
                "Folds in on itself: space the cones further apart or make the weave offset smaller, or the track narrower.")
        compare(Elements.foldAdvice(typed("turn"), metres), "")
    }
}
