import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import Conestructor


ApplicationWindow {
    id: root


    width: 1920
    height: 1080
    visible: true
    title: "Constructor | v1.2"




    menuBar: MenuBar {
            // General file menu
        Menu {
            title: "File"

            MenuItem { text: "New" }
            MenuItem { text: "Open" }
            MenuSeparator {}
            MenuItem { text: "Save As" }
            MenuItem { text: "Save" }
            MenuItem { text: "Export" }
        }

            // Post processing controls
        Menu {
            title: "Process"

            MenuItem { text: "Post process"; onClicked: PostProcessor.run() }
            Menu {
                title: "Mode"

                MenuItem { text: "Minimal" }
                MenuItem { text: "Optimal" }
                MenuItem { text: "Maximum" }
            }
            MenuItem { text: "Reset"; onClicked: canvasArea.clearConePreview() }
            MenuSeparator {}
            MenuItem { text: "Save As"; onClicked: exportPopup.openFor("save") }
            MenuItem { text: "Export"; onClicked: exportPopup.openFor("export") }
        }

            // Tools menu
        Menu {
            title: "Tools"

            Menu {
                title: "Backgrounds"

                MenuItem { text: "Blueprint"; onClicked: canvasArea.imagePath = "../assets/images/blueprintBackground.png" }
                MenuItem { text: "Duck pond"; onClicked: canvasArea.imagePath = "../assets/images/duckPondBirdeye.png" }
                MenuItem { text: "Riverwind"; onClicked: canvasArea.imagePath = "../assets/images/riverwindBirdeye.png" }
            }

            Menu {
                title: "Spawn"

                MenuItem { text: "2025 car" }
            }

            MenuItem { text: "Toggle cones"; onClicked: canvasArea.toggleConeDots() }
            MenuItem { text: "Toggle paths"; onClicked: canvasArea.toggleRouteLines() }
        }
    }


    Popup {
        id: exportPopup
        width: 420
        height: 420
        modal: true
        focus: true
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        closePolicy: Popup.CloseOnEscape

        property string mode: "save"
        property string fileType: "xlsx"

        function openFor(triggerMode) {
            mode = triggerMode
            open()
        }
        function urlToLocalPath(fileUrl) {
            var path = fileUrl.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^file:\/{3}/, "")   // strip exactly 3 slashes on Windows
            } else {
                path = path.replace(/^file:\/\//, "")    // strip 2 slashes on Linux/macOS
            }
            return decodeURIComponent(path)
        }

        component WhiteRadioButton: RadioButton {
            contentItem: Label {
                text: parent.text
                color: "white"
                verticalAlignment: Text.AlignVCenter
                leftPadding: parent.indicator.width + parent.spacing
            }
        }

        background: Rectangle {
            color: "#2a2a2a"
            border.color: "#555"
            radius: 6
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Label {
                text: exportPopup.mode === "save" ? "Save Track" : "Export Track"
                font.bold: true
                font.pointSize: 14
                color: "white"
            }

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Location"; color: "white"; Layout.preferredWidth: 100 }
                TextField { id: locationField; Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Processing Type"; color: "white"; Layout.preferredWidth: 100 }
                TextField { id: processingTypeField; Layout.fillWidth: true; text: "generic" }
            }

            Label { text: "Format:"; color: "white" }

            // RowLayout { spacing: 12
            //     WhiteRadioButton { text: "XLSX (full info)"; checked: exportPopup.fileType === "xlsx"; onClicked: exportPopup.fileType = "xlsx" }
            // }
            RowLayout { spacing: 12
                WhiteRadioButton { text: "JSON (cones only)"; checked: exportPopup.fileType === "json"; onClicked: exportPopup.fileType = "json" }
            }
            RowLayout { spacing: 12
                WhiteRadioButton { text: "PNG (canvas image)"; checked: exportPopup.fileType === "png"; onClicked: exportPopup.fileType = "png" }
            }
            RowLayout { spacing: 12
                WhiteRadioButton { text: "Upload to database"; checked: exportPopup.fileType === "database"; onClicked: exportPopup.fileType = "database" }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button { text: "Cancel"; Layout.fillWidth: true; onClicked: exportPopup.close() }

                Button {
                    text: exportPopup.fileType === "database" ? "Upload" : "Save"
                    Layout.fillWidth: true
                    onClicked: exportPopup.beginExport()
                }
            }
        }

        function beginExport() {
            var cones = PostProcessor.run()
            var metadata = {
                location: locationField.text,
                numCones: cones.length,
                processingType: processingTypeField.text
            }

            if (fileType === "database") {
                canvasArea.grabToImage(function(result) {
                    var imagePath = exportManager.tempImagePath()
                    result.saveToFile(imagePath)
                    exportManager.uploadToDatabase(metadata, cones, imagePath)
                    exportPopup.close()
                })
                return
            }

            if (fileType === "json") {
                jsonSaveDialog.pendingCones = cones
                jsonSaveDialog.open()
            // } else if (fileType === "xlsx") {
            //     xlsxSaveDialog.pendingMetadata = metadata
            //     xlsxSaveDialog.pendingCones = cones
            //     xlsxSaveDialog.open()
            } else if (fileType === "png") {
                pngSaveDialog.open()
            }
        }

        FileDialog {
            id: jsonSaveDialog
            property var pendingCones: []
            fileMode: FileDialog.SaveFile
            nameFilters: ["JSON files (*.json)"]
            defaultSuffix: "json"
            onAccepted: {
                var path = exportPopup.urlToLocalPath(selectedFile)
                exportManager.exportJson(pendingCones, path)
                exportPopup.close()
            }
        }

        FileDialog {
            id: pngSaveDialog
            fileMode: FileDialog.SaveFile
            nameFilters: ["PNG images (*.png)"]
            defaultSuffix: "png"
            onAccepted: {
                var path = exportPopup.urlToLocalPath(selectedFile)
                canvasArea.grabToImage(function(result) {
                    result.saveToFile(path)
                    exportManager.exportPng(path)
                    exportPopup.close()
                })
            }
        }
    }




    CanvasArea {
        id: canvasArea

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: panelArea.left


    }


    Item {
        id: panelArea
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 250

        ElementPanel {
            id: elementPanelInstance
            anchors.fill: parent
            visible: AppState.selectedElement === null
        }

        PropertyPanel {
            id: propertyPanelInstance
            anchors.fill: parent
            visible: AppState.selectedElement !== null
        }
    }
}
