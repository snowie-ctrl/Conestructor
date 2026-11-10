// Cone rows along a centreline, ported from the prototype's qml/elements/ConeUtils.js at 2c79b60. Lengths are in
// any unit; `unitsPerFoot` says how many of that unit make a foot (0.3048 for metres), because the prototype's
// spacing rules are written in feet. Part 3 replaces these spacing rules with density notches.

// Standing cone pairs along a straight run, both ends included. A run of length 0 still gets one pair.
export function straightRow(originX, originY, angleRad, length, halfWidth, unitsPerFoot, minSpacingFt, maxSpacingFt) {
    const maxSpacing = maxSpacingFt * unitsPerFoot
    const n = length > 0 ? Math.max(1, Math.ceil(length / maxSpacing)) : 0
    const spacing = n > 0 ? length / n : 0
    const dirX = Math.cos(angleRad)
    const dirY = Math.sin(angleRad)
    const nx = -Math.sin(angleRad)
    const ny = Math.cos(angleRad)
    const cones = []
    for (let i = 0; i <= n; i++) {
        const d = spacing * i
        const px = originX + dirX * d
        const py = originY + dirY * d
        cones.push({ x: px + nx * halfWidth, y: py + ny * halfWidth, heading: 0, type: "standing" })
        cones.push({ x: px - nx * halfWidth, y: py - ny * halfWidth, heading: 0, type: "standing" })
    }
    return cones
}

export function arcLengths(points) {
    const arcLen = [0]
    for (let i = 1; i < points.length; i++) {
        const dx = points[i].x - points[i - 1].x
        const dy = points[i].y - points[i - 1].y
        arcLen.push(arcLen[i - 1] + Math.sqrt(dx * dx + dy * dy))
    }
    return arcLen
}

export function atArcLength(points, arcLen, target) {
    for (let i = 1; i < arcLen.length; i++) {
        if (arcLen[i] >= target) {
            const segStart = arcLen[i - 1]
            const segEnd = arcLen[i]
            const t = segEnd > segStart ? (target - segStart) / (segEnd - segStart) : 0
            const p0 = points[i - 1]
            const p1 = points[i]
            return { x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t,
                     heading: p0.heading + (p1.heading - p0.heading) * t }
        }
    }
    return Object.assign({}, points[points.length - 1])
}

// Interior points only (both ends excluded), evenly spaced by arc length, as few as keep the spacing at or under
// maxSpacingFt. Each carries arcFraction (0 to 1), which an S-curve uses to flip sides halfway.
export function sampleInterior(points, minSpacingFt, maxSpacingFt, unitsPerFoot) {
    const arcLen = arcLengths(points)
    const total = arcLen[arcLen.length - 1]
    const maxSpacing = maxSpacingFt * unitsPerFoot
    const n = Math.max(1, Math.ceil(total / maxSpacing))
    const result = []
    for (let i = 1; i < n; i++) {
        const target = total * i / n
        const pt = atArcLength(points, arcLen, target)
        pt.arcFraction = total > 0 ? target / total : 0
        result.push(pt)
    }
    return result
}
