import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Conestructor
import "logic/units.mjs" as Units

// Edit > Preferences: Units, Cones (the cones the team owns) and Car (the outline's size and picture), in one scrolling
// column. Part 5 adds Team.
Dialog {
    id: dialog
    objectName: "preferencesDialog"
    title: qsTr("Preferences")
    modal: true
    standardButtons: Dialog.Close
    anchors.centerIn: parent

    // Whether the car picture's file is there: checked when the dialog opens and when the picture changes.
    property bool imageFound: false
    onAboutToShow: imageFound = Settings.carImageFound()
    Connections {
        target: Settings
        function onCarImageChanged() { dialog.imageFound = Settings.carImageFound() }
    }

    ScrollView {
        id: scroll
        implicitWidth: 360
        implicitHeight: Math.min(column.implicitHeight, 560)
        contentWidth: availableWidth

        ColumnLayout {
            id: column
            width: scroll.availableWidth
            spacing: 6

            Label {
                text: qsTr("Units")
                font.bold: true
            }
            Label {
                text: qsTr("How lengths are shown and typed. Files always store metres.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: "#b0b0b0"
            }
            ButtonGroup { id: unitGroup }
            Repeater {
                model: Units.UNITS
                RadioButton {
                    required property string modelData
                    text: Units.LABELS[modelData]
                    ButtonGroup.group: unitGroup
                    checked: Settings.units === modelData
                    onToggled: if (checked) Settings.units = modelData
                }
            }

            Label {
                Layout.topMargin: 12
                text: qsTr("Cones")
                font.bold: true
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("Cones we own")
                    color: "#e0e0e0"
                    Layout.preferredWidth: 104
                }
                TextField {
                    objectName: "conesOwnedField"
                    Layout.fillWidth: true
                    validator: IntValidator { bottom: 0; top: 9999 }
                    placeholderText: qsTr("No budget")
                    text: Settings.conesOwned > 0 ? String(Settings.conesOwned) : ""
                    onTextEdited: Settings.conesOwned = text === "" ? 0 : Number(text)
                }
            }
            Label {
                text: qsTr("The status bar shows the track's cones against this, in red when it needs more.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: "#b0b0b0"
            }

            Label {
                Layout.topMargin: 12
                text: qsTr("Car")
                font.bold: true
            }
            Label {
                text: qsTr("Tools › Car outline shows a car this size on the canvas.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: "#b0b0b0"
            }
            PropField {
                def: ({ key: "carLength", label: qsTr("Length"), kind: "length", min: 0.5, max: 10 })
                value: Settings.carLength
                onEdited: (v) => Settings.carLength = v
            }
            PropField {
                def: ({ key: "carWidth", label: qsTr("Width"), kind: "length", min: 0.5, max: 10 })
                value: Settings.carWidth
                onEdited: (v) => Settings.carWidth = v
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("Top-down image")
                    color: "#e0e0e0"
                    Layout.preferredWidth: 104
                }
                Label {
                    objectName: "carImageName"
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: Settings.carImage === "" ? qsTr("None")
                          : !dialog.imageFound ? qsTr("Image not found")
                          : Settings.carImage.split(/[\\/]/).pop()
                    color: Settings.carImage !== "" && !dialog.imageFound ? "#ffb74d" : "#e0e0e0"
                }
            }
            RowLayout {
                Button {
                    text: qsTr("Choose…")
                    onClicked: carImageDialog.open()
                }
                Button {
                    text: qsTr("Clear")
                    enabled: Settings.carImage !== ""
                    onClicked: Settings.carImage = ""
                }
            }
        }
    }

    FileDialog {
        id: carImageDialog
        title: qsTr("Top-down car image")
        nameFilters: [qsTr("Photos (*.png *.jpg *.jpeg)")]
        onAccepted: Settings.carImage = TrackFile.toLocalPath(selectedFile)
    }
}
