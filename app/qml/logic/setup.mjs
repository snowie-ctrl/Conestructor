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
