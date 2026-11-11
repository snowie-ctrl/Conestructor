// An example track on the blueprint (chosen, so setup counts it done) (1280 × 720 pixels; 128 m × 72 m at the ruler's 0.1 m per pixel), for
// screenshots (CONESTRUCTOR_DEMO) and the QML smoke test: every element type, joined end to end.
import * as Commands from "./commands.mjs"

export function demoTrack() {
    const steps = [
        ["setPhoto", { kind: "blueprint" }],
        ["setRuler", { a: { x: 140, y: 660 }, b: { x: 340, y: 660 }, realLength: 20 }],
        ["setTarget", { which: "origin", point: { x: 150, y: 560 } }],
        ["setTarget", { which: "direction", point: { x: 1150, y: 560 } }],
        ["add", { type: "straight", x: 30, y: 30 }],
        ["add", { type: "slalom", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } }],
        ["add", { type: "turn", x: 0, y: 0, snap: { ownEnd: "A", id: "e2", end: "B" } }],
        ["add", { type: "chicane", x: 0, y: 0, snap: { ownEnd: "A", id: "e3", end: "B" } }]
    ]
    const stack = new Commands.UndoStack()
    let track = Commands.emptyTrack()
    for (const [name, args] of steps)
        track = Commands.run(stack, track, name, args)
    return track
}
