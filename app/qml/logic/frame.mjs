// The export frame: x from the Origin target toward the Direction target, y 90° to the left of x seen from above,
// headings in degrees counter-clockwise from +x, all in metres. The canvas has x right and y down the screen with
// headings clockwise on screen, so "left" there is the axis turned a quarter anticlockwise on screen.
// Tests: tests/qml/tst_frame.qml.

export function normalize(degrees) {
    let d = degrees % 360
    if (d > 180) d -= 360
    if (d <= -180) d += 360
    return d
}

// From the two targets (photo pixels) and the ruler's scale; null until both targets exist apart and a scale is set.
export function makeFrame(originPx, directionPx, metresPerPixel) {
    if (!originPx || !directionPx || !(metresPerPixel > 0))
        return null
    const ox = originPx.x * metresPerPixel
    const oy = originPx.y * metresPerPixel
    const dx = directionPx.x * metresPerPixel - ox
    const dy = directionPx.y * metresPerPixel - oy
    const distance = Math.hypot(dx, dy)
    if (!(distance > 0))
        return null
    return { ox: ox, oy: oy, ux: dx / distance, uy: dy / distance, theta: Math.atan2(dy, dx) * 180 / Math.PI,
             distance: distance }
}

// Canvas metres to the export frame.
export function toFrame(frame, p) {
    const dx = p.x - frame.ox
    const dy = p.y - frame.oy
    return { x: dx * frame.ux + dy * frame.uy, y: dx * frame.uy - dy * frame.ux }
}

// The export frame to canvas metres.
export function fromFrame(frame, q) {
    return { x: frame.ox + q.x * frame.ux + q.y * frame.uy, y: frame.oy + q.x * frame.uy - q.y * frame.ux }
}

// A canvas heading (clockwise on screen) as an export heading (counter-clockwise from +x).
export function headingToFrame(frame, heading) {
    return normalize(frame.theta - heading)
}

// An export heading (counter-clockwise from +x) as a canvas heading (clockwise on screen).
export function headingFromFrame(frame, heading) {
    return normalize(frame.theta - heading)
}
