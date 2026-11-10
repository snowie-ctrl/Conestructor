pragma Singleton
import QtQuick
import Conestructor

QtObject {
    id: root

    function run() {
        var elements = AppState.canvasArea.elements
        var rulers = elements.filter(function(e) { return e.shapeName === "Ruler" })
        var targets = elements.filter(function(e) { return e.shapeName === "Target" })

        if (rulers.length !== 1) { console.error("PostProcessor: expected exactly 1 Ruler, found", rulers.length); return }
        if (targets.length !== 2) { console.error("PostProcessor: expected exactly 2 Target elements, found", targets.length); return }

        var ruler = rulers[0]
        var pixelsPerFoot = ruler.realWorldRatio
        if (pixelsPerFoot <= 0) { console.error("PostProcessor: Ruler has no valid realWorldLength set"); return }

        var targetA = targets.find(function(t) { return t.referenceIndex === 0 })
        var targetB = targets.find(function(t) { return t.referenceIndex === 1 })
        if (!targetA || !targetB) { console.error("PostProcessor: Targets must have referenceIndex 0 and 1 set"); return }

        var originX = targetA.xPos
        var originY = targetA.yPos
        var axisDx = targetB.xPos - originX
        var axisDy = targetB.yPos - originY
        var frameRotationRad = Math.atan2(axisDy, axisDx)

        var trackElements = elements.filter(function(e) {
            return e !== ruler && e !== targetA && e !== targetB
        })

        // Step 1: build cones per-element, in GLOBAL pixel space, keeping grouping
        var elementConeGroups = []
        for (var i = 0; i < trackElements.length; i++) {
            var element = trackElements[i]
            var localCones = element.getConePlacements(pixelsPerFoot)
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

        // Step 2: dedupe overlapping cones (mostly at mated gate junctions)
        var epsilonFt = .4 // Dedupe within this
        ConeUtils.dedupeElementCones(elementConeGroups, epsilonFt * pixelsPerFoot)

        // Step 3: order cones by walking the mate graph, then stitch remaining
        //         disconnected chains together via nearest-neighbor
        var chains = ConeUtils.buildChains(trackElements, elementConeGroups)
        var orderedGlobalCones = ConeUtils.stitchChains(chains)

        // Step 4: convert final ordered list to the reference frame (feet), assign index
        var cones = []
        var previewMarkers = []

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
            previewMarkers.push({ index: k, x: gc.x, y: gc.y, heading: gc.heading, coneType: gc.coneType })
        }

        console.log("=== Post-Processing Result:", cones.length, "cones ===")
        for (var m = 0; m < cones.length; m++) {
            var c = cones[m]
            console.log("[" + c.index + "] " + c.coneType + "  x: " + c.x.toFixed(2) + "ft  y: " + c.y.toFixed(2) + "ft  heading: " + c.heading.toFixed(1) + "°")
        }

        AppState.canvasArea.showConePreview(previewMarkers, pixelsPerFoot)
        return cones
    }
}
