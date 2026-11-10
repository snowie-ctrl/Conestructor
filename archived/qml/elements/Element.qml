import QtQuick 2.15
import QtQuick.Controls


Item {
    id: root


    // ================================================================
    // POSITION
    // ================================================================

    property real xPos: 0
    property real yPos: 0

    property real elementRotation: 0


    property int propertyUpdateInterval: 100 // in ms


    x:
        xPos - width / 2


    y:
        yPos - height / 2


    rotation:
        elementRotation


    transformOrigin:
        Item.Center


    // ================================================================
    // SHAPE CONTRACT
    // ================================================================

    property string shapeName: ""

    property Item hitShape: null


    // ================================================================
    // GATE PROPERTIES
    // ================================================================

    property bool hasGate: false

    property point entryLocal:
        Qt.point(0, 0)

    property point exitLocal:
        Qt.point(0, 0)

    property real entryGateHeading:
        0

    property real exitGateHeading:
        0


    // ================================================================
    // REFERENCES
    // ================================================================

    property Item canvasRef: null


    // ================================================================
    // STATE
    // ================================================================

    property bool placed: false

    property bool dragging: false

    property bool selected: false


    opacity:
        root.dragging ||
        root.selected
        ? 0.5
        : 1.0


    // ================================================================
    // SIGNALS
    // ================================================================

    signal dragStarted()


    signal selectedForEditing(
        var properties
    )


    signal selectionStateChanged(
        bool selected
    )

    signal propertiesChanged(var properties) //i.e. while dragging shape, tyhe xPos and yPos change
    signal propertiesApplied(bool success, string message)


    // ================================================================
    // DRAG STATE
    // ================================================================

    property point dragOffset


    // ================================================================
    // SELECTION STATE
    // ================================================================

    onSelectedChanged: {

        selectionStateChanged(
            root.selected
        )
    }


    // ================================================================
    // MOUSE AREA
    // ================================================================

    MouseArea {
        id: mouseArea


        anchors.fill:
            parent


        containmentMask:
            root.hitShape


        onPressed: function(mouse) {


            /*
             * A shape still inside a spawner cannot be selected.

             * It can only be dragged.
             */

            if (!root.placed) {

                root.selected =
                    false


                root.dragging =
                    true


                root.beginDrag(
                    mouse
                )


                return
            }


            /*
             * First click on a placed element:
             *
             *     select it
             *     send its properties
             */

            if (!root.selected) {


                root.selected =
                    true


                root.selectedForEditing(
                    root.getEditableProperties()
                )


                return
            }


            /*
             * Second click-and-hold:
             *
             *     move the already-selected element
             */

            root.dragging =
                true


            root.beginDrag(
                mouse
            )
        }


        Timer {
            id: propertyUpdateTimer

            interval:
                root.propertyUpdateInterval

            repeat:
                false

            onTriggered: {

                if (root.selected) {

                    root.propertiesChanged(
                        root.getEditableProperties()
                    )
                }
            }
        }


        onPositionChanged: function(mouse) {

            if (
                !pressed ||
                !root.dragging
            ) {
                return
            }


            var mouseGlobal =
                mouseArea.mapToItem(
                    Overlay.overlay,
                    mouse.x,
                    mouse.y
                )


            root.xPos =
                Math.round(
                    mouseGlobal.x -
                    root.dragOffset.x
                )


            root.yPos =
                Math.round(
                    mouseGlobal.y -
                    root.dragOffset.y
                )


            if (
                root.selected &&
                propertyUpdateTimer.running === false
            ) {

                propertyUpdateTimer.start()
            }
        }


        onReleased: {

            if (!root.dragging)
                return


            root.dragging =
                false


            propertyUpdateTimer.stop()


            if (root.selected) {

                root.propertiesChanged(
                    root.getEditableProperties()
                )
            }


            root.finishDrag()
        }
    }


    // ================================================================
    // BEGIN DRAG
    // ================================================================

    function beginDrag(mouse) {


        var elementCenter =
            root.mapToItem(
                Overlay.overlay,
                root.width / 2,
                root.height / 2
            )


        var mouseGlobal =
            mouseArea.mapToItem(
                Overlay.overlay,
                mouse.x,
                mouse.y
            )


        root.dragOffset =
            Qt.point(
                mouseGlobal.x -
                elementCenter.x,

                mouseGlobal.y -
                elementCenter.y
            )


        /*
         * The spawner needs to know that its instance is leaving.
         */

        if (!root.placed) {

            root.dragStarted()
        }


        root.parent =
            Overlay.overlay


        root.xPos =
            elementCenter.x


        root.yPos =
            elementCenter.y
    }


    // ================================================================
    // FINISH PLACEMENT
    // ================================================================

    function finishPlacement() {

        if (!root.canvasRef) {

            root.destroy()

            return
        }


        var globalCenter =
            Qt.point(
                root.xPos,
                root.yPos
            )


        if (
            !root.canvasRef.containsGlobalPoint(
                globalCenter
            )
        ) {

            root.canvasRef.unregisterElement(
                root
            )


            root.destroy()

            return
        }


        var canvasPosition =
            root.canvasRef.mapFromItem(
                Overlay.overlay,
                globalCenter.x,
                globalCenter.y
            )


        root.parent =
            root.canvasRef


        root.xPos =
            Math.round(
                canvasPosition.x
            )


        root.yPos =
            Math.round(
                canvasPosition.y
            )


        root.placed =
            true


        root.selected =
            false


        root.canvasRef.registerElement(
            root
        )
    }


    function finishDrag() {

        if (!root.canvasRef) {

            root.destroy()

            return
        }


        var globalCenter =
            Qt.point(
                root.xPos,
                root.yPos
            )


        var insideCanvas =
            root.canvasRef.containsGlobalPoint(
                globalCenter
            )


        if (!insideCanvas) {

            root.canvasRef.unregisterElement(
                root
            )


            root.destroy()

            return
        }


        if (!root.placed) {

            var canvasPosition =
                root.canvasRef.mapFromItem(
                    Overlay.overlay,
                    globalCenter.x,
                    globalCenter.y
                )


            root.parent =
                root.canvasRef


            root.xPos =
                Math.round(
                    canvasPosition.x
                )


            root.yPos =
                Math.round(
                    canvasPosition.y
                )


            root.placed =
                true


            root.selected =
                false


            root.canvasRef.registerElement(
                root
            )
        }
    }


    // ================================================================
    // PROPERTY EXPORT
    // ================================================================

    function getBaseEditableProperties() {
        return {
            "xPos": root.xPos,
            "yPos": root.yPos,
            "rotation": root.elementRotation
        }
    }


    function getEditableProperties() {
        return root.getBaseEditableProperties()
    }


    function applyProperties(
        properties
    ) {


        // ------------------------------------------------------------
        // COMMON ELEMENT PROPERTIES
        // ------------------------------------------------------------

        if (
            properties.hasOwnProperty(
                "xPos"
            )
        ) {

            root.xPos =
                Number(
                    properties.xPos
                )
        }


        if (
            properties.hasOwnProperty(
                "yPos"
            )
        ) {

            root.yPos =
                Number(
                    properties.yPos
                )
        }


        if (
            properties.hasOwnProperty(
                "rotation"
            )
        ) {

            root.elementRotation =
                Number(
                    properties.rotation
                )
        }


        // ------------------------------------------------------------
        // SHAPE-SPECIFIC PROPERTIES
        // ------------------------------------------------------------

        root.applyShapeProperties(
            properties
        )


        root.propertiesApplied(
            true,

            "Properties applied successfully"
        )
    }
}
