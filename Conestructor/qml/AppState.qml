pragma Singleton

import QtQuick

QtObject {
    id: root


    // <--- STATE MANGEMENT ---> //

    property var selectedElement: null


    // <--- PREFERENCES ---> //
    property color backgroundColor: "#1f1f1f"


    // <--- IMPORTANT REFERENCES ---> //
    property Item canvasArea:       null
    property Item elementPanel:     null
    property Item propertyPanel:    null


    // <--- SIGNALS ---> //

    signal selectionChanged(var element)



    // <--- CONSOLE LOGGING ---> //
    onSelectedElementChanged: console.log("Selected element: " + root.selectedElement)



    // <--- API FUNCTIONS ---> //

    function selectElement(element) {
        if (selectedElement === element) return

        root.selectedElement = element
        root.selectionChanged(element)
    }


    function deselectElements() {
        if (selectedElement === null) return

        root.selectedElement = null
        root.selectionChanged(null)
    }
}
