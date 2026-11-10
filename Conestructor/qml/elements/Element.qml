import QtQuick 2.15
import QtQuick.Controls

import Conestructor


Item {
    id: root


    // <--- SHAPE PROPERTIES ---> //       <-- Contract for each shape to change
    property string shapeName:              ""
    property color shapeColor:              "#FFFFFF"
    property Item shape:                    null
    property bool hasGates:                 true
    property var shapeEditableProperties:   []

    property point gateA:       Qt.point(0,0)
    property point gateB:       Qt.point(0,0)
    property real gateAHeading: 0
    property real gateBHeading: 0
    property var gateAMate:     null
    property var gateBMate:     null


    // <--- ELEMENT PROPERTIES ---> //
    property real xPos              // horizontal center location
    property real yPos              // vertical center location
    property real elementRotation   // effectively the same as just the rotation property of item


    // <--- VARIABLES ---> //
    property int positionUpdateInterval:    100 // in ms


    // <--- STATE ---> //
    property bool placed:   false
    property bool selected: AppState.selectedElement === root
    property bool dragging: false

    property point dragOffset
    property var currentSnap: null


    // <--- SIGNALS ---> //
    signal selected(var properties)
    signal dragStarted()
    signal propertiesChanged(var properties)


    // <--- ACTUAL VALUES ---> //
    opacity: root.dragging || root.selected ? 0.5 : 1.0
    x: xPos - width / 2
    y: yPos - height / 2
    rotation: elementRotation
    transformOrigin: Item.Center


    Timer {
        id: propertyUpdateTimer
        interval: root.positionUpdateInterval
        repeat: false
        onTriggered: {
            if (root.selected)
                root.propertiesChanged(root.getEditableProperties())
        }
    }


    MouseArea {
        id: mouseArea
        anchors.fill: parent
        containmentMask: root.shape

        onPressed: function(mouse) {
            if (!root.placed) {
                root.dragging = true
                root.elementRotation = 0
                root.setupDrag(mouse)
                return
            }

            if (!root.selected) {
                AppState.selectElement(root)
                return
            }

            if (root.placed && root.selected) {
                root.dragging = true
                root.setupDrag(mouse)
                return
            }
        }

        onPositionChanged: function(mouse) {
            if (!pressed || !root.dragging) return

            var mouseGlobal = mouseArea.mapToItem(Overlay.overlay, mouse.x, mouse.y)

            root.xPos = Math.round(mouseGlobal.x - root.dragOffset.x)
            root.yPos = Math.round(mouseGlobal.y - root.dragOffset.y)

            var ignoreSnap = (mouse.modifiers & Qt.ControlModifier) !== 0

            if (root.hasGates && !ignoreSnap) {
                var snap = AppState.canvasArea.findNearestGate(root)

                if (snap !== null) {
                    root.currentSnap = snap
                    root.snapToGate(snap.draggedElementGate, snap.element, snap.elementGate)
                } else {
                    root.currentSnap = null
                }
            } else {
                root.currentSnap = null
            }

            if (root.selected && !propertyUpdateTimer.running)
                propertyUpdateTimer.start()
        }

        onReleased: {
            if (!root.dragging) return

            root.dragging = false
            propertyUpdateTimer.stop()

            if (root.currentSnap !== null) {
                var snap = root.currentSnap
                root.createMate(snap.draggedElementGate, snap.element, snap.elementGate)
                root.currentSnap = null
            }

            if (root.selected)
                root.propertiesChanged(root.getEditableProperties())

            root.finishDrag()
        }
    }


    function setupDrag(mouse) {
        if (root.placed) {
            root.breakMate("A")
            root.breakMate("B")
        }

        var elementCenter = root.mapToItem(Overlay.overlay, root.width / 2, root.height / 2)
        var mouseGlobal = mouseArea.mapToItem(Overlay.overlay, mouse.x, mouse.y)

        root.dragOffset = Qt.point(
            mouseGlobal.x - elementCenter.x,
            mouseGlobal.y - elementCenter.y
        )

        root.dragStarted()

        root.parent = Overlay.overlay
        root.xPos = elementCenter.x
        root.yPos = elementCenter.y
    }

    function finishDrag() {
        var globalCenter = Qt.point(root.xPos, root.yPos)
        var insideCanvas = AppState.canvasArea.containsGlobalPoint(globalCenter)

        if (!insideCanvas) {
            // Only ever reached by the element the user directly dragged —
            // cascaded mates never pass through finishDrag(), so a chain
            // pushed off-canvas by a cascade is never at risk here.
            AppState.canvasArea.unregisterElement(root)
            root.destroy()
            return
        }

        var canvasPosition = AppState.canvasArea.mapFromItem(Overlay.overlay, globalCenter.x, globalCenter.y)

        root.parent = AppState.canvasArea
        root.xPos = Math.round(canvasPosition.x)
        root.yPos = Math.round(canvasPosition.y)

        if (!root.placed) {
            root.placed = true
            AppState.canvasArea.registerElement(root)
        }
    }

    function getEditableProperties() {
        var allNames = ["xPos", "yPos", "elementRotation"].concat(root.shapeEditableProperties)
        var result = {}
        for (var i = 0; i < allNames.length; i++)
            result[allNames[i]] = root[allNames[i]]
        return result
    }

    function applyProperties(newValues) {
        for (var propName in newValues) {
            if (propName in root)
                root[propName] = newValues[propName]
        }
        root.propagateFromSelf()
    }


    // <--- GATE GEOMETRY ---> //

    function getGateLocalPosition(gateName) {
        return gateName === "A" ? root.gateA : root.gateB
    }

    function getGateGlobalPosition(gateName) {
        var localGate = root.getGateLocalPosition(gateName)
        return root.mapToItem(Overlay.overlay, localGate.x + root.width / 2, localGate.y + root.height / 2)
    }

    function getGateLocalHeading(gateName) {
        return gateName === "A" ? root.gateAHeading : root.gateBHeading
    }

    function getGateGlobalHeading(gateName) {
        var localHeading = gateName === "A" ? root.gateAHeading : root.gateBHeading
        return root.elementRotation + localHeading
    }

    function normalizeAngle(angle) {
        while (angle > 180) angle -= 360
        while (angle < -180) angle += 360
        return angle
    }

    // Rotates + translates root so that `ownGate` coincides, facing opposite,
    // with `targetElement`'s `targetGate`.
    function snapToGate(ownGate, targetElement, targetGate) {
        var targetHeading = targetElement.getGateGlobalHeading(targetGate)
        var ownLocalHeading = root.getGateLocalHeading(ownGate)
        var desiredRotation = targetHeading + 180 - ownLocalHeading
        root.elementRotation = root.normalizeAngle(desiredRotation)

        var ownPosition = root.getGateGlobalPosition(ownGate)   // reflects the rotation just set
        var targetPosition = targetElement.getGateGlobalPosition(targetGate)

        root.xPos += targetPosition.x - ownPosition.x
        root.yPos += targetPosition.y - ownPosition.y
    }


    // <--- CASCADING ---> //

    // Call after this element's gates may have moved for a reason other than
    // being actively dragged (property edits, or settling a new mate).
    // Walks outward through the mate graph, keeping every connected element
    // glued to its neighbor's gate.
    function chainLength(gateName, visited) {
        var mate = gateName === "A" ? root.gateAMate : root.gateBMate
        if (!mate) return 0
        if (visited.indexOf(mate.element) !== -1) return 0   // cycle guard

        visited.push(mate.element)
        var farGate = mate.gate === "A" ? "B" : "A"
        return 1 + mate.element.chainLength(farGate, visited)
    }

    function propagateFromSelf() {
        var hasA = root.gateAMate !== null
        var hasB = root.gateBMate !== null

        if (!hasA && !hasB) return   // free-floating, nothing connected, nothing to do

        if (hasA && hasB) {
            var lengthA = root.chainLength("A", [root])
            var lengthB = root.chainLength("B", [root])

            var anchorGate = lengthA >= lengthB ? "A" : "B"
            var looseGate = anchorGate === "A" ? "B" : "A"
            var anchorMate = anchorGate === "A" ? root.gateAMate : root.gateBMate

            // Move self to match the longer (more expensive) side instead of dragging it
            root.snapToGate(anchorGate, anchorMate.element, anchorMate.gate)

            // Only the shorter side needs to follow self's new position
            root.cascadeGate(looseGate, [root])
        } else {
            // Only one side connected — it's the anchor by definition.
            // Move self to meet it; there's nothing on the other side to cascade.
            var onlyGate = hasA ? "A" : "B"
            var onlyMate = hasA ? root.gateAMate : root.gateBMate
            root.snapToGate(onlyGate, onlyMate.element, onlyMate.gate)
        }
    }

    function cascadeGate(gateName, visited) {
        var mate = gateName === "A" ? root.gateAMate : root.gateBMate
        if (!mate) return

        var otherElement = mate.element
        var otherGate = mate.gate

        if (visited.indexOf(otherElement) !== -1) return

        otherElement.snapToGate(otherGate, root, gateName)
        visited.push(otherElement)

        // Keep the property panel in sync if this cascaded element happens
        // to be the one currently displayed — otherwise its cached fields
        // go stale and get reasserted (fighting the cascade) on next Apply.
        if (otherElement.selected)
            otherElement.propertiesChanged(otherElement.getEditableProperties())

        var farGate = otherGate === "A" ? "B" : "A"
        otherElement.cascadeGate(farGate, visited)
    }


    // <--- MATING ---> //

    function createMate(ownGate, otherElement, otherGate) {
        var ownMate = { element: otherElement, gate: otherGate }
        var otherMate = { element: root, gate: ownGate }

        if (ownGate === "A") root.gateAMate = ownMate
        else root.gateBMate = ownMate

        if (otherGate === "A") otherElement.gateAMate = otherMate
        else otherElement.gateBMate = otherMate
    }

    function breakMate(gateName) {
        var mate = gateName === "A" ? root.gateAMate : root.gateBMate
        if (mate === null) return

        var other = mate.element
        var otherGate = mate.gate

        if (otherGate === "A") other.gateAMate = null
        else other.gateBMate = null

        if (gateName === "A") root.gateAMate = null
        else root.gateBMate = null
    }


    // default: no cones (safe fallback for shapes that haven't implemented this yet)
    function getConePlacements() {
        return []   // list of { x, y, heading, coneType } in element-local pixel space
    }
}
