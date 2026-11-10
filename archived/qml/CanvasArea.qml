import QtQuick 2.15
import QtQuick.Controls


Rectangle {
    id: root


    color: "#010426"


    // ================================================================
    // PLACED ELEMENTS
    // ================================================================

    property var elements: []


    // ================================================================
    // SIGNALS TO MAIN
    // ================================================================

    signal elementSelected(
        Item element,
        var properties
    )


    signal elementDeselected(
        Item element
    )


    // ================================================================
    // EMPTY CANVAS CLICK
    // ================================================================

    MouseArea {
        id: canvasMouseArea


        anchors.fill:
            parent


        /*
         * Shape MouseAreas are children of the canvas and receive
         * clicks on shapes.

         * This MouseArea handles empty canvas clicks.
         */

        onClicked: {

            root.deselectAll()
        }
    }


    // ================================================================
    // REGISTER ELEMENT
    // ================================================================

    function registerElement(element) {


        if (
            root.elements.indexOf(
                element
            ) !== -1
        ) {

            return
        }


        root.elements.push(
            element
        )


        /*
         * Forward the element's selection signal to Main.qml.

         * The element remains the owner of its selection state.
         */

        element.selectedForEditing.connect(
            function(properties) {


                /*
                 * Deselect every other element.

                 * This is the canvas-wide part of selection.
                 */

                for (
                    var i = 0;
                    i < root.elements.length;
                    ++i
                ) {


                    var other =
                        root.elements[i]


                    if (
                        other !== element &&
                        other.selected
                    ) {

                        other.selected =
                            false
                    }
                }


                root.elementSelected(
                    element,
                    properties
                )
            }
        )


        /*
         * When the element becomes deselected, notify Main.qml.

         * This is important when the canvas itself is clicked.
         */

        element.selectionStateChanged.connect(
            function(selected) {


                if (!selected) {

                    root.elementDeselected(
                        element
                    )
                }
            }
        )
    }


    // ================================================================
    // UNREGISTER ELEMENT
    // ================================================================

    function unregisterElement(element) {

        var index =
            root.elements.indexOf(element)


        if (index !== -1) {

            root.elements.splice(
                index,
                1
            )


            root.elements =
                root.elements
        }
    }


    // ================================================================
    // DESELECT ALL
    // ================================================================

    function deselectAll() {


        /*
         * Copy the array because selection signals may cause
         * other application logic to run.
         */

        var currentElements =
            root.elements.slice()


        for (
            var i = 0;
            i < currentElements.length;
            ++i
        ) {


            var element =
                currentElements[i]


            if (element.selected) {

                element.selected =
                    false
            }
        }
    }


    // ================================================================
    // GLOBAL BOUNDARY CHECK
    // ================================================================

    function containsGlobalPoint(point) {


        var topLeft =
            root.mapToItem(
                Overlay.overlay,
                0,
                0
            )


        return (
            point.x >= topLeft.x &&
            point.x <=
                topLeft.x + root.width &&

            point.y >= topLeft.y &&
            point.y <=
                topLeft.y + root.height
        )
    }
}
