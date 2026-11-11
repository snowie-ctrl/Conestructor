import QtQuick
import QtTest
import "../../qml/logic/commands.mjs" as Commands
import "../../qml/logic/elements.mjs" as Elements

TestCase {
    name: "Commands"

    // A ruler at 0.1 m per pixel, Origin, and three joined elements e1 (straight) - e2 (turn) - e3 (straight).
    function base() {
        const s = new Commands.UndoStack()
        let t = Commands.emptyTrack()
        t = Commands.run(s, t, "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 })
        t = Commands.run(s, t, "setTarget", { which: "origin", point: { x: 10, y: 10 } })
        t = Commands.run(s, t, "add", { type: "straight", x: 5, y: 5 })
        t = Commands.run(s, t, "add", { type: "turn", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } })
        t = Commands.run(s, t, "add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "A", id: "e2", end: "B" } })
        return t
    }

    function byId(track, id) {
        return track.elements.find(e => e.id === id)
    }

    function endsMeet(track, aId, aEnd, bId, bEnd) {
        const pa = Elements.endsWorld(byId(track, aId))[aEnd]
        const pb = Elements.endsWorld(byId(track, bId))[bEnd]
        return Math.hypot(pa.x - pb.x, pa.y - pb.y) < 1e-9
    }

    function test_everyCommandUndoesAndRedoesExactly_data() {
        return [
            { tag: "new track", name: "newTrack", args: {} },
            { tag: "load photo", name: "setPhoto", args: { kind: "image", ref: 3 } },
            { tag: "use the blueprint", name: "setPhoto", args: { kind: "blueprint" } },
            { tag: "drag a ruler end", name: "setRuler", args: { a: { x: 0, y: 0 }, b: { x: 200, y: 0 }, realLength: 10 } },
            { tag: "type a ruler length", name: "setRuler", args: { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 12 } },
            { tag: "place Direction", name: "setTarget", args: { which: "direction", point: { x: 500, y: 10 } } },
            { tag: "move Origin", name: "setTarget", args: { which: "origin", point: { x: 20, y: 30 } } },
            { tag: "delete Origin", name: "setTarget", args: { which: "origin", point: null } },
            { tag: "add a free slalom", name: "add", args: { type: "slalom", x: 40, y: 40, rotation: 15 } },
            { tag: "add a joined chicane", name: "add",
              args: { type: "chicane", x: 0, y: 0, snap: { ownEnd: "A", id: "e3", end: "B" } } },
            { tag: "move the middle element", name: "place", args: { id: "e2", x: 60, y: 60, rotation: 0 } },
            { tag: "rotate the last element", name: "place", args: { id: "e3", x: 1, y: 2, rotation: 45, verb: "Rotate" } },
            { tag: "change a turn's radius", name: "setProp", args: { id: "e2", key: "radius", value: 9 } },
            { tag: "change a straight's length", name: "setProp", args: { id: "e1", key: "length", value: 30 } },
            { tag: "delete the middle element", name: "remove", args: { id: "e2" } },
            { tag: "duplicate", name: "duplicate", args: { id: "e1" } },
            { tag: "reverse the turn", name: "reverse", args: { ids: ["e2"] } },
            { tag: "reverse two", name: "reverse", args: { ids: ["e1", "e2"] } },
            { tag: "type a rotation", name: "rotateChain", args: { id: "e1", rotation: 90 } },
            { tag: "change two widths", name: "setProps", args: { ids: ["e1", "e3"], key: "trackWidth", value: 6 } },
            { tag: "delete two", name: "removeMany", args: { ids: ["e1", "e3"] } },
            { tag: "duplicate two", name: "duplicateMany", args: { ids: ["e1", "e2"] } },
            { tag: "drag two", name: "placeMany",
              args: { moves: [{ id: "e1", x: 40, y: 40, rotation: 0 }, { id: "e2", x: 60, y: 40, rotation: 0 }], snap: null } }
        ]
    }

    function test_everyCommandUndoesAndRedoesExactly(row) {
        const stack = new Commands.UndoStack()
        const before = base()
        const beforeText = JSON.stringify(before)
        const after = Commands.run(stack, before, row.name, row.args)
        const afterText = JSON.stringify(after)
        verify(afterText !== beforeText, "the command changed something")
        compare(JSON.stringify(before), beforeText, "the old track was not touched")
        compare(JSON.stringify(stack.undo()), beforeText)
        compare(JSON.stringify(stack.redo()), afterText)
    }

    function test_labels() {
        const stack = new Commands.UndoStack()
        let t = base()
        const steps = [
            ["place", { id: "e1", x: 3, y: 3, rotation: 0 }, "Move Straight"],
            ["place", { id: "e2", x: 3, y: 3, rotation: 30, verb: "Rotate" }, "Rotate Turn"],
            ["setProp", { id: "e2", key: "trackWidth", value: 5 }, "Change Track width"],
            ["setTarget", { which: "direction", point: { x: 1, y: 1 } }, "Place Direction"],
            ["setTarget", { which: "direction", point: { x: 2, y: 1 } }, "Move Direction"],
            ["setTarget", { which: "direction", point: null }, "Delete Direction"],
            ["add", { type: "slalom", x: 0, y: 0 }, "Add Slalom"],
            ["duplicate", { id: "e1" }, "Duplicate Straight"],
            ["remove", { id: "e3" }, "Delete Straight"],
            ["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 11 }, "Set ruler"],
            ["reverse", { ids: ["e2"] }, "Reverse Turn"],
            ["reverse", { ids: ["e1", "e2"] }, "Reverse 2 elements"],
            ["rotateChain", { id: "e1", rotation: 45 }, "Rotate Straight"],
            ["setPhoto", { kind: "image", ref: 1 }, "Load photo"],
            ["setPhoto", { kind: "blueprint" }, "Use blueprint"],
            ["newTrack", {}, "New track"]
        ]
        for (const [name, args, label] of steps) {
            t = Commands.run(stack, t, name, args)
            stack.seal()
            compare(stack.undoLabel(), label, name)
        }
    }

    function test_nothingChangedRecordsNothing() {
        const stack = new Commands.UndoStack()
        const t = base()
        const same = Commands.run(stack, t, "setPhoto", { kind: "none" })
        verify(same === t)
        verify(!stack.canUndo())
    }

    function test_aPhotoIsOnlyItsRef() {
        const t = Commands.run(new Commands.UndoStack(), base(), "setPhoto", { kind: "image", ref: 7 })
        compare(JSON.stringify(t.photo), JSON.stringify({ kind: "image", ref: 7, metresPerPixel: 0.1 }))
        const b = Commands.run(new Commands.UndoStack(), t, "setPhoto", { kind: "blueprint", ref: 7 })
        compare(b.photo.ref, null)
        compare(JSON.stringify(Commands.emptyTrack().photo), JSON.stringify({ kind: "none", ref: null, metresPerPixel: 0 }))
    }

    function test_typingIntoOneFieldIsOneStep() {
        const stack = new Commands.UndoStack()
        const t0 = base()
        let t = Commands.run(stack, t0, "setProp", { id: "e1", key: "length", value: 2 })
        t = Commands.run(stack, t, "setProp", { id: "e1", key: "length", value: 25 })
        compare(byId(t, "e1").props.length, 25)
        compare(JSON.stringify(stack.undo()), JSON.stringify(t0))
        verify(!stack.canUndo())
    }

    function test_sealingStartsANewStep() {
        const stack = new Commands.UndoStack()
        let t = Commands.run(stack, base(), "setProp", { id: "e1", key: "length", value: 2 })
        stack.seal()
        t = Commands.run(stack, t, "setProp", { id: "e1", key: "length", value: 25 })
        stack.undo()
        verify(stack.canUndo())
    }

    function test_aDragIsOneStep() {
        const stack = new Commands.UndoStack()
        const t0 = base()
        let t = t0
        for (let i = 1; i <= 5; i++)
            t = Commands.run(stack, t, "place", { id: "e1", x: 5 + i, y: 5, rotation: 0, mergeKey: "drag1" })
        stack.seal()
        compare(JSON.stringify(stack.undo()), JSON.stringify(t0))
        verify(!stack.canUndo())
    }

    function test_aNewStepClearsRedo() {
        const stack = new Commands.UndoStack()
        let t = Commands.run(stack, base(), "add", { type: "slalom", x: 0, y: 0 })
        t = stack.undo()
        verify(stack.canRedo())
        Commands.run(stack, t, "add", { type: "turn", x: 0, y: 0 })
        verify(!stack.canRedo())
    }

    function test_theStackKeepsAtMostItsLimit() {
        const stack = new Commands.UndoStack(3)
        let t = base()
        for (let i = 0; i < 5; i++)
            t = Commands.run(stack, t, "add", { type: "straight", x: i, y: 0 })
        let undone = 0
        while (stack.undo()) undone += 1
        compare(undone, 3)
    }

    function test_addWithASnapJoinsBothWays() {
        const t = base()
        compare(JSON.stringify(byId(t, "e1").joins.B), JSON.stringify({ id: "e2", end: "A" }))
        compare(JSON.stringify(byId(t, "e2").joins.A), JSON.stringify({ id: "e1", end: "B" }))
        verify(endsMeet(t, "e1", "B", "e2", "A"))
        verify(endsMeet(t, "e2", "B", "e3", "A"))
        compare(t.nextId, 4)
    }

    function test_placeUnjoinsAndCanJoinAgain() {
        const s = new Commands.UndoStack()
        let t = Commands.run(s, base(), "place", { id: "e3", x: 90, y: 90, rotation: 0 })
        compare(byId(t, "e3").joins.A, null)
        compare(byId(t, "e2").joins.B, null)
        t = Commands.run(s, t, "place", { id: "e3", x: 0, y: 0, rotation: 0, snap: { ownEnd: "A", id: "e2", end: "B" } })
        verify(endsMeet(t, "e2", "B", "e3", "A"))
        compare(byId(t, "e2").joins.B.id, "e3")
    }

    function test_setPropClampsAndKeepsTheChainGlued() {
        const t = Commands.run(new Commands.UndoStack(), base(), "setProp", { id: "e2", key: "trackWidth", value: 50 })
        compare(byId(t, "e2").props.trackWidth, 20)
        const u = Commands.run(new Commands.UndoStack(), base(), "setProp", { id: "e2", key: "radius", value: 15 })
        verify(endsMeet(u, "e1", "B", "e2", "A"))
        verify(endsMeet(u, "e2", "B", "e3", "A"))
    }

    function test_undoingADeleteRestoresTheNeighboursJoins() {
        const stack = new Commands.UndoStack()
        const t0 = base()
        const t1 = Commands.run(stack, t0, "remove", { id: "e2" })
        compare(byId(t1, "e1").joins.B, null)
        compare(byId(t1, "e3").joins.A, null)
        const back = stack.undo()
        compare(byId(back, "e1").joins.B.id, "e2")
        compare(byId(back, "e3").joins.A.id, "e2")
        compare(JSON.stringify(back), JSON.stringify(t0))
    }

    function test_duplicateIsUnjoinedAndOffset() {
        const t = Commands.run(new Commands.UndoStack(), base(), "duplicate", { id: "e2" })
        const copy = t.elements[t.elements.length - 1]
        const original = byId(t, "e2")
        compare(copy.id, "e4")
        compare(copy.joins.A, null)
        compare(copy.joins.B, null)
        compare(copy.x, original.x + 2)
        compare(copy.y, original.y + 2)
        compare(JSON.stringify(copy.props), JSON.stringify(original.props))
        compare(original.joins.A.id, "e1")
    }

    function test_theRulerRescalesAndKeepsChainsGlued() {
        const stack = new Commands.UndoStack()
        const t0 = base()
        const e1Pixels = { x: byId(t0, "e1").x / 0.1, y: byId(t0, "e1").y / 0.1 }
        const t1 = Commands.run(stack, t0, "setRuler", { a: { x: 0, y: 0 }, b: { x: 200, y: 0 }, realLength: 10 })
        compare(t1.photo.metresPerPixel, 0.05)
        fuzzyCompare(byId(t1, "e1").x / 0.05, e1Pixels.x, 1e-9)
        fuzzyCompare(byId(t1, "e1").y / 0.05, e1Pixels.y, 1e-9)
        compare(JSON.stringify(byId(t1, "e1").props), JSON.stringify(byId(t0, "e1").props))
        verify(endsMeet(t1, "e1", "B", "e2", "A"), "e1-e2")
        verify(endsMeet(t1, "e2", "B", "e3", "A"), "e2-e3")
        compare(JSON.stringify(stack.undo()), JSON.stringify(t0))
    }

    function test_theRulerCannotLoseItsScaleUnderElements() {
        const t0 = base()
        const stack = new Commands.UndoStack()
        verify(Commands.run(stack, t0, "setRuler", { a: { x: 5, y: 5 }, b: { x: 5, y: 5 }, realLength: 10 }) === t0)
        verify(Commands.run(stack, t0, "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 0 }) === t0)
        verify(Commands.run(stack, t0, "removeRuler", {}) === t0)
        verify(!stack.canUndo())
    }

    function test_droppingBackIntoAGapJoinsBothEnds() {
        // e2 sits between e1 and e3; placed back where it was, snapped to e1, it joins e3 again too.
        const t0 = base()
        const e2 = byId(t0, "e2")
        const t = Commands.run(new Commands.UndoStack(), t0, "place",
                               { id: "e2", x: e2.x + 0.05, y: e2.y + 0.02, rotation: e2.rotation,
                                 snap: { ownEnd: "A", id: "e1", end: "B" } })
        compare(byId(t, "e2").joins.A.id, "e1")
        verify(byId(t, "e2").joins.B !== null, "e2's exit joined again")
        compare(byId(t, "e3").joins.A.id, "e2")
    }

    function test_noJoinedEndsAreLeftApart() {
        // Four quarter turns joined into a closed ring; a bigger radius on one cannot close, so the joint that
        // opens is unjoined rather than left looking joined.
        const turn = { angle: 90, radius: 6, leadIn: 0, leadOut: 0 }
        const s = new Commands.UndoStack()
        let t = Commands.run(s, Commands.emptyTrack(), "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 })
        t = Commands.run(s, t, "add", { type: "turn", x: 20, y: 20, props: turn })
        for (const id of ["e1", "e2", "e3"])
            t = Commands.run(s, t, "add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: id, end: "B" } })
        const e1 = byId(t, "e1")
        t = Commands.run(s, t, "place", { id: "e1", x: e1.x, y: e1.y, rotation: e1.rotation,
                                          snap: { ownEnd: "A", id: "e4", end: "B" } })
        compare(byId(t, "e1").joins.A.id, "e4")
        compare(byId(t, "e1").joins.B.id, "e2")            // the ring is closed
        t = Commands.run(s, t, "setProp", { id: "e2", key: "radius", value: 8 })
        let joins = 0
        for (const el of t.elements)
            for (const end of ["A", "B"]) {
                const mate = el.joins[end]
                if (!mate)
                    continue
                joins += 1
                verify(endsMeet(t, el.id, end, mate.id, mate.end), el.id + "." + end + " is joined but apart")
            }
        verify(joins >= 6, "the rest of the ring stays joined: " + joins)
    }

    function test_aRulerWithoutElementsCanBeRemoved() {
        const s = new Commands.UndoStack()
        let t = Commands.run(s, Commands.emptyTrack(), "setRuler", { a: { x: 0, y: 0 }, b: { x: 50, y: 0 }, realLength: 0 })
        compare(t.photo.metresPerPixel, 0)
        t = Commands.run(s, t, "removeRuler", {})
        compare(t.ruler, null)
    }

    function meets(track, aId, aEnd, bId, bEnd) {
        const pa = Elements.endsWorld(byId(track, aId))[aEnd]
        const pb = Elements.endsWorld(byId(track, bId))[bEnd]
        return Math.hypot(pa.x - pb.x, pa.y - pb.y) < 1e-6
    }

    // Every join is mutual and its ends meet; returns how many ends are joined.
    function allJoinsHold(t) {
        let n = 0
        for (const el of t.elements)
            for (const end of ["A", "B"]) {
                const mate = el.joins[end]
                if (!mate)
                    continue
                n += 1
                compare(byId(t, mate.id).joins[mate.end].id, el.id, el.id + "." + end + " is joined back")
                verify(meets(t, el.id, end, mate.id, mate.end), el.id + "." + end + " meets its mate")
            }
        return n
    }

    // Four quarter turns joined into a closed ring.
    function ring() {
        const turn = { angle: 90, radius: 6, leadIn: 0, leadOut: 0 }
        const s = new Commands.UndoStack()
        let t = Commands.run(s, Commands.emptyTrack(), "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 })
        t = Commands.run(s, t, "add", { type: "turn", x: 20, y: 20, props: turn })
        for (const id of ["e1", "e2", "e3"])
            t = Commands.run(s, t, "add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: id, end: "B" } })
        const e1 = byId(t, "e1")
        return Commands.run(s, t, "place", { id: "e1", x: e1.x, y: e1.y, rotation: e1.rotation,
                                             snap: { ownEnd: "A", id: "e4", end: "B" } })
    }

    function test_reversingKeepsTheChainJoined() {
        const t0 = base()
        const t = Commands.run(new Commands.UndoStack(), t0, "reverse", { ids: ["e2"] })
        const e2 = byId(t, "e2")
        compare(e2.props.direction, "left")
        compare(e2.joins.A.id, "e3")
        compare(e2.joins.B.id, "e1")
        compare(JSON.stringify(byId(t, "e1").joins.B), JSON.stringify({ id: "e2", end: "B" }))
        compare(JSON.stringify(byId(t, "e3").joins.A), JSON.stringify({ id: "e2", end: "A" }))
        compare(allJoinsHold(t), 4)
        for (const id of ["e1", "e3"]) {
            compare(byId(t, id).x, byId(t0, id).x)
            compare(byId(t, id).y, byId(t0, id).y)
            compare(byId(t, id).rotation, byId(t0, id).rotation)
        }
    }

    function test_reversingTwiceIsWhereYouStarted() {
        const t0 = base()
        const s = new Commands.UndoStack()
        const t = Commands.run(s, Commands.run(s, t0, "reverse", { ids: ["e2"] }), "reverse", { ids: ["e2"] })
        const a = byId(t0, "e2")
        const b = byId(t, "e2")
        compare(JSON.stringify(b.props), JSON.stringify(a.props))
        compare(JSON.stringify(b.joins), JSON.stringify(a.joins))
        verify(Math.abs(b.x - a.x) < 1e-9 && Math.abs(b.y - a.y) < 1e-9, "same place")
        verify(Math.abs(Elements.normalizeAngle(b.rotation - a.rotation)) < 1e-9, "same rotation")
    }

    function test_reversingInsideAClosedLoopKeepsItClosed() {
        const t0 = ring()
        const stack = new Commands.UndoStack()
        const t = Commands.run(stack, t0, "reverse", { ids: ["e2"] })
        compare(allJoinsHold(t), 8)
        compare(JSON.stringify(stack.undo()), JSON.stringify(t0))
    }

    function test_typingARotationTurnsTheWholeChain() {
        const t0 = base()
        const t = Commands.run(new Commands.UndoStack(), t0, "rotateChain", { id: "e1", rotation: 90 })
        compare(byId(t, "e1").rotation, 90)
        compare(byId(t, "e1").x, byId(t0, "e1").x)
        compare(byId(t, "e1").y, byId(t0, "e1").y)
        compare(allJoinsHold(t), 4)
        verify(Math.abs(Elements.normalizeAngle(byId(t, "e3").rotation - byId(t0, "e3").rotation - 90)) < 1e-9,
               "the far end turned too")
    }

    function test_anUnjoinedElementTurnsAlone() {
        const s = new Commands.UndoStack()
        const t0 = Commands.run(s, base(), "add", { type: "slalom", x: 40, y: 40 })
        const t = Commands.run(s, t0, "rotateChain", { id: "e4", rotation: -30 })
        compare(byId(t, "e4").rotation, -30)
        for (const id of ["e1", "e2", "e3"])
            compare(JSON.stringify(byId(t, id)), JSON.stringify(byId(t0, id)))
    }

    function test_aTypedRotationWraps() {
        const t = Commands.run(new Commands.UndoStack(), base(), "rotateChain", { id: "e1", rotation: 270 })
        compare(byId(t, "e1").rotation, -90)
    }

    function test_severalElementsChangeTogether() {
        const stack = new Commands.UndoStack()
        const t = Commands.run(stack, base(), "setProps", { ids: ["e1", "e2"], key: "trackWidth", value: 50 })
        compare(byId(t, "e1").props.trackWidth, 20)
        compare(byId(t, "e2").props.trackWidth, 20)
        compare(stack.undoLabel(), "Change Track width (2 elements)")
        stack.seal()
        const t2 = Commands.run(stack, t, "setProps", { ids: ["e1", "e3"], key: "length", value: 30 })
        compare(byId(t2, "e3").props.length, 30)
        compare(allJoinsHold(t2), 4)
        const one = Commands.run(new Commands.UndoStack(), base(), "setProps", { ids: ["e2"], key: "radius", value: 8 })
        compare(byId(one, "e2").props.radius, 8)
    }

    function test_deletingSeveral() {
        const stack = new Commands.UndoStack()
        const t = Commands.run(stack, base(), "removeMany", { ids: ["e1", "e3"] })
        compare(t.elements.length, 1)
        compare(JSON.stringify(byId(t, "e2").joins), JSON.stringify({ A: null, B: null }))
        compare(stack.undoLabel(), "Delete 2 elements")
        Commands.run(stack, base(), "removeMany", { ids: ["e2"] })
        compare(stack.undoLabel(), "Delete Turn")
    }

    function test_duplicatingSeveralKeepsTheirJoins() {
        const stack = new Commands.UndoStack()
        const t0 = base()
        const t = Commands.run(stack, t0, "duplicateMany", { ids: ["e1", "e2"] })
        compare(t.elements.length, 5)
        compare(JSON.stringify(byId(t, "e4").joins), JSON.stringify({ A: null, B: { id: "e5", end: "A" } }))
        compare(JSON.stringify(byId(t, "e5").joins), JSON.stringify({ A: { id: "e4", end: "B" }, B: null }))
        compare(byId(t, "e4").x, byId(t0, "e1").x + 2)
        compare(byId(t, "e5").y, byId(t0, "e2").y + 2)
        compare(t.nextId, 6)
        compare(stack.undoLabel(), "Duplicate 2 elements")
        compare(allJoinsHold(t), 6)
    }

    function test_aGroupDragKeepsInnerJoinsAndBreaksOuterOnes() {
        const t0 = base()
        const e1 = byId(t0, "e1")
        const e2 = byId(t0, "e2")
        const stack = new Commands.UndoStack()
        const t = Commands.run(stack, t0, "placeMany", {
            moves: [{ id: "e1", x: e1.x + 30, y: e1.y, rotation: e1.rotation },
                    { id: "e2", x: e2.x + 30, y: e2.y, rotation: e2.rotation }], snap: null })
        compare(byId(t, "e1").joins.B.id, "e2")
        verify(meets(t, "e1", "B", "e2", "A"))
        compare(byId(t, "e2").joins.B, null)
        compare(byId(t, "e3").joins.A, null)
        compare(stack.undoLabel(), "Move 2 elements")
        compare(JSON.stringify(stack.undo()), JSON.stringify(t0))
    }

    function test_aGroupDragCanSnap() {
        const t0 = base()
        const e3 = byId(t0, "e3")
        const s = new Commands.UndoStack()
        let t = Commands.run(s, t0, "placeMany", { moves: [{ id: "e3", x: e3.x + 50, y: e3.y, rotation: e3.rotation }], snap: null })
        compare(byId(t, "e3").joins.A, null)
        t = Commands.run(s, t, "placeMany", { moves: [{ id: "e3", x: e3.x, y: e3.y, rotation: e3.rotation }],
                                              snap: { ownId: "e3", ownEnd: "A", id: "e2", end: "B" } })
        compare(byId(t, "e3").joins.A.id, "e2")
        compare(byId(t, "e2").joins.B.id, "e3")
    }

    // A skidpad figure 8: two full loops, one each way, joined.
    function test_aFigureEightIsTwoJoinedLoops() {
        const s = new Commands.UndoStack()
        let t = Commands.emptyTrack()
        t = Commands.run(s, t, "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 })
        t = Commands.run(s, t, "add", { type: "turn", x: 30, y: 30, props: { angle: 360, leadOut: 0, radius: 9 } })
        t = Commands.run(s, t, "add", { type: "turn", x: 0, y: 0, props: { angle: 360, leadIn: 0, radius: 9, direction: "left" },
                                        snap: { ownEnd: "A", id: "e1", end: "B" } })
        compare(byId(t, "e1").joins.B.id, "e2")
        verify(endsMeet(t, "e1", "B", "e2", "A"))
        compare(byId(t, "e1").joins.A, null)
        compare(byId(t, "e2").joins.B, null)
    }

    function test_stretchMovesAndChangesOneSettingAsOneStep() {
        const s = new Commands.UndoStack()
        const t0 = base()
        const t1 = Commands.run(s, t0, "stretch", { id: "e3", x: 1, y: 2, rotation: 400, key: "length", value: 30, mergeKey: "g1" })
        compare(byId(t1, "e3").rotation, 40)
        const t2 = Commands.run(s, t1, "stretch", { id: "e3", x: 1, y: 3, rotation: 40, key: "length", value: 300, mergeKey: "g1" })
        compare(byId(t2, "e3").props.length, 200)            // kept within its limits
        compare(s.undoLabel(), "Stretch Straight")
        compare(s.done.length, 1)
        compare(JSON.stringify(s.undo()), JSON.stringify(t0))
    }
}
