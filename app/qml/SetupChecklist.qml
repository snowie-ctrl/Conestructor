import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/setup.mjs" as Setup

// The four setup steps at the top of the side panel: photo, ruler, Origin, Direction. Each row ticks when its step is
// done; the step to do now is highlighted and the steps after it dimmed (the coach card on the canvas says the same).
// The ruler and target rows hold tiles to click or drag onto the canvas. With every step done it folds to one line
// (click it to unfold); a step that comes undone unfolds it again.
ColumnLayout {
    id: checklist
    required property CanvasView canvas
    signal loadPhoto()
    signal useBlueprint()

    readonly property var status: Setup.status(TrackStore.track)
    readonly property bool done: status.done
    // The step to do now (1 to 4), or 0 once setup is done: its row is highlighted and the rows after it dimmed.
    readonly property int currentNumber: {
        const step = Setup.current(TrackStore.track)
        return step === "" ? 0 : Setup.CARDS[step].number
    }
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

    // One step's row: highlighted when it is the step to do now, dimmed when it comes later.
    component StepRow: Rectangle {
        required property int number
        required property bool ticked
        readonly property bool current: number === checklist.currentNumber
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 8
        radius: 4
        color: current ? "#22324d" : "transparent"
        border.color: current ? "#2f6fd6" : "transparent"
        opacity: !ticked && checklist.currentNumber > 0 && number > checklist.currentNumber ? 0.45 : 1
        ColumnLayout {
            id: inner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            spacing: 2
        }
    }

    // A step placed with its tile: click the tile, then the canvas (or drag it there).
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
            objectName: "setupTitle"
            text: checklist.done ? qsTr("Setup ✓ (photo, ruler, targets)") : qsTr("Setup: start here")
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

    StepRow {
        objectName: "setupStep1"
        visible: checklist.open
        number: 1
        ticked: checklist.status.photo
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

    StepRow {
        objectName: "setupStep2"
        visible: checklist.open
        number: 2
        ticked: checklist.status.ruler
        Step {
            canvas: checklist.canvas
            number: 2
            kind: "ruler"
            name: qsTr("Ruler")
            colour: "#f5cb42"
            ticked: checklist.status.ruler
            placed: TrackStore.track.ruler !== null
            hint: qsTr("Click it, then click both ends of something you know the length of, such as a parking space; then type its real length.")
        }
    }
    StepRow {
        objectName: "setupStep3"
        visible: checklist.open
        number: 3
        ticked: checklist.status.origin
        Step {
            canvas: checklist.canvas
            number: 3
            kind: "origin"
            name: qsTr("Origin")
            colour: "#00ffff"
            ticked: checklist.status.origin
            placed: TrackStore.track.targets.origin !== null
            hint: qsTr("Click it, then click a spot you can find on the real lot. x and y are measured from here.")
        }
    }
    StepRow {
        objectName: "setupStep4"
        visible: checklist.open
        number: 4
        ticked: checklist.status.direction
        Step {
            canvas: checklist.canvas
            number: 4
            kind: "direction"
            name: qsTr("Direction")
            colour: "#00ffff"
            ticked: checklist.status.direction
            placed: TrackStore.track.targets.direction !== null
            hint: qsTr("Click it, then click a second landmark well away from Origin. x points from Origin toward here.")
        }
    }

    Label {
        visible: !checklist.done
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("Track pieces unlock when setup is done.")
        color: "#b0b0b0"
    }
}
