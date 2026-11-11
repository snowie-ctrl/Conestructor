import QtQuick
import QtTest
import "../../qml/logic/commands.mjs" as Commands
import "../../qml/logic/setup.mjs" as Setup

TestCase {
    name: "Setup"

    function after(steps) {
        const s = new Commands.UndoStack()
        let t = Commands.emptyTrack()
        for (const step of steps)
            t = Commands.run(s, t, step[0], step[1])
        return t
    }

    function test_aNewTrackHasNothingDone() {
        const s = Setup.status(Commands.emptyTrack())
        compare(JSON.stringify(s), JSON.stringify({ photo: false, ruler: false, origin: false, direction: false,
                                                    count: 0, done: false }))
    }

    function test_eachStepTicks() {
        const steps = [["setPhoto", { kind: "blueprint" }]]
        compare(Setup.status(after(steps)).count, 1)
        steps.push(["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 0 }])
        verify(!Setup.status(after(steps)).ruler, "a ruler without a length is not done")
        steps.push(["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 }])
        verify(Setup.status(after(steps)).ruler)
        steps.push(["setTarget", { which: "origin", point: { x: 50, y: 50 } }])
        verify(Setup.status(after(steps)).origin)
        steps.push(["setTarget", { which: "direction", point: { x: 55, y: 50 } }])      // 0.5 m away
        verify(!Setup.status(after(steps)).direction, "too close to Origin")
        steps.push(["setTarget", { which: "direction", point: { x: 150, y: 50 } }])
        const s = Setup.status(after(steps))
        verify(s.direction)
        compare(s.count, 4)
        verify(s.done)
    }

    function test_aLotPhotoCountsToo() {
        verify(Setup.status(after([["setPhoto", { kind: "image", ref: 1 }]])).photo)
    }

    function test_directionWithNothingToMeasureCountsWhenPlaced() {
        verify(Setup.status(after([["setTarget", { which: "direction", point: { x: 1, y: 1 } }]])).direction)
    }
}
