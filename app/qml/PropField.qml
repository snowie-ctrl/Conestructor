import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/elements.mjs" as Elements
import "logic/units.mjs" as Units

// One setting: a field in the chosen units with up and down arrows (length, angle, count), or a two-way switch
// (choice). Changes apply as you type. Text that is not a value turns red and the old value stays until it is fixed
// or Esc puts it back; a value outside the setting's limits is kept within them, with a note.
ColumnLayout {
    id: field

    required property var def
    required property var value
    property bool emptyWhenZero: false
    signal edited(var newValue)
    signal finished()

    property bool bad: false
    property string note: ""
    readonly property string unit: Settings.units
    readonly property bool isChoice: def.kind === "choice"

    Layout.fillWidth: true
    spacing: 2

    function shown() {
        if (emptyWhenZero && !(value > 0))
            return ""
        return Units.formatValue(def.kind, value, unit)
    }

    function refresh() {
        if (!input.activeFocus) {
            input.text = shown()
            bad = false
        }
    }

    // Stores a parsed value, kept within limits; returns what was stored.
    function apply(parsed) {
        const c = Elements.clamp(def, parsed)
        note = c.clamped ? qsTr("Kept within %1 to %2").arg(Units.formatValue(def.kind, def.min, unit))
                                                          .arg(Units.formatValue(def.kind, def.max, unit)) : ""
        if (c.value !== value)
            edited(c.value)
        return c.value
    }

    function typed(text) {
        const parsed = Units.parseValue(def.kind, text, unit)
        bad = isNaN(parsed)
        if (!bad)
            apply(parsed)
    }

    function step(direction) {
        const stored = apply(Number(value) + direction * Units.stepFor(def.kind, unit))
        input.text = Units.formatValue(def.kind, stored, unit)
        bad = false
    }

    onValueChanged: refresh()
    onUnitChanged: {
        input.text = shown()
        bad = false
    }
    Component.onCompleted: refresh()

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Label {
            text: field.def.label
            color: "#e0e0e0"
            Layout.preferredWidth: 104
            elide: Text.ElideRight
        }

        RowLayout {
            visible: field.isChoice
            spacing: 0
            Repeater {
                model: field.isChoice ? field.def.choices.length : 0
                Button {
                    required property int index
                    text: field.def.labels[index]
                    checkable: true
                    checked: field.value === field.def.choices[index]
                    focusPolicy: Qt.NoFocus
                    // Only `edited`: a choice can change which settings show, and the panel then rebuilds this field
                    // before the handler returns. The panel ends the undo step for choices.
                    onClicked: field.edited(field.def.choices[index])
                }
            }
        }

        TextField {
            id: input
            visible: !field.isChoice
            Layout.fillWidth: true
            color: field.bad ? "#ff6b6b" : "#f0f0f0"
            placeholderText: field.emptyWhenZero ? qsTr("Type it here") : ""
            selectByMouse: true
            onTextEdited: field.typed(text)
            onEditingFinished: {
                if (!field.bad)
                    text = field.shown()
                field.finished()
            }
            Keys.onEscapePressed: {
                field.bad = false
                field.note = ""
                text = field.shown()
            }
            Keys.onUpPressed: field.step(1)
            Keys.onDownPressed: field.step(-1)
        }

        ColumnLayout {
            visible: !field.isChoice
            spacing: 0
            ToolButton {
                text: "▲"
                font.pixelSize: 9
                implicitHeight: 15
                focusPolicy: Qt.NoFocus
                onClicked: { field.step(1); field.finished() }
            }
            ToolButton {
                text: "▼"
                font.pixelSize: 9
                implicitHeight: 15
                focusPolicy: Qt.NoFocus
                onClicked: { field.step(-1); field.finished() }
            }
        }
    }

    Label {
        visible: field.note !== ""
        text: field.note
        color: "#ffb74d"
        font.pixelSize: 11
        Layout.leftMargin: 110
    }
}
