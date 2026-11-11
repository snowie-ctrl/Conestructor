import QtQuick
import QtTest
import "../../qml/logic/postprocess.mjs" as Post
import "../../qml/logic/units.mjs" as Units
import "fixtures/prototype.mjs" as Prototype
import "fixtures/sampletrack.mjs" as Sample

// The spec's port check: the sample track through the prototype's cone code and through the new code gives the same
// cones, once the prototype's feet become metres, its y (to the right) is flipped to the left, and its clockwise
// headings become counter-clockwise. Part 2 orders cones by the arrows (tested in tst_postprocess), so here the
// cones are compared as a set: every prototype cone must match one of ours exactly.
TestCase {
    name: "PortCheck"

    function angleGap(a, b) {
        let d = (a - b) % 360
        if (d > 180) d -= 360
        if (d < -180) d += 360
        return Math.abs(d)
    }

    function test_theSampleTrackCoversWhatMatters() {
        const t = Sample.track()
        compare(t.elements.length, 6)
        compare(t.elements[3].joins.B.id, "e3")         // the chicane is entered at its exit
        compare(t.elements[4].joins.A, null)            // the lone straight
    }

    function test_conesMatchThePrototype() {
        const t = Sample.track()
        const ours = Post.run(t)
        verify(!ours.error, ours.error ? ours.error.message : "")
        const theirs = Prototype.run(Sample.prototypeElements(t), Sample.pixelsPerFoot(t),
                                     Sample.prototypeTarget(t.targets.origin), Sample.prototypeTarget(t.targets.direction))
        compare(ours.cones.length, theirs.length)
        verify(theirs.length > 60, "a real sample: " + theirs.length + " cones")
        const unmatched = ours.cones.slice()
        for (let i = 0; i < theirs.length; i++) {
            const b = theirs[i]
            const k = unmatched.findIndex(a => a.type === b.coneType
                                          && Math.abs(a.x - b.x * Units.FOOT) < 1e-6
                                          && Math.abs(a.y + b.y * Units.FOOT) < 1e-6
                                          && angleGap(a.heading, -b.heading) < 1e-6)
            verify(k >= 0, "prototype cone " + i + " (" + b.coneType + " at " + (b.x * Units.FOOT) + ", "
                           + (-b.y * Units.FOOT) + ") has no match")
            unmatched.splice(k, 1)
        }
    }
}
