import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/units.mjs" as Units

// Beside a ruler just put down without a length: "Real length", ready for typing in the display units. Enter sets it
// (its own undo step); Esc closes the box and leaves the length unset. It closes for good if the ruler goes.
Rectangle {
    id: box
    objectName: "rulerLengthBox"
    required property CanvasView canvas

    readonly property var ruler: TrackStore.track.ruler
    readonly property var middle: ruler ? canvas.toScreen((ruler.a.x + ruler.b.x) / 2, (ruler.a.y + ruler.b.y) / 2) : null
    property bool bad: false

    visible: canvas.lengthBoxOpen && ruler !== null && !(ruler.realLength > 0)
    width: row.implicitWidth + 16
    height: row.implicitHeight + 12
    radius: 4
    color: "#333333"
    border.color: "#f5cb42"
    x: middle ? middle.x - width / 2 : 0
    y: middle ? middle.y + 16 : 0

    onRulerChanged: if (!ruler) canvas.lengthBoxOpen = false
    onVisibleChanged: {
        if (visible) {
            input.text = ""
            bad = false
            input.forceActiveFocus()
        }
    }

    function apply() {
        const metres = Units.parse(input.text, Settings.units)
        if (isNaN(metres) || !(metres > 0)) {
            bad = true
            return
        }
        const r = ruler
        TrackStore.run("setRuler", { a: r.a, b: r.b, realLength: Math.min(1000, Math.max(0.1, metres)) })
        TrackStore.seal()
        canvas.lengthBoxOpen = false
        canvas.forceActiveFocus()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Label {
            text: qsTr("Real length")
            color: "#f0f0f0"
        }
        TextField {
            id: input
            Layout.preferredWidth: 100
            color: box.bad ? "#ff6b6b" : "#f0f0f0"
            placeholderText: qsTr("Type it here")
            selectByMouse: true
            onTextEdited: box.bad = false
            onAccepted: box.apply()
            Keys.onEscapePressed: {
                box.canvas.lengthBoxOpen = false
                box.canvas.forceActiveFocus()
            }
        }
    }
}
