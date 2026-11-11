import QtQuick
import QtTest
import "../../qml/logic/frame.mjs" as Frame

TestCase {
    name: "Frame"

    // Origin at (10 m, 10 m); Direction straight up the screen, 10 m away.
    function upFrame() {
        return Frame.makeFrame({ x: 100, y: 100 }, { x: 100, y: 0 }, 0.1)
    }

    function near(p, x, y) {
        verify(Math.abs(p.x - x) < 1e-9 && Math.abs(p.y - y) < 1e-9, "(" + p.x + ", " + p.y + ") should be (" + x + ", " + y + ")")
    }

    function test_originIsZero() {
        near(Frame.toFrame(upFrame(), { x: 10, y: 10 }), 0, 0)
    }

    function test_directionLiesOnPlusX() {
        const f = upFrame()
        near(Frame.toFrame(f, { x: 10, y: 0 }), 10, 0)
        fuzzyCompare(f.distance, 10, 1e-9)
    }

    function test_leftOfTheAxisIsPlusY() {
        near(Frame.toFrame(upFrame(), { x: 9, y: 10 }), 0, 1)
        near(Frame.toFrame(upFrame(), { x: 11, y: 5 }), 5, -1)
        // An axis along the screen: left of it is up the screen.
        const along = Frame.makeFrame({ x: 0, y: 50 }, { x: 400, y: 50 }, 0.1)
        near(Frame.toFrame(along, { x: 3, y: 2 }), 3, 3)
    }

    function test_headingsAreCounterClockwise() {
        const f = upFrame()
        compare(Frame.headingToFrame(f, -90), 0)
        compare(Frame.headingToFrame(f, 180), 90)
        compare(Frame.headingToFrame(f, 0), -90)
    }

    function test_fromFrameUndoesToFrame() {
        const f = Frame.makeFrame({ x: 37, y: 120 }, { x: 410, y: -55 }, 0.073)
        for (const p of [{ x: 0, y: 0 }, { x: 12.5, y: -3 }, { x: -40, y: 81 }]) {
            const back = Frame.fromFrame(f, Frame.toFrame(f, p))
            near(back, p.x, p.y)
        }
    }

    function test_noFrameWithoutBothTargetsAndAScale() {
        compare(Frame.makeFrame(null, { x: 1, y: 1 }, 0.1), null)
        compare(Frame.makeFrame({ x: 1, y: 1 }, null, 0.1), null)
        compare(Frame.makeFrame({ x: 1, y: 1 }, { x: 5, y: 1 }, 0), null)
        compare(Frame.makeFrame({ x: 1, y: 1 }, { x: 1, y: 1 }, 0.1), null)
    }

    function test_normalize() {
        compare(Frame.normalize(190), -170)
        compare(Frame.normalize(-190), 170)
        compare(Frame.normalize(-180), 180)
        compare(Frame.normalize(540), 180)
        compare(Frame.normalize(0), 0)
    }
}
