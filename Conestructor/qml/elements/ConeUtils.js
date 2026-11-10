.pragma library

// Standing cone pairs along a straight run, inclusive of both endpoints.
// Correctly handles lengthPx === 0 by still emitting exactly one pair at
// the origin (needed for "always place standing cones even with 0-length lead").
function straightConeSegment(originX, originY, angleRad, lengthPx, halfWidthPx, pixelsPerFoot, minSpacingFt, maxSpacingFt) {
    var maxSpacingPx = maxSpacingFt * pixelsPerFoot
    var n = lengthPx > 0 ? Math.max(1, Math.ceil(lengthPx / maxSpacingPx)) : 0
    var spacingPx = n > 0 ? lengthPx / n : 0

    var dirX = Math.cos(angleRad)
    var dirY = Math.sin(angleRad)
    var nx = -Math.sin(angleRad)
    var ny = Math.cos(angleRad)

    var cones = []
    for (var i = 0; i <= n; i++) {
        var d = spacingPx * i
        var px = originX + dirX * d
        var py = originY + dirY * d
        cones.push({ x: px + nx * halfWidthPx, y: py + ny * halfWidthPx, heading: 0, coneType: "standing" })
        cones.push({ x: px - nx * halfWidthPx, y: py - ny * halfWidthPx, heading: 0, coneType: "standing" })
    }
    return cones
}

function computeArcLengths(points) {
    var arcLen = [0]
    for (var i = 1; i < points.length; i++) {
        var dx = points[i].x - points[i - 1].x
        var dy = points[i].y - points[i - 1].y
        arcLen.push(arcLen[i - 1] + Math.sqrt(dx * dx + dy * dy))
    }
    return arcLen
}

function interpolateAtArcLength(points, arcLen, targetLen) {
    for (var i = 1; i < arcLen.length; i++) {
        if (arcLen[i] >= targetLen) {
            var segStart = arcLen[i - 1]
            var segEnd = arcLen[i]
            var t = (segEnd > segStart) ? (targetLen - segStart) / (segEnd - segStart) : 0
            var p0 = points[i - 1]
            var p1 = points[i]
            return {
                x: p0.x + (p1.x - p0.x) * t,
                y: p0.y + (p1.y - p0.y) * t,
                heading: p0.heading + (p1.heading - p0.heading) * t
            }
        }
    }
    return points[points.length - 1]
}

// Returns INTERIOR points only (excludes both endpoints) uniformly spaced
// by arc length, minimizing count while keeping spacing <= maxSpacingFt.
// Each point also carries arcFraction (0-1) for callers that need to know
// which half of a curve a point falls in (e.g. an S-curve side flip).
function sampleInteriorByArcLength(points, minSpacingFt, maxSpacingFt, pixelsPerFoot) {
    var arcLen = computeArcLengths(points)
    var totalLen = arcLen[arcLen.length - 1]
    var maxSpacingPx = maxSpacingFt * pixelsPerFoot

    var n = Math.max(1, Math.ceil(totalLen / maxSpacingPx))
    var result = []
    for (var i = 1; i < n; i++) {
        var targetLen = totalLen * i / n
        var pt = interpolateAtArcLength(points, arcLen, targetLen)
        pt.arcFraction = totalLen > 0 ? targetLen / totalLen : 0
        result.push(pt)
    }
    return result
}

function dedupeElementCones(elementConeGroups, epsilonPx) {
    var flat = []
    for (var g = 0; g < elementConeGroups.length; g++) {
        var cones = elementConeGroups[g].cones
        for (var c = 0; c < cones.length; c++) {
            flat.push({ groupIndex: g, coneIndex: c, cone: cones[c] })
        }
    }

    var removed = new Array(flat.length).fill(false)

    for (var i = 0; i < flat.length; i++) {
        if (removed[i]) continue
        for (var j = i + 1; j < flat.length; j++) {
            if (removed[j]) continue
            var dx = flat[i].cone.x - flat[j].cone.x
            var dy = flat[i].cone.y - flat[j].cone.y
            if (Math.sqrt(dx * dx + dy * dy) < epsilonPx) {
                removed[j] = true
            }
        }
    }

    for (var g2 = 0; g2 < elementConeGroups.length; g2++) {
        var keep = []
        for (var c2 = 0; c2 < flat.length; c2++) {
            if (flat[c2].groupIndex === g2 && !removed[c2]) {
                keep.push(flat[c2].cone)
            }
        }
        elementConeGroups[g2].cones = keep
    }
}

function distance(a, b) {
    var dx = a.x - b.x, dy = a.y - b.y
    return Math.sqrt(dx * dx + dy * dy)
}

function findGroupCones(element, elementConeGroups) {
    for (var i = 0; i < elementConeGroups.length; i++) {
        if (elementConeGroups[i].element === element) return elementConeGroups[i].cones
    }
    return []
}

function appendElementCones(element, enterGate, elementConeGroups, outList) {
    var cones = findGroupCones(element, elementConeGroups)
    if (enterGate === "B") {
        for (var i = cones.length - 1; i >= 0; i--) outList.push(cones[i])
    } else {
        for (var j = 0; j < cones.length; j++) outList.push(cones[j])
    }
}

function walkChain(startElement, startGate, visited, elementConeGroups) {
    var outList = []
    var current = startElement
    var enterGate = startGate

    while (current && visited.indexOf(current) === -1) {
        visited.push(current)
        appendElementCones(current, enterGate, elementConeGroups, outList)

        var exitGate = enterGate === "A" ? "B" : "A"
        var mate = exitGate === "A" ? current.gateAMate : current.gateBMate

        if (mate && visited.indexOf(mate.element) === -1) {
            current = mate.element
            enterGate = mate.gate
        } else {
            current = null
        }
    }
    return outList
}

function distance(a, b) {
    var dx = a.x - b.x, dy = a.y - b.y
    return Math.sqrt(dx * dx + dy * dy)
}

function distance(a, b) {
    var dx = a.x - b.x, dy = a.y - b.y
    return Math.sqrt(dx * dx + dy * dy)
}

function findGroupCones(element, elementConeGroups) {
    for (var i = 0; i < elementConeGroups.length; i++) {
        if (elementConeGroups[i].element === element) return elementConeGroups[i].cones
    }
    return []
}

function appendElementCones(element, enterGate, elementConeGroups, outList) {
    var cones = findGroupCones(element, elementConeGroups)
    if (enterGate === "B") {
        for (var i = cones.length - 1; i >= 0; i--) outList.push(cones[i])
    } else {
        for (var j = 0; j < cones.length; j++) outList.push(cones[j])
    }
}

function walkChain(startElement, startGate, visited, elementConeGroups) {
    var outList = []
    var current = startElement
    var enterGate = startGate

    while (current && visited.indexOf(current) === -1) {
        visited.push(current)
        appendElementCones(current, enterGate, elementConeGroups, outList)

        var exitGate = enterGate === "A" ? "B" : "A"
        var mate = exitGate === "A" ? current.gateAMate : current.gateBMate

        if (mate && visited.indexOf(mate.element) === -1) {
            current = mate.element
            enterGate = mate.gate
        } else {
            current = null
        }
    }
    return outList
}

function buildChains(trackElements, elementConeGroups) {
    var visited = []
    var chains = []

    for (var i = 0; i < trackElements.length; i++) {
        var element = trackElements[i]
        if (visited.indexOf(element) !== -1) continue

        var hasA = element.gateAMate !== null
        var hasB = element.gateBMate !== null
        if (hasA && hasB) continue

        var startGate = hasA ? "B" : "A"
        var chainCones = walkChain(element, startGate, visited, elementConeGroups)
        if (chainCones.length > 0) chains.push(chainCones)
    }

    for (var k = 0; k < trackElements.length; k++) {
        var el2 = trackElements[k]
        if (visited.indexOf(el2) !== -1) continue
        var loopCones = walkChain(el2, "A", visited, elementConeGroups)
        if (loopCones.length > 0) chains.push(loopCones)
    }

    return chains
}

function stitchChains(chains) {
    if (chains.length === 0) return []

    var remaining = chains.slice()
    var first = remaining.shift()
    var ordered = first.slice()
    var currentEnd = ordered[ordered.length - 1]

    while (remaining.length > 0) {
        var bestIdx = -1
        var bestReversed = false
        var bestDist = Infinity

        for (var i = 0; i < remaining.length; i++) {
            var chain = remaining[i]
            var dStart = distance(currentEnd, chain[0])
            var dEnd = distance(currentEnd, chain[chain.length - 1])

            if (dStart < bestDist) { bestDist = dStart; bestIdx = i; bestReversed = false }
            if (dEnd < bestDist) { bestDist = dEnd; bestIdx = i; bestReversed = true }
        }

        var chosen = remaining[bestIdx]
        remaining.splice(bestIdx, 1)
        var toAppend = bestReversed ? chosen.slice().reverse() : chosen

        ordered = ordered.concat(toAppend)
        currentEnd = ordered[ordered.length - 1]
    }

    return ordered
}
