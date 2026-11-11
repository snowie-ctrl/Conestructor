import QtQuick
import QtTest
import "../../qml/logic/commands.mjs" as Commands
import "../../qml/logic/postprocess.mjs" as Post
import "../../qml/logic/snapping.mjs" as Snapping

TestCase {
    name: "PostProcess"

    function build(steps) {
        const s = new Commands.UndoStack()
        let t = Commands.emptyTrack()
        for (const step of steps)
            t = Commands.run(s, t, step[0], step[1])
        return t
    }
    // 0.1 m per pixel.
    function scale() { return [["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 }]] }
    // Origin at (0 m, 5 m), x along the screen.
    function targets() {
        return [["setTarget", { which: "origin", point: { x: 0, y: 50 } }],
                ["setTarget", { which: "direction", point: { x: 400, y: 50 } }]]
    }
    function xs(result) { return result.cones.map(c => Math.round(c.x * 1000) / 1000) }

    function test_check_data() {
        return [
            { tag: "no ruler", steps: [], message: Post.MESSAGES.noRuler, kind: "" },
            { tag: "no real length", steps: [["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 0 }]],
              message: Post.MESSAGES.noLength, kind: "ruler" },
            { tag: "no Origin", steps: scale(), message: Post.MESSAGES.noOrigin, kind: "" },
            { tag: "no Direction", steps: scale().concat([["setTarget", { which: "origin", point: { x: 0, y: 0 } }]]),
              message: Post.MESSAGES.noDirection, kind: "" },
            { tag: "targets too close", steps: scale().concat([["setTarget", { which: "origin", point: { x: 0, y: 0 } }],
                                                              ["setTarget", { which: "direction", point: { x: 9, y: 0 } }]]),
              message: Post.MESSAGES.tooClose, kind: "direction" },
            { tag: "no track", steps: scale().concat(targets()), message: Post.MESSAGES.noTrack, kind: "" }
        ]
    }

    function test_check(row) {
        const error = Post.check(build(row.steps))
        compare(error.message, row.message)
        compare(error.target ? error.target.kind : "", row.kind)
        const result = Post.run(build(row.steps))
        compare(result.error.message, row.message)
    }

    function test_aReadyTrackPasses() {
        compare(Post.check(build(scale().concat(targets(), [["add", { type: "straight", x: 10, y: 5 }]]))), null)
    }

    function test_conesFollowTheDrivingOrderAlongAChain() {
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } }]
        ]))
        const result = Post.run(t)
        compare(JSON.stringify(xs(result)), JSON.stringify([0, 0, 10, 10, 20, 20, 30, 30, 40, 40]))
        fuzzyCompare(result.targetDistance, 40, 1e-9)
    }

    function test_aReversedElementIsWalkedTheRightWay() {
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "B", id: "e1", end: "B" } }]
        ]))
        compare(t.elements[1].rotation, 180)
        compare(JSON.stringify(xs(Post.run(t))), JSON.stringify([0, 0, 10, 10, 20, 20, 30, 30, 40, 40]))
        compare(JSON.stringify(Post.backwards(t.elements)), JSON.stringify(["e2"]))
    }

    function test_conesAtAJoinAreNotDoubled() {
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } }]
        ]))
        const groups = Post.coneGroups(t.elements)
        compare(groups[0].cones.length + groups[1].cones.length, 12)
        compare(Post.run(t).cones.length, 10)
    }

    function test_separateChainsKeepTheirArrows() {
        // The second straight points back toward the first (rotation 180): it is driven from its entry at x 70.
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 60, y: 5, rotation: 180 }]
        ]))
        compare(JSON.stringify(xs(Post.run(t))), JSON.stringify([0, 0, 10, 10, 20, 20, 70, 70, 60, 60, 50, 50]))
    }

    function test_aChainBuiltBackwardsIsDrivenTheWayItsArrowsPoint() {
        // e2 is added in front of e1 (its exit joins e1's entry), so the chain is driven e2 then e1.
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "B", id: "e1", end: "A" } }]
        ]))
        compare(JSON.stringify(xs(Post.run(t))), JSON.stringify([-20, -20, -10, -10, 0, 0, 10, 10, 20, 20]))
        compare(JSON.stringify(Post.backwards(t.elements)), "[]")
    }

    function test_theMajorityDecides() {
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } }],
            ["add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "B", id: "e2", end: "B" } }]     // e3 faces back
        ]))
        compare(JSON.stringify(xs(Post.run(t))), JSON.stringify([0, 0, 10, 10, 20, 20, 30, 30, 40, 40, 50, 50, 60, 60]))
        compare(JSON.stringify(Post.backwards(t.elements)), JSON.stringify(["e3"]))
        const steps = Post.chains(t.elements)
        compare(steps.length, 1)
        compare(JSON.stringify(steps[0]), JSON.stringify([{ id: "e1", forward: true }, { id: "e2", forward: true },
                                                          { id: "e3", forward: false }]))
    }

    function test_aClosedLoopStartsAtItsEarliestElement() {
        const turn = { angle: 90, radius: 6, leadIn: 0, leadOut: 0 }
        let t = build(scale().concat(targets(), [
            ["add", { type: "turn", x: 20, y: 20, props: turn }],
            ["add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: "e1", end: "B" } }],
            ["add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: "e2", end: "B" } }],
            ["add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: "e3", end: "B" } }]
        ]))
        t = Commands.clone(t)
        Snapping.join(t.elements, "e4", "B", "e1", "A")
        const steps = Post.chains(t.elements)
        compare(steps.length, 1)
        compare(steps[0].map(s => s.id).join(","), "e1,e2,e3,e4")
        verify(steps[0].every(s => s.forward))
    }

    function test_yIsToTheLeftOfTheAxis() {
        const t = build(scale().concat(targets(), [["add", { type: "straight", x: 10, y: 0 }]]))   // 5 m up the screen
        for (const c of Post.run(t).cones)
            verify(Math.abs(c.y - 5) < 2 + 1e-9 && c.y > 0, "y " + c.y)
    }

    function test_aClosedLoopListsEveryConeOnce() {
        const turn = { angle: 90, radius: 6, leadIn: 0, leadOut: 0 }
        let t = build(scale().concat(targets(), [
            ["add", { type: "turn", x: 20, y: 20, props: turn }],
            ["add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: "e1", end: "B" } }],
            ["add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: "e2", end: "B" } }],
            ["add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: "e3", end: "B" } }]
        ]))
        t = Commands.clone(t)
        Snapping.join(t.elements, "e4", "B", "e1", "A")
        const groups = Post.coneGroups(t.elements)
        Post.dedupe(groups, Post.DEDUPE_METRES)
        const expected = groups.reduce((n, g) => n + g.cones.length, 0)
        const result = Post.run(t)
        compare(result.cones.length, expected)
        for (let i = 0; i < result.cones.length; i++)
            compare(result.cones[i].index, i)
    }

    function test_canvasConesMatchTheExportCones() {
        const t = build(scale().concat(targets(), [["add", { type: "slalom", x: 40, y: 20, rotation: 30 }]]))
        const r = Post.run(t)
        compare(r.canvasCones.length, r.cones.length)
        compare(r.canvasCones[3].type, r.cones[3].type)
        compare(r.cones[3].element, "e1")
        compare(r.canvasCones[3].element, "e1")
    }
}
