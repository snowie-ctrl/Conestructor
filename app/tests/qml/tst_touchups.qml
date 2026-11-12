import QtQuick
import QtTest
import "../../qml/logic/commands.mjs" as Commands
import "../../qml/logic/demo.mjs" as Demo
import "../../qml/logic/postprocess.mjs" as Post
import "../../qml/logic/touchups.mjs" as Touchups

TestCase {
    name: "TouchUps"

    function frozen() {
        return Touchups.freeze(Demo.demoTrack())
    }

    function test_freezingKeepsThePlacedCones() {
        const placed = Post.run(Demo.demoTrack()).canvasCones
        const u = frozen()
        compare(u.placed, placed.length)
        compare(u.cones.length, placed.length)
        for (let i = 0; i < placed.length; i++) {
            compare(u.cones[i].x, placed[i].x)
            compare(u.cones[i].y, placed[i].y)
            compare(u.cones[i].type, placed[i].type)
            compare(u.cones[i].element, placed[i].element)
            compare(u.cones[i].edited, false)
        }
        compare(Touchups.changes(u), 0)
        compare(Touchups.changes(null), 0)
    }

    function test_aTrackThatCannotBeProcessedHasNothingToFreeze() {
        compare(Touchups.freeze(Commands.emptyTrack()), null)
    }

    function test_deletingCones() {
        const u = frozen()
        const one = Touchups.removeCones(u, [0])
        compare(one.cones.length, u.cones.length - 1)
        compare(one.cones[0].x, u.cones[1].x)
        compare(Touchups.changes(one), 1)
        const three = Touchups.removeCones(one, [0, 2, 99])
        compare(three.cones.length, u.cones.length - 3)
        compare(Touchups.changes(three), 3)
        compare(u.cones.length, u.placed, "the old touch-ups are not changed")
    }

    function test_movingAConeKeepsItsPlaceInTheOrder() {
        const u = frozen()
        const moved = Touchups.moveCone(u, 2, 50, 60)
        compare(moved.cones[2].x, 50)
        compare(moved.cones[2].y, 60)
        compare(moved.cones[2].edited, true)
        compare(moved.cones[2].element, u.cones[2].element)
        compare(Touchups.changes(moved), 1)
        compare(Touchups.changes(Touchups.moveCone(moved, 2, 51, 60)), 1, "moving it again is still one change")
    }

    function test_retypingAndPointing() {
        const u = frozen()
        const standing = u.cones.findIndex(c => c.type === "standing")
        const leaning = Touchups.setType(u, [standing], "leaning")
        compare(leaning.cones[standing].type, "leaning")
        compare(leaning.cones[standing].heading, u.cones[standing].heading, "it keeps its heading")
        compare(leaning.cones[standing].edited, true)
        compare(JSON.stringify(Touchups.setType(u, [standing], "standing").cones), JSON.stringify(u.cones),
                "already standing: nothing changes")
        const turned = Touchups.pointCone(leaning, standing, 135)
        compare(turned.cones[standing].heading, 135)
        compare(Touchups.changes(turned), 1)
    }

    function test_anAddedConeComesLast() {
        const u = frozen()
        const added = Touchups.addCone(u, 5, 6)
        compare(added.cones.length, u.cones.length + 1)
        const last = added.cones[added.cones.length - 1]
        compare(last.type, "standing")
        compare(last.x, 5)
        compare(last.y, 6)
        compare(last.heading, 0)
        compare(last.element, null)
        compare(last.edited, true)
        compare(Touchups.changes(added), 1)
        compare(Touchups.changes(Touchups.removeCones(added, [added.cones.length - 1])), 0, "added then deleted: no change")
    }

    function test_pickingTheNearestConeWithinItsFootprint() {
        const cones = [{ type: "standing", x: 0, y: 0 }, { type: "leaning", x: 0.3, y: 0 }, { type: "standing", x: 5, y: 5 }]
        compare(Touchups.coneAt(cones, { x: 0.05, y: 0 }, 0), 0)
        compare(Touchups.coneAt(cones, { x: 0.25, y: 0 }, 0), 1)
        compare(Touchups.coneAt(cones, { x: 5 + Touchups.STANDING_RADIUS + 0.01, y: 5 }, 0), -1)
        compare(Touchups.coneAt(cones, { x: 5 + Touchups.STANDING_RADIUS + 0.01, y: 5 }, 0.05), 2)
        compare(Touchups.coneAt(cones, { x: 0.3 + Touchups.LEANING_RADIUS - 0.01, y: 0 }, 0), 1)
        compare(Touchups.inBox(cones, { x: 6, y: 6 }, { x: -1, y: -1 }).join(","), "0,1,2")
        compare(Touchups.inBox(cones, { x: -1, y: -1 }, { x: 1, y: 1 }).join(","), "0,1")
    }

    function test_theResultIsWhatPlaceConesGaveUntilTouched() {
        const t = Demo.demoTrack()
        t.touchUps = Touchups.freeze(t)
        const touched = Touchups.result(t)
        const placed = Post.run(t)
        compare(touched.cones.length, placed.cones.length)
        for (let i = 0; i < placed.cones.length; i++) {
            compare(touched.cones[i].index, i)
            fuzzyCompare(touched.cones[i].x, placed.cones[i].x, 1e-9)
            fuzzyCompare(touched.cones[i].y, placed.cones[i].y, 1e-9)
            fuzzyCompare(touched.cones[i].heading, placed.cones[i].heading, 1e-9)
            compare(touched.canvasCones[i].x, placed.canvasCones[i].x)
        }
        compare(touched.targetDistance, placed.targetDistance)
    }
}
