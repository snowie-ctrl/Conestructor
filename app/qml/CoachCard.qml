import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/setup.mjs" as Setup

// The setup step to do now, at the top of the canvas while setup is not done: what it is for, what to do, and a button
// that starts it. It goes once setup is done and comes back if a step comes undone.
Rectangle {
    id: card
    objectName: "coachCard"
    required property CanvasView canvas
    signal loadPhoto()
    signal useBlueprint()

    readonly property string step: Setup.current(TrackStore.track)
    readonly property var info: step !== "" ? Setup.CARDS[step] : null

    visible: info !== null
    width: Math.min(520, canvas.width - 40)
    height: column.implicitHeight + 24
    radius: 8
    color: "#2b2b2b"
    border.color: "#2f6fd6"
    border.width: 2

    // Clicks on the card stay on the card (the canvas under it would select or pan); the wheel still zooms.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: (w) => w.accepted = false
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 6

        Label {
            text: card.info ? card.info.title : ""
            font.bold: true
            font.pixelSize: 15
            color: "#ffffff"
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: card.info ? card.info.text : ""
            color: "#d8d8d8"
        }
        RowLayout {
            spacing: 8
            Button {
                visible: card.step === "photo"
                text: qsTr("Load lot photo…")
                focusPolicy: Qt.NoFocus
                onClicked: card.loadPhoto()
            }
            Button {
                visible: card.step === "photo"
                text: qsTr("Use the blueprint")
                focusPolicy: Qt.NoFocus
                onClicked: card.useBlueprint()
            }
            Button {
                visible: card.info !== null && card.info.button !== undefined
                text: card.info && card.info.button ? card.info.button : ""
                focusPolicy: Qt.NoFocus
                onClicked: {
                    if (card.info.kind === "rulerLength")
                        card.canvas.openLengthBox()
                    else
                        card.canvas.pickUp(card.info.kind)
                }
            }
        }
    }
}
