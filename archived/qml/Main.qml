import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtCore


ApplicationWindow {
    id: window


    width:
        1920


    height:
        1080


    visible:
        true


    title:
        "Conestructor | v1.0"


    // ================================================================
    // CURRENT SELECTION
    // ================================================================

    property Item selectedElement:
        null


    // ================================================================
    // CANVAS
    // ================================================================

    CanvasArea {
        id: canvasArea


        anchors.top:
            parent.top


        anchors.bottom:
            parent.bottom


        anchors.left:
            parent.left


        anchors.right:
            panelStack.left
    }


    // ================================================================
    // PANEL COMPONENTS
    // ================================================================

    Component {
        id: elementPanel


        ElementPanel {
            canvas:
                canvasArea
        }
    }


    Component {
        id: propertyPanel


        PropertyPanel {
            id: propertyPanelInstance


            selectedElement:
                window.selectedElement
        }
    }


    // ================================================================
    // PANEL STACK
    // ================================================================

    StackView {
        id: panelStack


        anchors.top:
            parent.top


        anchors.bottom:
            parent.bottom


        anchors.right:
            parent.right


        width:
            300


        initialItem:
            elementPanel


        replaceEnter:
            Transition {}


        replaceExit:
            Transition {}
    }


    // ================================================================
    // ELEMENT SELECTION
    // ================================================================

    Connections {
        target:
            canvasArea


        // Only needed if CanvasArea emits a selection signal.
    }


    function selectElement(
        element,
        properties
    ) {


        window.selectedElement =
            element


        panelStack.replace(
            propertyPanel
        )


        var panel =
            panelStack.currentItem


        if (
            panel &&
            panel.loadProperties
        ) {


            panel.loadProperties(
                properties
            )
        }
    }
}
