import QtQuick
import QtTest
import "../../qml/logic/viewport.mjs" as Viewport

TestCase {
    name: "Viewport"

    function test_fitCentresTheWholePhoto() {
        const v = Viewport.fit(1000, 500, 1280, 720)
        fuzzyCompare(v.zoom, 500 / 720 * 0.95, 1e-12)
        const centre = Viewport.toScreen(v, 640, 360)
        fuzzyCompare(centre.x, 500, 1e-9)
        fuzzyCompare(centre.y, 250, 1e-9)
        const corner = Viewport.toScreen(v, 1280, 720)
        verify(corner.x <= 1000 && corner.y <= 500)
    }

    function test_fitWithNothingToFit() {
        compare(JSON.stringify(Viewport.fit(0, 500, 1280, 720)), JSON.stringify({ zoom: 1, panX: 0, panY: 0 }))
    }

    function test_zoomKeepsThePointUnderTheCursor() {
        const v0 = { zoom: 1.3, panX: -40, panY: 25 }
        const under = Viewport.toWorld(v0, 300, 200)
        const v1 = Viewport.zoomAt(v0, 1.7, 300, 200, 0.1, 50)
        fuzzyCompare(v1.zoom, 1.3 * 1.7, 1e-12)
        const after = Viewport.toScreen(v1, under.x, under.y)
        fuzzyCompare(after.x, 300, 1e-9)
        fuzzyCompare(after.y, 200, 1e-9)
    }

    function test_zoomStaysWithinItsLimits() {
        compare(Viewport.zoomAt({ zoom: 1, panX: 0, panY: 0 }, 100, 0, 0, 0.1, 10).zoom, 10)
        compare(Viewport.zoomAt({ zoom: 1, panX: 0, panY: 0 }, 0.001, 0, 0, 0.1, 10).zoom, 0.1)
    }

    function test_screenAndWorldAreInverses() {
        const v = { zoom: 2.5, panX: 13, panY: -7 }
        const w = Viewport.toWorld(v, 101, 57)
        const s = Viewport.toScreen(v, w.x, w.y)
        fuzzyCompare(s.x, 101, 1e-9)
        fuzzyCompare(s.y, 57, 1e-9)
    }

    function test_limitsReachFromTheWholePhotoToSingleCones() {
        const l = Viewport.limits(0.5, 0.1)
        compare(l.min, 0.25)
        fuzzyCompare(l.max, 80 * 0.1 / Viewport.CONE_METRES, 1e-9)
        const noScale = Viewport.limits(0.5, 0)
        compare(noScale.max, 16)
    }
}
