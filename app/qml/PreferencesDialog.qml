import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/units.mjs" as Units

// Edit > Preferences. Part 1 has one section, Units; parts 3 and 4 add Cones, Car and Team.
Dialog {
    id: dialog
    title: qsTr("Preferences")
    modal: true
    standardButtons: Dialog.Close
    anchors.centerIn: parent

    ColumnLayout {
        spacing: 6

        Label {
            text: qsTr("Units")
            font.bold: true
        }
        Label {
            text: qsTr("How lengths are shown and typed. Files always store metres.")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: 320
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
    }
}
