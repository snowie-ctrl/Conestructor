// The port check's sample track: every element type, joins (one entered backwards at its exit), a changing-radius
// turn, a left turn and two free elements to stitch, on an angled Origin -> Direction axis. Built with the new
// commands, then converted to the prototype's pixel elements for tests/qml/fixtures/prototype.mjs.
import * as Commands from "../../../qml/logic/commands.mjs"
import { FOOT } from "../../../qml/logic/units.mjs"

export function track() {
    const steps = [
        ["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 }],      // 0.1 m per pixel
        ["setTarget", { which: "origin", point: { x: 200, y: 600 } }],
        ["setTarget", { which: "direction", point: { x: 900, y: 300 } }],
        ["add", { type: "straight", x: 30, y: 40 }],                                                        // e1
        ["add", { type: "slalom", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } }],                 // e2
        ["add", { type: "turn", x: 0, y: 0, props: { radiusType: "changing", exitRadius: 10 },
                  snap: { ownEnd: "A", id: "e2", end: "B" } }],                                              // e3
        ["add", { type: "chicane", x: 0, y: 0, snap: { ownEnd: "B", id: "e3", end: "B" } }],                // e4, backwards
        ["add", { type: "straight", x: 20, y: 70, rotation: 30, props: { length: 15 } }],                   // e5, alone
        ["add", { type: "turn", x: 90, y: 15, rotation: -20, props: { direction: "left", angle: 90, radius: 9 } }]  // e6
    ]
    const stack = new Commands.UndoStack()
    let t = Commands.emptyTrack()
    for (const [name, args] of steps)
        t = Commands.run(stack, t, name, args)
    return t
}

const SHAPE_NAMES = { straight: "Straight", slalom: "Slalom", chicane: "Chicane", turn: "Hairpin" }

// The same elements as the prototype held them: pixels, its property names, mates as { element, gate }.
export function prototypeElements(track) {
    const k = 1 / track.photo.metresPerPixel
    const list = track.elements.map(el => {
        const p = el.props
        const base = { shapeName: SHAPE_NAMES[el.type], xPos: el.x * k, yPos: el.y * k, elementRotation: el.rotation,
                       gateAMate: null, gateBMate: null }
        switch (el.type) {
        case "straight":
            return Object.assign(base, { length: p.length * k, trackWidth: p.trackWidth * k })
        case "slalom":
            return Object.assign(base, { leadInLength: p.leadIn * k, leadOutLength: p.leadOut * k,
                                         numSlaloms: p.coneCount, initialDirection: p.firstTurn,
                                         apexOffset: p.weaveOffset * k, slalomOffset: p.coneSpacing * k,
                                         trackWidth: p.trackWidth * k })
        case "chicane":
            return Object.assign(base, { leadInLength: p.leadIn * k, leadOutLength: p.leadOut * k,
                                         leadWidthOffset: p.shiftLength * k, leadHeightOffset: p.shift * k,
                                         trackWidth: p.trackWidth * k, turnDirection: p.direction })
        case "turn":
            return Object.assign(base, { radiusType: p.radiusType, leadInLength: p.leadIn * k,
                                         leadOutLength: p.leadOut * k, primaryRadius: p.radius * k,
                                         secondaryRadius: p.exitRadius * k, degreesOfTurn: p.angle,
                                         turnDirection: p.direction, trackWidth: p.trackWidth * k })
        }
        return base
    })
    track.elements.forEach((el, i) => {
        for (const end of ["A", "B"]) {
            const mate = el.joins[end]
            if (mate)
                list[i]["gate" + end + "Mate"] = { element: list[track.elements.findIndex(e => e.id === mate.id)],
                                                   gate: mate.end }
        }
    })
    return list
}

export function pixelsPerFoot(track) {
    return FOOT / track.photo.metresPerPixel
}

export function prototypeTarget(point) {
    return { xPos: point.x, yPos: point.y }
}
