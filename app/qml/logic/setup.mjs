// The setup checklist: which of the four steps are done. Photo: a lot photo is loaded or the blueprint was chosen.
// Ruler: placed, with a real length. Origin: placed. Direction: placed, and at least 1 m from Origin whenever Origin
// and the ruler's scale are there to measure it. Tests: tests/qml/tst_setup.qml.
import * as Frame from "./frame.mjs"
import { MIN_TARGET_DISTANCE } from "./postprocess.mjs"

export function status(track) {
    const scale = track.photo.metresPerPixel
    const photo = track.photo.kind === "image" || track.photo.kind === "blueprint"
    const ruler = track.ruler !== null && scale > 0
    const origin = track.targets.origin !== null
    let direction = track.targets.direction !== null
    if (direction && origin && scale > 0) {
        const frame = Frame.makeFrame(track.targets.origin, track.targets.direction, scale)
        direction = frame !== null && frame.distance >= MIN_TARGET_DISTANCE
    }
    const count = [photo, ruler, origin, direction].filter(done => done).length
    return { photo: photo, ruler: ruler, origin: origin, direction: direction, count: count, done: count === 4 }
}

// The step to do now, the first not done: "photo", "ruler" (not placed), "rulerLength" (placed, no scale yet),
// "origin", "direction", or "" once setup is done.
export function current(track) {
    const s = status(track)
    if (!s.photo)
        return "photo"
    if (!s.ruler)
        return track.ruler === null ? "ruler" : "rulerLength"
    if (!s.origin)
        return "origin"
    if (!s.direction)
        return "direction"
    return ""
}

// The coach card for each step: why it matters and what to do. `button` starts the step: `kind` is the tile it picks
// up, or "rulerLength" to open the ruler's length box. The photo step has its own two buttons.
export const CARDS = {
    photo: {
        number: 1, title: "Step 1 of 4: Lot photo",
        text: "Start with a birdseye photo of the lot, or use the blueprint to sketch without one."
    },
    ruler: {
        number: 2, title: "Step 2 of 4: Ruler",
        text: "The ruler sets the photo's scale. Click one end of something you know the length of, such as a "
              + "parking-space line, then the other end.",
        button: "Place the ruler", kind: "ruler"
    },
    rulerLength: {
        number: 2, title: "Step 2 of 4: Ruler",
        text: "Now type how long that really is, in the box beside the ruler.",
        button: "Type its length", kind: "rulerLength"
    },
    origin: {
        number: 3, title: "Step 3 of 4: Origin",
        text: "Every cone is measured from Origin. Put it on something you can find on the real lot, such as the base "
              + "of a light pole or a drain.",
        button: "Place Origin", kind: "origin"
    },
    direction: {
        number: 4, title: "Step 4 of 4: Direction",
        text: "x points from Origin toward Direction. Pick a second landmark well away from Origin: farther is more "
              + "accurate.",
        button: "Place Direction", kind: "direction"
    }
}
