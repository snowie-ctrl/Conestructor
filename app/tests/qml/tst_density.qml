import QtQuick
import QtTest
import "../../qml/logic/density.mjs" as Density

TestCase {
    name: "Density"

    function test_theFiveNotches() {
        compare(Density.NOTCHES.join(","), "1,2,3,4,5")
        compare(Density.NOTCHES.map(n => Density.NAMES[n]).join(","), "Fewest,Fewer,SAE standard,More,Most")
        compare(Density.NOTCHES.map(n => Density.factor(n)).join(","), "2,1.5,1,0.75,0.5")
        compare(Density.STANDARD, 3)
    }

    function test_aTrackWithoutANotchIsSAEStandard() {
        compare(Density.trackNotch({}), 3)
        compare(Density.trackNotch({ density: 5 }), 5)
        compare(Density.trackNotch({ density: 9 }), 3)
    }

    function test_anElementsOwnNotchBeatsTheTracks() {
        compare(Density.elementNotch({ props: { density: 0 } }, 4), 4)
        compare(Density.elementNotch({ props: {} }, 2), 2)
        compare(Density.elementNotch({ props: { density: 1 } }, 4), 1)
    }
}
