import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/setup.mjs" as Setup

// The four setup steps at the top of the side panel: photo, ruler, Origin, Direction. Each row ticks when its step is
// done; the ruler and target rows hold the tiles dragged onto the canvas. With every step done it folds to one line
// (click it to unfold); a step that comes undone unfolds it again.
ColumnLayout {
    id: checklist
    required property CanvasView canvas
    signal loadPhoto()
    signal useBlueprint()

    readonly property var status: Setup.status(TrackStore.track)
    readonly property bool done: status.done
    property bool unfolded: false
    readonly property bool open: !done || unfolded
    onDoneChanged: unfolded = false

    spacing: 6

    // A step's number, or a tick once it is done.
    component Tick: Label {
        required property bool ticked
        required property int number
        text: ticked ? "✓" : String(number)
        color: ticked ? "#4caf50" : "#b0b0b0"
        font.bold: true
        Layout.preferredWidth: 18
    }

    // A step placed by dragging its tile onto the canvas.
    component Step: ColumnLayout {
        id: step
        required property CanvasView canvas
        required property bool ticked
        required property int number
        required property string kind
        required property string name
        required property color colour
        required property string hint
        required property bool placed
        Layout.fillWidth: true
        spacing: 2
        RowLayout {
            Tick { ticked: step.ticked; number: step.number }
            PaletteTile {
                canvas: step.canvas
                kind: step.kind
                name: step.name
                colour: step.colour
                tip: step.hint
                usable: !step.placed
                Layout.fillWidth: false
                Layout.preferredWidth: 110
                Layout.preferredHeight: 36
            }
        }
        Label {
            Layout.leftMargin: 24
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: step.hint
            color: "#b0b0b0"
            font.pixelSize: 11
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Label {
            text: checklist.done ? qsTr("Setup ✓ (photo, ruler, targets)") : qsTr("Setup")
            font.bold: true
            color: checklist.done ? "#4caf50" : "#ffffff"
        }
        Item { Layout.fillWidth: true }
        Label {
            visible: !checklist.done
            text: qsTr("%1 of 4").arg(checklist.status.count)
            color: "#b0b0b0"
        }
        TapHandler {
            enabled: checklist.done
            onTapped: checklist.unfolded = !checklist.unfolded
        }
    }

    ColumnLayout {
        visible: checklist.open
        spacing: 2
        RowLayout {
            Tick { ticked: checklist.status.photo; number: 1 }
            Label { text: qsTr("Photo"); color: "#e0e0e0" }
        }
        RowLayout {
            Layout.leftMargin: 24
            Button {
                text: qsTr("Load lot photo…")
                focusPolicy: Qt.NoFocus
                onClicked: checklist.loadPhoto()
            }
            Button {
                text: qsTr("Use the blueprint")
                focusPolicy: Qt.NoFocus
                onClicked: checklist.useBlueprint()
            }
        }
    }

    Step {
        visible: checklist.open
        canvas: checklist.canvas
        number: 2
        kind: "ruler"
        name: qsTr("Ruler")
        colour: "#f5cb42"
        ticked: checklist.status.ruler
        placed: TrackStore.track.ruler !== null
        hint: qsTr("Drag onto something you know the length of, such as a parking space, then type its real length.")
    }
    Step {
        visible: checklist.open
        canvas: checklist.canvas
        number: 3
        kind: "origin"
        name: qsTr("Origin")
        colour: "#00ffff"
        ticked: checklist.status.origin
        placed: TrackStore.track.targets.origin !== null
        hint: qsTr("x and y are measured from here.")
    }
    Step {
        visible: checklist.open
        canvas: checklist.canvas
        number: 4
        kind: "direction"
        name: qsTr("Direction")
        colour: "#00ffff"
        ticked: checklist.status.direction
        placed: TrackStore.track.targets.direction !== null
        hint: qsTr("x points from Origin toward here, at least 1 m away.")
    }

    Label {
        visible: !checklist.done
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("Track pieces unlock when setup is done.")
        color: "#b0b0b0"
    }
}
