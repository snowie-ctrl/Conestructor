// The prototype's cone code at commit 2c79b60, kept as the port check's reference. Transcribed from
// Conestructor/qml/elements/ConeUtils.js, Straight.qml, Slalom.qml, Chicane.qml, Hairpin.qml and PostProcessor.qml:
// QML property reads became reads from a plain element object `el` (prototype property names), Qt.point became
// {x, y}, the duplicated ConeUtils functions appear once, and nothing else changed. Pixels and feet, y down the
// screen, headings clockwise. Do not fix anything here: this is what the new code is compared against. The
// exceptions are marked OWNER'S CORRECTION (the slalom pointer cones) and PART 2 CHANGE (turn steps follow the
// heading at their middle).

// ---- ConeUtils.js ----

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

// ---- Straight.qml getConePlacements ----

function straightCones(el, pixelsPerFoot) {
    var minSpacingFt = 8 * 3.28084
    var maxSpacingFt = 10 * 3.28084

    return straightConeSegment(
        -el.length / 2, 0, 0, el.length,
        el.trackWidth / 2, pixelsPerFoot, minSpacingFt, maxSpacingFt
    )
}

// ---- Slalom.qml getConePlacements (width is Slalom.qml's totalLength) ----

function slalomCones(el, pixelsPerFoot) {
    var width = el.leadInLength + (el.numSlaloms + 1) * el.slalomOffset + el.leadOutLength
    var leadMinSpacingFt = 8 * 3.28084
    var leadMaxSpacingFt = 10 * 3.28084

    var leaningOffsetFt = (10.5 / 2 + 18 / 2) / 12
    var leaningOffsetPx = leaningOffsetFt * pixelsPerFoot
    var halfWidth = el.trackWidth / 2

    var cones = []

    cones = cones.concat(straightConeSegment(
        -width / 2, 0, 0, el.leadInLength,
        halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
    ))

    var sign = (el.initialDirection === "left") ? -1 : 1
    for (var i = 0; i < el.numSlaloms; i++) {
        var apexX = el.leadInLength + (i + 1) * el.slalomOffset - width / 2
        var apexY = sign * el.apexOffset
        // OWNER'S CORRECTION, the one deliberate change from the prototype (after the part 1 check, 2026-11-10): the
        // pointer lies on the centreline side of the apex cone, still pointing at it. The prototype had
        // `apexY + sign * leaningOffsetPx` here and `Math.atan2(-sign, 0)` below.
        var leanY = apexY - sign * leaningOffsetPx

        cones.push({ x: apexX, y: apexY, heading: 0, coneType: "standing" })

        var headingDeg = Math.atan2(sign, 0) * 180 / Math.PI
        cones.push({ x: apexX, y: leanY, heading: headingDeg, coneType: "leaning" })

        sign = -sign
    }

    var slalomEndLocalX = el.leadInLength + (el.numSlaloms + 1) * el.slalomOffset - width / 2
    cones = cones.concat(straightConeSegment(
        slalomEndLocalX, 0, 0, el.leadOutLength,
        halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
    ))

    return cones
}

// ---- Chicane.qml getConePlacements (width, height, bendRight, drawEntry, drawExit are Chicane.qml's bindings) ----

function chicaneCones(el, pixelsPerFoot) {
    var width = el.leadInLength + el.leadWidthOffset + el.leadOutLength
    var height = el.leadHeightOffset + el.trackWidth
    var bendRight = el.turnDirection !== "left"
    var drawEntry = { x: 0, y: bendRight ? el.trackWidth / 2 : (el.leadHeightOffset + el.trackWidth / 2) }
    var drawExit = { x: width, y: bendRight ? (el.leadHeightOffset + el.trackWidth / 2) : el.trackWidth / 2 }

    var leadMinSpacingFt = 8 * 3.28084
    var leadMaxSpacingFt = 10 * 3.28084
    var leaningMinSpacingFt = 3
    var leaningMaxSpacingFt = 6
    var halfWidth = el.trackWidth / 2

    var cones = []

    cones = cones.concat(straightConeSegment(
        0 - width / 2, drawEntry.y - height / 2, 0, el.leadInLength,
        halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
    ))

    var p0 = { x: el.leadInLength, y: drawEntry.y }
    var c1 = { x: el.leadInLength + el.leadWidthOffset / 2, y: drawEntry.y }
    var c2 = { x: el.leadInLength + el.leadWidthOffset / 2, y: drawExit.y }
    var p3 = { x: el.leadInLength + el.leadWidthOffset, y: drawExit.y }

    function bezierPoint(t) {
        var mt = 1 - t
        return {
            x: mt*mt*mt*p0.x + 3*mt*mt*t*c1.x + 3*mt*t*t*c2.x + t*t*t*p3.x,
            y: mt*mt*mt*p0.y + 3*mt*mt*t*c1.y + 3*mt*t*t*c2.y + t*t*t*p3.y
        }
    }

    function bezierTangentDeg(t) {
        var mt = 1 - t
        var dx = 3*mt*mt*(c1.x-p0.x) + 6*mt*t*(c2.x-c1.x) + 3*t*t*(p3.x-c2.x)
        var dy = 3*mt*mt*(c1.y-p0.y) + 6*mt*t*(c2.y-c1.y) + 3*t*t*(p3.y-c2.y)
        return Math.atan2(dy, dx) * 180 / Math.PI
    }

    var sampleCount = 60
    var curvePoints = []
    for (var i = 0; i <= sampleCount; i++) {
        var t = i / sampleCount
        var pt = bezierPoint(t)
        curvePoints.push({
            x: pt.x - width / 2,
            y: pt.y - height / 2,
            heading: bezierTangentDeg(t)
        })
    }

    var interior = sampleInteriorByArcLength(curvePoints, leaningMinSpacingFt, leaningMaxSpacingFt, pixelsPerFoot)
    var bendSign = bendRight ? -1 : 1

    for (var j = 0; j < interior.length; j++) {
        var p = interior[j]
        var side = (p.arcFraction < 0.5) ? bendSign : -bendSign

        var headingRad = p.heading * Math.PI / 180
        var outsideAngleRad = headingRad + (90 * side) * Math.PI / 180

        var coneX = p.x + Math.cos(outsideAngleRad) * halfWidth
        var coneY = p.y + Math.sin(outsideAngleRad) * halfWidth
        var coneHeadingDeg = p.heading

        cones.push({ x: coneX, y: coneY, heading: coneHeadingDeg, coneType: "leaning" })
    }

    cones = cones.concat(straightConeSegment(
        el.leadInLength + el.leadWidthOffset - width / 2, drawExit.y - height / 2, 0, el.leadOutLength,
        halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
    ))

    return cones
}

// ---- Hairpin.qml rebuildPath (the parts getConePlacements reads), radiusAtTheta and getConePlacements ----

function radiusAtTheta(el, thetaDeg) {
    if (el.radiusType === "constant" || el.degreesOfTurn === 0) return el.primaryRadius
    var t = thetaDeg / el.degreesOfTurn
    return el.primaryRadius + (el.secondaryRadius - el.primaryRadius) * t
}

function hairpinShape(el) {
    var samplesPerDegree = 3
    var pts = []
    var x = 0
    var y = 0
    var heading = 0

    pts.push({ x: x, y: y })

    x += el.leadInLength
    pts.push({ x: x, y: y })

    var turnSign = el.turnDirection === "right" ? 1 : -1
    var steps = Math.max(6, Math.round(Math.abs(el.degreesOfTurn) * samplesPerDegree))
    var dThetaDeg = el.degreesOfTurn / steps

    for (var i = 0; i < steps; i++) {
        var thetaMid = (i + 0.5) * dThetaDeg
        var r = radiusAtTheta(el, thetaMid)
        var dThetaRad = dThetaDeg * Math.PI / 180
        var ds = r * dThetaRad
        // PART 2 CHANGE (2026-11-10): each step follows the heading at its middle, so turns are true arcs and a
        // reversed turn retraces its footprint. The prototype had `heading * Math.PI / 180` here.
        var headingRad = (heading + turnSign * dThetaDeg / 2) * Math.PI / 180

        x += ds * Math.cos(headingRad)
        y += ds * Math.sin(headingRad)
        heading += turnSign * dThetaDeg

        pts.push({ x: x, y: y })
    }

    var headingRad2 = heading * Math.PI / 180
    x += el.leadOutLength * Math.cos(headingRad2)
    y += el.leadOutLength * Math.sin(headingRad2)
    pts.push({ x: x, y: y })

    var minX = pts[0].x, maxX = pts[0].x
    var minY = pts[0].y, maxY = pts[0].y

    for (var p = 0; p < pts.length; p++) {
        minX = Math.min(minX, pts[p].x)
        maxX = Math.max(maxX, pts[p].x)
        minY = Math.min(minY, pts[p].y)
        maxY = Math.max(maxY, pts[p].y)
    }

    var pad = el.trackWidth / 2
    minX -= pad; maxX += pad
    minY -= pad; maxY += pad

    var width = maxX - minX
    var height = maxY - minY

    var normalized = []
    for (var q = 0; q < pts.length; q++) {
        normalized.push({ x: pts[q].x - minX, y: pts[q].y - minY })
    }

    var entryPoint = normalized[0]
    var exitPoint = normalized[normalized.length - 1]

    return {
        width: width,
        height: height,
        pathStartPoint: normalized[0],
        gateA: { x: entryPoint.x - width / 2, y: entryPoint.y - height / 2 },
        gateB: { x: exitPoint.x - width / 2, y: exitPoint.y - height / 2 }
    }
}

function hairpinCones(el, pixelsPerFoot) {
    if (el.degreesOfTurn > 180) return []
    var shape = hairpinShape(el)
    var samplesPerDegree = 3

    var leadMinSpacingFt = 8 * 3.28084
    var leadMaxSpacingFt = 10 * 3.28084
    var turnMinSpacingFt = 5
    var turnMaxSpacingFt = 8
    var halfWidth = el.trackWidth / 2

    var cones = []

    cones = cones.concat(straightConeSegment(
        shape.gateA.x, shape.gateA.y, 0, el.leadInLength,
        halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
    ))

    var turnPoints = []
    var x = el.leadInLength
    var y = 0
    var heading = 0
    turnPoints.push({ x: x, y: y, heading: heading })

    var turnSign = el.turnDirection === "right" ? 1 : -1
    var steps = Math.max(6, Math.round(Math.abs(el.degreesOfTurn) * samplesPerDegree))
    var dThetaDeg = el.degreesOfTurn / steps

    for (var i = 0; i < steps; i++) {
        var thetaMid = (i + 0.5) * dThetaDeg
        var r = radiusAtTheta(el, thetaMid)
        var dThetaRad = dThetaDeg * Math.PI / 180
        var ds = r * dThetaRad
        // PART 2 CHANGE (2026-11-10): each step follows the heading at its middle, so turns are true arcs and a
        // reversed turn retraces its footprint. The prototype had `heading * Math.PI / 180` here.
        var headingRad = (heading + turnSign * dThetaDeg / 2) * Math.PI / 180

        x += ds * Math.cos(headingRad)
        y += ds * Math.sin(headingRad)
        heading += turnSign * dThetaDeg

        turnPoints.push({ x: x, y: y, heading: heading })
    }

    var relPoints = turnPoints.map(function(p) {
        return {
            x: p.x + shape.pathStartPoint.x - shape.width / 2,
            y: p.y + shape.pathStartPoint.y - shape.height / 2,
            heading: p.heading
        }
    })

    var interior = sampleInteriorByArcLength(relPoints, turnMinSpacingFt, turnMaxSpacingFt, pixelsPerFoot)

    for (var j = 0; j < interior.length; j++) {
        var pt = interior[j]
        var headingRad2 = pt.heading * Math.PI / 180
        var insideAngleRad = headingRad2 - (-90 * turnSign) * Math.PI / 180

        var coneX = pt.x + Math.cos(insideAngleRad) * halfWidth
        var coneY = pt.y + Math.sin(insideAngleRad) * halfWidth
        var coneHeadingDeg = pt.heading

        cones.push({ x: coneX, y: coneY, heading: coneHeadingDeg, coneType: "leaning" })
    }

    var lastRel = relPoints[relPoints.length - 1]
    var lastRaw = turnPoints[turnPoints.length - 1]
    var exitHeadingRad = lastRaw.heading * Math.PI / 180

    cones = cones.concat(straightConeSegment(
        lastRel.x, lastRel.y, exitHeadingRad, el.leadOutLength,
        halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
    ))

    return cones
}

function getConePlacements(el, pixelsPerFoot) {
    switch (el.shapeName) {
    case "Straight": return straightCones(el, pixelsPerFoot)
    case "Slalom": return slalomCones(el, pixelsPerFoot)
    case "Chicane": return chicaneCones(el, pixelsPerFoot)
    case "Hairpin": return hairpinCones(el, pixelsPerFoot)
    }
    return []
}

// ---- PostProcessor.qml run(), from "Step 1" on; targets are { xPos, yPos } in pixels ----

export function run(trackElements, pixelsPerFoot, targetA, targetB) {
    var originX = targetA.xPos
    var originY = targetA.yPos
    var axisDx = targetB.xPos - originX
    var axisDy = targetB.yPos - originY
    var frameRotationRad = Math.atan2(axisDy, axisDx)

    var elementConeGroups = []
    for (var i = 0; i < trackElements.length; i++) {
        var element = trackElements[i]
        var localCones = getConePlacements(element, pixelsPerFoot)
        var globalCones = []

        var elementRotRad = element.elementRotation * Math.PI / 180
        var cosE = Math.cos(elementRotRad)
        var sinE = Math.sin(elementRotRad)

        for (var j = 0; j < localCones.length; j++) {
            var local = localCones[j]
            globalCones.push({
                x: element.xPos + (local.x * cosE - local.y * sinE),
                y: element.yPos + (local.x * sinE + local.y * cosE),
                heading: element.elementRotation + local.heading,
                coneType: local.coneType
            })
        }

        elementConeGroups.push({ element: element, cones: globalCones })
    }

    var epsilonFt = .4
    dedupeElementCones(elementConeGroups, epsilonFt * pixelsPerFoot)

    var chains = buildChains(trackElements, elementConeGroups)
    var orderedGlobalCones = stitchChains(chains)

    var cones = []
    for (var k = 0; k < orderedGlobalCones.length; k++) {
        var gc = orderedGlobalCones[k]
        var dx = gc.x - originX
        var dy = gc.y - originY

        var cosF = Math.cos(-frameRotationRad)
        var sinF = Math.sin(-frameRotationRad)

        var frameX = (dx * cosF - dy * sinF) / pixelsPerFoot
        var frameY = (dx * sinF + dy * cosF) / pixelsPerFoot
        var frameHeadingDeg = gc.heading - (frameRotationRad * 180 / Math.PI)

        cones.push({ index: k, coneType: gc.coneType, x: frameX, y: frameY, heading: frameHeadingDeg })
    }
    return cones
}
