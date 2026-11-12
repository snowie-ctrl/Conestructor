import QtQuick
import QtTest
import "../../qml/logic/car.mjs" as Car

TestCase {
    name: "Car"

    function test_aPointInsideTheTurnedCar() {
        const car = { x: 10, y: 5, rotation: 90 }            // its front points down the screen
        verify(Car.contains(car, 3, 1.4, { x: 10, y: 6.4 }))  // 1.4 m toward the front
        verify(!Car.contains(car, 3, 1.4, { x: 11, y: 5 }))   // 1 m to the side of a 1.4 m-wide car
        verify(!Car.contains(car, 3, 1.4, { x: 10, y: 6.6 })) // past the nose
    }

    function test_theCornersGoRoundFromTheFrontLeft() {
        const c = Car.corners({ x: 0, y: 0, rotation: 0 }, 4, 2)
        compare(c.map(p => p.x + "," + p.y).join(" "), "2,-1 2,1 -2,1 -2,-1")
    }

    function test_theHandleSitsBeyondTheNose() {
        const h = Car.handle({ x: 0, y: 0, rotation: 90 }, 3, 0.5)
        fuzzyCompare(h.x, 0, 1e-9)
        fuzzyCompare(h.y, 2, 1e-9)
    }

    function test_facingAPoint() {
        compare(Car.facing({ x: 0, y: 0 }, { x: 0, y: 5 }, 0), 90)
        compare(Car.facing({ x: 0, y: 0 }, { x: 1, y: 1.1 }, 15), 45)
    }
}
