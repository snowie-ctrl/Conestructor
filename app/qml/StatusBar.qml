import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/frame.mjs" as Frame
import "logic/units.mjs" as Units

// Messages on the left; the cursor's position in the export frame (once both targets exist) and the zoom on the right.
Rectangle {
    id: bar
    required property CanvasView canvas

    implicitHeight: 28
    color: "#181818"

    readonly property var position: {
        const h = canvas.hover
        const f = TrackStore.frame
        return h && f ? Frame.toFrame(f, { x: h.x * TrackStore.mpp, y: h.y * TrackStore.mpp }) : null
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 18

        Label {
            Layout.fillWidth: true
            text: TrackStore.message
            elide: Text.ElideRight
            color: "#d0d0d0"
        }
        Label {
            visible: bar.position !== null
            text: bar.position ? "x " + Units.format(bar.position.x, Settings.units) + " · y "
                                 + Units.format(bar.position.y, Settings.units) : ""
            color: "#d0d0d0"
        }
        Label {
            text: qsTr("Zoom %1%").arg(Math.round(bar.canvas.zoom * 100))
            color: "#d0d0d0"
        }
    }
}
