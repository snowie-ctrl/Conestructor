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
            { tag: "duplicate", name: "duplicate", args: { id: "e1" } }
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
}
