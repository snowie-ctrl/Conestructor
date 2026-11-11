import QtQuick
import QtTest
import "../../qml/logic/elements.mjs" as Elements
import "../../qml/logic/selection.mjs" as Selection

TestCase {
    name: "Selection"

    function el(id, type, props, x, y, rotation) {
        return { id: id, type: type, x: x || 0, y: y || 0, rotation: rotation || 0,
                 props: Object.assign(Elements.defaults(type), props || {}), joins: { A: null, B: null } }
    }

    function keys(list) {
        return list.map(s => s.def.key).join(",")
    }

    function test_aStraightAndATurnShareOnlyTheTrackWidth() {
        compare(keys(Selection.sharedProps([el("e1", "straight"), el("e2", "turn")])), "trackWidth")
    }

    function test_turnsAndChicanesShareLeadsAndDirection() {
        compare(keys(Selection.sharedProps([el("e1", "turn"), el("e2", "chicane")])), "leadIn,leadOut,direction,trackWidth")
    }

    function test_differentValuesAreMixed() {
        const shared = Selection.sharedProps([el("e1", "straight", { trackWidth: 4 }), el("e2", "straight", { trackWidth: 5 })])
        const width = shared.find(s => s.def.key === "trackWidth")
        verify(width.mixed)
        compare(width.value, null)
        const length = shared.find(s => s.def.key === "length")
        verify(!length.mixed)
        compare(length.value, 20)
    }

    function test_exitRadiusOnlyWhenAllAreChanging() {
        const changing = { radiusType: "changing" }
        verify(keys(Selection.sharedProps([el("e1", "turn", changing), el("e2", "turn", changing)])).indexOf("exitRadius") >= 0)
        const mixed = Selection.sharedProps([el("e1", "turn", changing), el("e2", "turn")])
        compare(keys(mixed).indexOf("exitRadius"), -1)
        verify(mixed.find(s => s.def.key === "radiusType").mixed)
    }

    function test_nothingSelectedSharesNothing() {
        compare(Selection.sharedProps([]).length, 0)
    }

    function test_aBoxTouchingTheBandSelects() {
        // A 20 m straight from (0, 5) to (20, 5), 4 m wide: its band runs from y 3 to y 7.
        const list = [el("e1", "straight", {}, 10, 5, 0)]
        compare(JSON.stringify(Selection.boxHits(list, { x: 8, y: 6.5 }, { x: 12, y: 8 })), JSON.stringify(["e1"]))
        compare(JSON.stringify(Selection.boxHits(list, { x: 12, y: 8 }, { x: 8, y: 6.5 })), JSON.stringify(["e1"]))
        compare(JSON.stringify(Selection.boxHits(list, { x: 9, y: 4.5 }, { x: 11, y: 5.5 })), JSON.stringify(["e1"]))
        compare(Selection.boxHits(list, { x: 8, y: -1 }, { x: 12, y: 1 }).length, 0)
        compare(Selection.boxHits(list, { x: 25, y: 4 }, { x: 30, y: 6 }).length, 0)
    }

    function test_aLineAndAStraightShareOnlyTheLength() {
        compare(keys(Selection.sharedProps([el("e1", "straight"), el("e2", "line")])), "length")
        compare(keys(Selection.sharedProps([el("e1", "turn"), el("e2", "line")])), "")
    }

    function test_theBoxPicksALineWithinHalfAMetre() {
        const line = el("e1", "line")
        compare(JSON.stringify(Selection.boxHits([line], { x: -1, y: 0.4 }, { x: 1, y: 1 })), JSON.stringify(["e1"]))
        compare(JSON.stringify(Selection.boxHits([line], { x: -1, y: 0.6 }, { x: 1, y: 1 })), "[]")
    }
}
