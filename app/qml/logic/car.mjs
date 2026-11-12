// The true-size car outline (Tools › Car outline): a rectangle `length` long and `width` wide in canvas metres, centred
// on car.x, car.y, its front along car.rotation (degrees clockwise on screen, like elements). It is never part of the
// track. Tests: tests/qml/tst_car.qml.

function local(car, p) {
    const r = -car.rotation * Math.PI / 180
    const dx = p.x - car.x
    const dy = p.y - car.y
    return { x: dx * Math.cos(r) - dy * Math.sin(r), y: dx * Math.sin(r) + dy * Math.cos(r) }
}

function world(car, q) {
    const r = car.rotation * Math.PI / 180
    return { x: car.x + q.x * Math.cos(r) - q.y * Math.sin(r), y: car.y + q.x * Math.sin(r) + q.y * Math.cos(r) }
}

// Whether p (canvas metres) is on the car.
export function contains(car, length, width, p) {
    const q = local(car, p)
    return Math.abs(q.x) <= length / 2 && Math.abs(q.y) <= width / 2
}

// The four corners, front left first, going round.
export function corners(car, length, width) {
    return [{ x: length / 2, y: -width / 2 }, { x: length / 2, y: width / 2 }, { x: -length / 2, y: width / 2 },
            { x: -length / 2, y: -width / 2 }].map(q => world(car, q))
}

// The rotate handle, `extra` metres past the nose.
export function handle(car, length, extra) {
    return world(car, { x: length / 2 + extra, y: 0 })
}

// The rotation that points the car's front at p; in `step`-degree steps when step > 0 (Shift).
export function facing(car, p, step) {
    let r = Math.atan2(p.y - car.y, p.x - car.x) * 180 / Math.PI
    if (step > 0)
        r = Math.round(r / step) * step
    return r
}
