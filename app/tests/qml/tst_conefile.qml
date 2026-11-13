import QtQuick
import QtTest
import "../../qml/logic/commands.mjs" as Commands
import "../../qml/logic/conefile.mjs" as ConeFile
import "../../qml/logic/demo.mjs" as Demo
import "../../qml/logic/elements.mjs" as Elements
import "../../qml/logic/touchups.mjs" as Touchups
import "fixtures/schemacheck.mjs" as SchemaCheck

TestCase {
    name: "ConeFile"

    property var schema: null
    property bool schemaRead: false
    readonly property var info: ({ name: "Duck pond", app: "Conestructor 0.3.0", saved: "2026-11-10T14:03:00Z" })

    // The schema is read from docs/ (run.ps1 sets QML_XHR_ALLOW_FILE_READ=1 so XMLHttpRequest may read files).
    function initTestCase() {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                schema = xhr.responseText ? JSON.parse(xhr.responseText) : null
                schemaRead = true
            }
        }
        xhr.open("GET", Qt.resolvedUrl("../../../docs/cone-format.schema.json"))
        xhr.send()
        tryVerify(() => schemaRead, 5000, "docs/cone-format.schema.json was read")
        verify(schema !== null, "the schema is JSON")
    }

    function doc(track) {
        return JSON.parse(ConeFile.documentText(track, info))
    }

    function withPhoto(track, ref) {
        return Commands.run(new Commands.UndoStack(), track, "setPhoto", { kind: "image", ref: ref })
    }

    function test_theDocumentReadsInFileOrder() {
        const text = ConeFile.documentText(Demo.demoTrack(), info)
        compare(Object.keys(JSON.parse(text)).join(","), "format,version,name,app,saved,units,axes,targets,cones,design")
        verify(text.startsWith('{\n  "format": "conestructor-track",\n  "version": 1,'), text.slice(0, 80))
        compare(ConeFile.timestamp(new Date(Date.UTC(2026, 10, 10, 14, 3, 0, 456))), "2026-11-10T14:03:00Z")
    }

    function test_conesAndTargetsAreInTheExportFrame() {
        const d = doc(Demo.demoTrack())
        compare(JSON.stringify(d.targets), JSON.stringify({ origin: { x: 0, y: 0 }, direction: { x: 100, y: 0 }, distance: 100 }))
        verify(d.cones.length > 40, d.cones.length + " cones")
        compare(d.cones[0].index, 0)
        compare(d.cones[0].element, "e1")
        for (const c of d.cones) {
            verify(c.type === "standing" || c.type === "leaning", c.type)
            if (c.type === "standing")
                compare(c.heading, 0, "a standing cone has no heading (cone " + c.index + ")")
            verify(Math.abs(c.x * 1000 - Math.round(c.x * 1000)) < 1e-6, "x to the millimetre: " + c.x)
        }
        verify(d.cones.some(c => c.type === "leaning" && c.heading !== 0), "leaning cones keep their headings")
        compare(d.units, "m")
        compare(d.axes, "x toward Direction target, y to the left, heading degrees counter-clockwise from +x")
    }

    function test_anUnfinishedTrackStillSaves() {
        const d = doc(Commands.emptyTrack())
        compare(d.cones.length, 0)
        compare(JSON.stringify(d.targets), JSON.stringify({ origin: null, direction: null, distance: null }))
    }

    function test_theDesignHoldsNoPhotoBytes() {
        compare(JSON.stringify(doc(withPhoto(Demo.demoTrack(), 5)).design.photo),
                JSON.stringify({ kind: "image", metresPerPixel: 0.1 }))
    }

    function test_aTrackComesBackExactly() {
        const t = withPhoto(Demo.demoTrack(), 9)
        const back = ConeFile.fromDocument(doc(t), 9)
        verify(!back.error, back.error)
        compare(JSON.stringify(back.track), JSON.stringify(t))
        compare(back.warning, "")
        compare(JSON.stringify(ConeFile.fromDocument(doc(Demo.demoTrack()), -1).track), JSON.stringify(Demo.demoTrack()))
        compare(JSON.stringify(ConeFile.fromDocument(doc(Commands.emptyTrack()), -1).track),
                JSON.stringify(Commands.emptyTrack()))
    }

    function test_refusals_data() {
        return [
            { tag: "not an object", what: "array", error: ConeFile.MESSAGES.notTrack },
            { tag: "another format", what: "format", error: ConeFile.MESSAGES.notTrack },
            { tag: "a newer version", what: "newer", error: ConeFile.MESSAGES.newer },
            { tag: "a version that is not a number", what: "version", error: ConeFile.MESSAGES.damaged },
            { tag: "no design", what: "design", error: ConeFile.MESSAGES.damaged },
            { tag: "an unknown element type", what: "type", error: ConeFile.MESSAGES.damaged },
            { tag: "a join that is not mutual", what: "join", error: ConeFile.MESSAGES.damaged },
            { tag: "elements without a ruler", what: "ruler", error: ConeFile.MESSAGES.damaged },
            { tag: "two elements with one id", what: "twins", error: ConeFile.MESSAGES.damaged }
        ]
    }

    function test_refusals(row) {
        let d = doc(Demo.demoTrack())
        switch (row.what) {
        case "array": d = []; break
        case "format": d.format = "geojson"; break
        case "newer": d.version = 2; break
        case "version": d.version = "one"; break
        case "design": d.design = null; break
        case "type": d.design.elements[0].type = "loop"; break
        case "join": d.design.elements[1].joins.A = null; break
        case "ruler": d.design.ruler = null; break
        case "twins": d.design.elements[1].id = "e1"; break
        }
        compare(ConeFile.fromDocument(d, -1).error, row.error)
    }

    function test_aPhotoThatCannotBeReadOpensOnTheBlueprint() {
        const back = ConeFile.fromDocument(doc(withPhoto(Demo.demoTrack(), 4)), -1)
        compare(JSON.stringify(back.track.photo), JSON.stringify({ kind: "none", ref: null, metresPerPixel: 0.1 }))
        compare(back.warning, ConeFile.MESSAGES.photo)
    }

    function test_aHandEditedFileIsReadSafely() {
        const d = doc(Demo.demoTrack())
        d.design.elements[0].props.trackWidth = 500           // beyond its limit
        delete d.design.elements[1].props.coneSpacing         // missing
        d.design.photo.metresPerPixel = 3                     // ignored: the ruler sets the scale
        d.design.nextId = 2                                   // too low for e4
        const back = ConeFile.fromDocument(d, -1)
        verify(!back.error, back.error)
        compare(back.track.elements[0].props.trackWidth, 20)
        compare(back.track.elements[1].props.coneSpacing, 10)
        compare(back.track.photo.metresPerPixel, 0.1)
        compare(back.track.nextId, 5)
    }

    function test_theDocumentMatchesTheSchema() {
        for (const t of [Demo.demoTrack(), Commands.emptyTrack()]) {
            const d = doc(t)
            d.photo = null
            compare(SchemaCheck.problems(schema, d).join("; "), "")
            d.photo = { mediaType: "image/png", width: 1280, height: 720, data: "iVBORw0KGgo=" }
            compare(SchemaCheck.problems(schema, d).join("; "), "")
        }
        const bad = doc(Demo.demoTrack())
        bad.photo = null
        bad.cones[0].type = "upright"
        delete bad.units
        const found = SchemaCheck.problems(schema, bad)
        compare(found.length, 2, found.join("; "))
    }

    // Two straights joined e1.B - e2.A, as a document to edit by hand.
    function joinedDoc() {
        const s = new Commands.UndoStack()
        let t = Commands.emptyTrack()
        t = Commands.run(s, t, "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 })
        t = Commands.run(s, t, "add", { type: "straight", x: 10, y: 5 })
        t = Commands.run(s, t, "add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } })
        return doc(t)
    }

    function test_selfJoinsAndReservedIdsAreDamaged() {
        const self = joinedDoc()
        self.design.elements[0].joins.A = { id: "e1", end: "A" }
        compare(ConeFile.fromDocument(self, -1).error, ConeFile.MESSAGES.damaged)
        for (const id of ["ruler", "origin", "direction"]) {
            const d = joinedDoc()
            d.design.elements[0].id = id
            d.design.elements[1].joins.A = { id: id, end: "B" }
            compare(ConeFile.fromDocument(d, -1).error, ConeFile.MESSAGES.damaged, id)
        }
    }

    function test_joinedEndsApartAreUnjoined() {
        const apart = joinedDoc()
        apart.design.elements[1].x += 1
        const t = ConeFile.fromDocument(apart, -1).track
        compare(t.elements[0].joins.B, null)
        compare(t.elements[1].joins.A, null)
        const close = joinedDoc()
        close.design.elements[1].x += 0.01
        compare(ConeFile.fromDocument(close, -1).track.elements[0].joins.B.id, "e2")
    }

    function test_aJoinToALineIsDropped() {
        const d = joinedDoc()
        d.design.elements[1].type = "line"
        d.design.elements[1].props = { length: 20, spacing: 3 }
        const t = ConeFile.fromDocument(d, -1).track
        compare(t.elements[0].joins.B, null)
        compare(t.elements[1].joins.A, null)
    }

    function test_aLineRoundTripsAndItsConesComeLast() {
        let t = Demo.demoTrack()
        t = Commands.run(new Commands.UndoStack(), t, "add",
                         { type: "line", x: 120, y: 68, rotation: 30, props: { length: 12, spacing: 2 } })
        const d = doc(t)
        compare(JSON.stringify(ConeFile.fromDocument(d, -1).track), JSON.stringify(t))
        compare(d.cones.filter(c => c.element === "e5").length, 7)
        compare(d.cones.slice(-7).map(c => c.element).join(","), "e5,e5,e5,e5,e5,e5,e5")
    }

    function touchedUp() {
        const s = new Commands.UndoStack()
        let t = Demo.demoTrack()
        t = Commands.run(s, t, "deleteCones", { indices: [0] })
        t = Commands.run(s, t, "moveCone", { index: 1, x: 40, y: 40 })
        t = Commands.run(s, t, "addCone", { x: 5, y: 6 })
        return t
    }

    function test_theFileHoldsTheTouchedUpCones() {
        const t = touchedUp()
        const d = doc(t)
        compare(d.cones.length, t.touchUps.cones.length)
        d.cones.forEach((c, i) => compare(c.index, i))
        compare(d.cones[1].edited, true)
        verify(!("edited" in d.cones[0]), "an untouched cone carries no edited field")
        const last = d.cones[d.cones.length - 1]
        compare(last.element, null)
        compare(last.edited, true)
        compare(last.heading, 0)
        d.photo = null                                   // TrackFile adds the photo last
        compare(SchemaCheck.problems(schema, d).join("; "), "")
    }

    function test_aTouchedUpTrackComesBackLocked() {
        const t = touchedUp()
        const back = ConeFile.fromDocument(doc(t), -1).track
        compare(JSON.stringify(back), JSON.stringify(t))
        verify(Commands.locked(back))
    }

    // Part 4's minor 3: a hand-edited placed count below the cones still carrying an element is raised to it, so the
    // change count is never negative.
    function test_thePlacedCountIsNeverBelowTheKeptCones() {
        const d = doc(touchedUp())
        d.design.touchUps.placed = 2
        const back = ConeFile.fromDocument(d, -1).track
        const kept = back.touchUps.cones.filter(c => c.element !== null).length
        compare(back.touchUps.placed, kept)
        compare(Touchups.changes(back.touchUps), back.touchUps.cones.filter(c => c.edited).length)
    }

    function test_densityRoundTrips() {
        const t = Commands.run(new Commands.UndoStack(), Demo.demoTrack(), "setDensity", { notch: 5 })
        compare(ConeFile.fromDocument(doc(t), -1).track.density, 5)
        const old = doc(Demo.demoTrack())
        delete old.design.density
        delete old.design.touchUps
        const back = ConeFile.fromDocument(old, -1).track
        compare(back.density, 3)
        compare(back.touchUps, null)
    }

    function test_badDensityOrTouchUpsAreDamaged_data() {
        return [
            { tag: "density 7", change: d => { d.design.density = 7 } },
            { tag: "density text", change: d => { d.design.density = "most" } },
            { tag: "touchUps not an object", change: d => { d.design.touchUps = "x" } },
            { tag: "cones not a list", change: d => { d.design.touchUps.cones = {} } },
            { tag: "no placed count", change: d => { delete d.design.touchUps.placed } },
            { tag: "unknown cone type", change: d => { d.design.touchUps.cones[0].type = "flat" } },
            { tag: "cone without x", change: d => { delete d.design.touchUps.cones[0].x } },
            { tag: "element a number", change: d => { d.design.touchUps.cones[0].element = 4 } }
        ]
    }
    function test_badDensityOrTouchUpsAreDamaged(row) {
        const d = doc(touchedUp())
        row.change(d)
        compare(ConeFile.fromDocument(d, -1).error, ConeFile.MESSAGES.damaged)
    }

    // Review focus 4: touch-ups on a design that cannot be processed would open locked with no cones to show.
    function test_touchUpsNeedATrackThatCanBeProcessed() {
        const d = doc(touchedUp())
        d.design.targets.direction = null
        compare(ConeFile.fromDocument(d, -1).error, ConeFile.MESSAGES.damaged)
    }

    // Part 3's minor: joined ends a little apart in a hand-edited file are glued on open, so the next edit keeps them.
    function test_joinsSlightlyApartAreGluedOnOpen() {
        const d = joinedDoc()
        d.design.elements[1].x += 0.02
        const t = ConeFile.fromDocument(d, -1).track
        compare(t.elements[0].joins.B.id, "e2")
        const a = Elements.endsWorld(t.elements[0]).B
        const b = Elements.endsWorld(t.elements[1]).A
        verify(Math.hypot(a.x - b.x, a.y - b.y) < 1e-6, "glued exactly")
        const after = Commands.run(new Commands.UndoStack(), t, "setProp", { id: t.elements[0].id, key: "trackWidth", value: 5 })
        compare(after.elements[0].joins.B.id, "e2")
    }
}
