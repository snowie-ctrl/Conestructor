// Track elements as data. Per type: the settings (defaults and physical limits), the centreline, the two ends and
// the cones, all in metres in the element's own frame: origin in the middle of its centreline's bounding box, x
// along its entry, y down the screen, headings in degrees clockwise on screen (Qt's convention). Ported from the
// prototype's qml/elements/*.qml at 2c79b60 with pixels replaced by metres; the frame is the prototype's, so the
// cone code is unchanged. Element objects: { id, type, x, y, rotation, props, joins: { A, B } } (see commands.mjs).
import * as Rows from "./conerows.mjs"
import { FOOT } from "./units.mjs"

export const TYPES = ["straight", "slalom", "chicane", "turn"]
export const NAMES = { straight: "Straight", slalom: "Slalom", chicane: "Chicane", turn: "Turn" }
export const COLOURS = { straight: "#b603fc", slalom: "#c9691a", chicane: "#1a46c9", turn: "#34eb7a" }
export const TIPS = {
    straight: "Straight: a run between two rows of cones.",
    slalom: "Slalom: a line of cones to weave through.",
    chicane: "Chicane: a sideways step in the track.",
    turn: "Turn: anything from a sweeper to a hairpin."
}

const WIDTH = { key: "trackWidth", label: "Track width", kind: "length", min: 1, max: 20 }
const LEAD_IN = { key: "leadIn", label: "Lead-in", kind: "length", min: 0, max: 100 }
const LEAD_OUT = { key: "leadOut", label: "Lead-out", kind: "length", min: 0, max: 100 }
const SIDES = { kind: "choice", choices: ["left", "right"], labels: ["Left", "Right"] }

// Physical limits only; the rulebook's limits are part 3's warnings and never block.
export const PROPS = {
    straight: [
        { key: "length", label: "Length", kind: "length", min: 1, max: 200 },
        WIDTH
    ],
    slalom: [
        LEAD_IN, LEAD_OUT,
        { key: "coneCount", label: "Cones", kind: "count", min: 1, max: 20 },
        { key: "coneSpacing", label: "Cone spacing", kind: "length", min: 2, max: 40 },
        { key: "weaveOffset", label: "Weave offset", kind: "length", min: 0, max: 10 },
        Object.assign({ key: "firstTurn", label: "First turn" }, SIDES),
        WIDTH
    ],
    chicane: [
        LEAD_IN, LEAD_OUT,
        { key: "shiftLength", label: "Shift length", kind: "length", min: 1, max: 100 },
        { key: "shift", label: "Sideways shift", kind: "length", min: 0, max: 40 },
        Object.assign({ key: "direction", label: "Direction" }, SIDES),
        WIDTH
    ],
    turn: [
        LEAD_IN, LEAD_OUT,
        { key: "angle", label: "Turn angle", kind: "angle", min: 0, max: 180 },
        { key: "radius", label: "Radius", kind: "length", min: 1, max: 100 },
        { key: "radiusType", label: "Radius type", kind: "choice", choices: ["constant", "changing"],
          labels: ["Constant", "Changing"] },
        { key: "exitRadius", label: "Exit radius", kind: "length", min: 1, max: 100,
          showWhen: { key: "radiusType", value: "changing" } },
        Object.assign({ key: "direction", label: "Direction" }, SIDES),
        WIDTH
    ]
}

const DEFAULTS = {
    straight: { length: 20, trackWidth: 4 },
    slalom: { leadIn: 6, leadOut: 6, coneCount: 4, coneSpacing: 10, weaveOffset: 1.5, firstTurn: "left", trackWidth: 4 },
    chicane: { leadIn: 6, leadOut: 6, shiftLength: 12, shift: 6, direction: "left", trackWidth: 4 },
    turn: { leadIn: 6, leadOut: 6, angle: 180, radius: 6, radiusType: "constant", exitRadius: 10, direction: "right",
            trackWidth: 4 }
}

export function defaults(type) {
    return Object.assign({}, DEFAULTS[type])
}

// The settings shown for these values (Exit radius only when the radius changes).
export function propList(type, props) {
    return PROPS[type].filter(p => !p.showWhen || props[p.showWhen.key] === p.showWhen.value)
}

// A value kept within a setting's limits: { value, clamped }. Counts are whole numbers.
export function clamp(def, value) {
    if (def.kind === "choice")
        return def.choices.indexOf(value) >= 0 ? { value: value, clamped: false } : { value: def.choices[0], clamped: true }
    let v = Number(value)
    if (!isFinite(v))
        return { value: def.min, clamped: true }
    if (def.kind === "count")
        v = Math.round(v)
    if (v < def.min)
        return { value: def.min, clamped: true }
    if (v > def.max)
        return { value: def.max, clamped: true }
    return { value: v, clamped: false }
}

export function clampProp(type, key, value) {
    const def = PROPS[type].find(p => p.key === key)
    if (!def)
        throw new Error("No setting " + key + " on " + type)
    return clamp(def, value)
}

// The prototype's Element.normalizeAngle: into [-180, 180].
export function normalizeAngle(angle) {
    while (angle > 180) angle -= 360
    while (angle < -180) angle += 360
    return angle
}

// ---- Geometry per type, in the element's own frame ----

const LEAD_MIN_FT = 8 * 3.28084       // the prototype's lead spacing (8 m to 10 m), written in feet
const LEAD_MAX_FT = 10 * 3.28084
const LEAN_OFFSET_FT = (10.5 / 2 + 18 / 2) / 12   // half a standing cone's base plus half a leaning cone
const SLALOM_SAMPLES = 16
const CURVE_SAMPLES = 60
const TURN_SAMPLES_PER_DEGREE = 3

function straight(p) {
    const half = p.length / 2
    return {
        path: [{ x: -half, y: 0 }, { x: half, y: 0 }],
        ends: { A: { x: -half, y: 0, heading: 180 }, B: { x: half, y: 0, heading: 0 } },
        cones: Rows.straightRow(-half, 0, 0, p.length, p.trackWidth / 2, FOOT, LEAD_MIN_FT, LEAD_MAX_FT)
    }
}

function slalom(p) {
    const total = p.leadIn + (p.coneCount + 1) * p.coneSpacing + p.leadOut
    const half = total / 2
    const weaveEnd = -half + p.leadIn + (p.coneCount + 1) * p.coneSpacing

    // The centreline swings out past each cone (weave offset plus half the track width), eased in and out.
    const keypoints = [{ x: -half, y: 0 }, { x: -half + p.leadIn, y: 0 }]
    let sign = p.firstTurn === "left" ? -1 : 1
    for (let i = 0; i < p.coneCount; i++) {
        keypoints.push({ x: -half + p.leadIn + (i + 1) * p.coneSpacing, y: sign * (p.weaveOffset + p.trackWidth / 2) })
        sign = -sign
    }
    keypoints.push({ x: weaveEnd, y: 0 }, { x: half, y: 0 })
    const path = []
    for (let k = 1; k < keypoints.length; k++) {
        const a = keypoints[k - 1]
        const b = keypoints[k]
        for (let s = k === 1 ? 0 : 1; s <= SLALOM_SAMPLES; s++) {
            const t = s / SLALOM_SAMPLES
            const ease = (1 - Math.cos(Math.PI * t)) / 2
            path.push({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * ease })
        }
    }

    // Cones: lead-in pairs, a standing cone at each apex with a pointer cone just inside it, lead-out pairs.
    const halfWidth = p.trackWidth / 2
    const lean = LEAN_OFFSET_FT * FOOT
    let cones = Rows.straightRow(-half, 0, 0, p.leadIn, halfWidth, FOOT, LEAD_MIN_FT, LEAD_MAX_FT)
    sign = p.firstTurn === "left" ? -1 : 1
    for (let i = 0; i < p.coneCount; i++) {
        const apexX = p.leadIn + (i + 1) * p.coneSpacing - half
        const apexY = sign * p.weaveOffset
        cones.push({ x: apexX, y: apexY, heading: 0, type: "standing" })
        // The pointer lies on the centreline side of the apex cone, pointing at it (the owner's correction after the
        // part 1 check; the prototype put it on the outside).
        cones.push({ x: apexX, y: apexY - sign * lean, heading: Math.atan2(sign, 0) * 180 / Math.PI, type: "leaning" })
        sign = -sign
    }
    cones = cones.concat(Rows.straightRow(weaveEnd, 0, 0, p.leadOut, halfWidth, FOOT, LEAD_MIN_FT, LEAD_MAX_FT))

    return { path: path, ends: { A: { x: -half, y: 0, heading: 180 }, B: { x: half, y: 0, heading: 0 } }, cones: cones }
}

function chicane(p) {
    const total = p.leadIn + p.shiftLength + p.leadOut
    const half = total / 2
    const bendRight = p.direction !== "left"
    const entryY = bendRight ? -p.shift / 2 : p.shift / 2
    const exitY = -entryY
    const p0 = { x: -half + p.leadIn, y: entryY }
    const c1 = { x: -half + p.leadIn + p.shiftLength / 2, y: entryY }
    const c2 = { x: -half + p.leadIn + p.shiftLength / 2, y: exitY }
    const p3 = { x: -half + p.leadIn + p.shiftLength, y: exitY }

    function point(t) {
        const mt = 1 - t
        return {
            x: mt * mt * mt * p0.x + 3 * mt * mt * t * c1.x + 3 * mt * t * t * c2.x + t * t * t * p3.x,
            y: mt * mt * mt * p0.y + 3 * mt * mt * t * c1.y + 3 * mt * t * t * c2.y + t * t * t * p3.y
        }
    }
    function tangentDeg(t) {
        const mt = 1 - t
        const dx = 3 * mt * mt * (c1.x - p0.x) + 6 * mt * t * (c2.x - c1.x) + 3 * t * t * (p3.x - c2.x)
        const dy = 3 * mt * mt * (c1.y - p0.y) + 6 * mt * t * (c2.y - c1.y) + 3 * t * t * (p3.y - c2.y)
        return Math.atan2(dy, dx) * 180 / Math.PI
    }

    const curve = []
    for (let i = 0; i <= CURVE_SAMPLES; i++) {
        const t = i / CURVE_SAMPLES
        const q = point(t)
        curve.push({ x: q.x, y: q.y, heading: tangentDeg(t) })
    }
    const path = [{ x: -half, y: entryY }].concat(curve.map(q => ({ x: q.x, y: q.y })), [{ x: half, y: exitY }])

    // Cones: entry pairs, leaning cones on the outside of each half of the S, exit pairs.
    const halfWidth = p.trackWidth / 2
    let cones = Rows.straightRow(-half, entryY, 0, p.leadIn, halfWidth, FOOT, LEAD_MIN_FT, LEAD_MAX_FT)
    const bendSign = bendRight ? -1 : 1
    for (const q of Rows.sampleInterior(curve, 3, 6, FOOT)) {
        const side = q.arcFraction < 0.5 ? bendSign : -bendSign
        const outside = q.heading * Math.PI / 180 + (90 * side) * Math.PI / 180
        cones.push({ x: q.x + Math.cos(outside) * halfWidth, y: q.y + Math.sin(outside) * halfWidth,
                     heading: q.heading, type: "leaning" })
    }
    cones = cones.concat(Rows.straightRow(p3.x, exitY, 0, p.leadOut, halfWidth, FOOT, LEAD_MIN_FT, LEAD_MAX_FT))

    return { path: path, ends: { A: { x: -half, y: entryY, heading: 180 }, B: { x: half, y: exitY, heading: 0 } },
             cones: cones }
}

function radiusAt(p, thetaDeg) {
    if (p.radiusType === "constant" || p.angle === 0)
        return p.radius
    return p.radius + (p.exitRadius - p.radius) * (thetaDeg / p.angle)
}

function turn(p) {
    const turnSign = p.direction === "right" ? 1 : -1
    const steps = Math.max(6, Math.round(Math.abs(p.angle) * TURN_SAMPLES_PER_DEGREE))
    const dTheta = p.angle / steps

    // The arc from the end of the lead-in, in the entry frame (start at 0, 0 heading +x), stepped as the prototype did.
    const arc = [{ x: p.leadIn, y: 0, heading: 0 }]
    let x = p.leadIn
    let y = 0
    let heading = 0
    for (let i = 0; i < steps; i++) {
        const ds = radiusAt(p, (i + 0.5) * dTheta) * (dTheta * Math.PI / 180)
        const h = heading * Math.PI / 180
        x += ds * Math.cos(h)
        y += ds * Math.sin(h)
        heading += turnSign * dTheta
        arc.push({ x: x, y: y, heading: heading })
    }
    const exitRad = heading * Math.PI / 180
    const raw = [{ x: 0, y: 0 }].concat(arc.map(q => ({ x: q.x, y: q.y })),
                                        [{ x: x + p.leadOut * Math.cos(exitRad), y: y + p.leadOut * Math.sin(exitRad) }])

    // Centre on the bounding box of the centreline (the prototype's padded box has the same centre).
    let minX = raw[0].x, maxX = raw[0].x, minY = raw[0].y, maxY = raw[0].y
    for (const q of raw) {
        minX = Math.min(minX, q.x); maxX = Math.max(maxX, q.x)
        minY = Math.min(minY, q.y); maxY = Math.max(maxY, q.y)
    }
    const cx = (minX + maxX) / 2
    const cy = (minY + maxY) / 2
    const path = raw.map(q => ({ x: q.x - cx, y: q.y - cy }))
    const rel = arc.map(q => ({ x: q.x - cx, y: q.y - cy, heading: q.heading }))

    // Cones: entry pairs, leaning cones on the inside of the arc, exit pairs.
    const halfWidth = p.trackWidth / 2
    let cones = Rows.straightRow(path[0].x, path[0].y, 0, p.leadIn, halfWidth, FOOT, LEAD_MIN_FT, LEAD_MAX_FT)
    for (const q of Rows.sampleInterior(rel, 5, 8, FOOT)) {
        const inside = q.heading * Math.PI / 180 - (-90 * turnSign) * Math.PI / 180
        cones.push({ x: q.x + Math.cos(inside) * halfWidth, y: q.y + Math.sin(inside) * halfWidth,
                     heading: q.heading, type: "leaning" })
    }
    const last = rel[rel.length - 1]
    cones = cones.concat(Rows.straightRow(last.x, last.y, exitRad, p.leadOut, halfWidth, FOOT, LEAD_MIN_FT, LEAD_MAX_FT))

    return {
        path: path,
        ends: { A: { x: path[0].x, y: path[0].y, heading: 180 },
                B: { x: path[path.length - 1].x, y: path[path.length - 1].y, heading: normalizeAngle(turnSign * p.angle) } },
        cones: cones
    }
}

const BUILD = { straight: straight, slalom: slalom, chicane: chicane, turn: turn }
const cache = new Map()

// The element's centreline, ends and cones in its own frame. Cached by settings; callers must not change the result.
export function geometry(type, props) {
    const key = type + JSON.stringify(props)
    let g = cache.get(key)
    if (!g) {
        g = BUILD[type](props)
        if (cache.size > 500)
            cache.clear()
        cache.set(key, g)
    }
    return g
}

// ---- In the world (canvas metres) ----

export function toWorld(el, p) {
    const r = el.rotation * Math.PI / 180
    const c = Math.cos(r)
    const s = Math.sin(r)
    return { x: el.x + (p.x * c - p.y * s), y: el.y + (p.x * s + p.y * c) }
}

export function endsWorld(el) {
    const ends = geometry(el.type, el.props).ends
    const out = {}
    for (const end of ["A", "B"]) {
        const w = toWorld(el, ends[end])
        out[end] = { x: w.x, y: w.y, heading: el.rotation + ends[end].heading }
    }
    return out
}

export function pathWorld(el) {
    return geometry(el.type, el.props).path.map(p => toWorld(el, p))
}

export function conesWorld(el) {
    return geometry(el.type, el.props).cones.map(c => {
        const w = toWorld(el, c)
        return { x: w.x, y: w.y, heading: el.rotation + c.heading, type: c.type }
    })
}

export function pointSegmentDistance(p, a, b) {
    const dx = b.x - a.x
    const dy = b.y - a.y
    const lengthSquared = dx * dx + dy * dy
    const t = lengthSquared > 0 ? Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared)) : 0
    return Math.hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
}

export function distanceToPath(el, p) {
    const path = pathWorld(el)
    let best = Infinity
    for (let i = 1; i < path.length; i++)
        best = Math.min(best, pointSegmentDistance(p, path[i - 1], path[i]))
    return best
}

// The id of the topmost element (last drawn) whose band covers p, within `tolerance` metres; "" when none.
export function hitTest(elements, p, tolerance) {
    for (let i = elements.length - 1; i >= 0; i--) {
        const el = elements[i]
        if (distanceToPath(el, p) <= el.props.trackWidth / 2 + tolerance)
            return el.id
    }
    return ""
}

// Where the rotate handle sits: above the band (up the element's own y), `extraMetres` clear of it.
export function rotateHandle(el, extraMetres) {
    const g = geometry(el.type, el.props)
    let reach = 0
    for (const p of g.path)
        reach = Math.max(reach, Math.abs(p.y))
    return toWorld(el, { x: 0, y: -(reach + el.props.trackWidth / 2 + extraMetres) })
}

// The band (as wide as the track) around a centreline, as one closed outline: one side forward, the other back.
// Drawn as a fill, so a translucent band never darkens where a thick stroke's segments would overlap on a curve.
export function bandPolygon(path, halfWidth) {
    if (path.length < 2)
        return []
    const left = []
    const right = []
    for (let i = 0; i < path.length; i++) {
        const a = path[Math.max(0, i - 1)]
        const b = path[Math.min(path.length - 1, i + 1)]
        const length = Math.hypot(b.x - a.x, b.y - a.y) || 1
        const nx = -(b.y - a.y) / length
        const ny = (b.x - a.x) / length
        left.push({ x: path[i].x + nx * halfWidth, y: path[i].y + ny * halfWidth })
        right.push({ x: path[i].x - nx * halfWidth, y: path[i].y - ny * halfWidth })
    }
    return left.concat(right.reverse())
}
