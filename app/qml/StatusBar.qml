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
            textFormat: Text.PlainText      // may hold a track name from the team
            elide: Text.ElideRight
            color: "#d0d0d0"
        }
        // The cones the track needs against the cones the team owns (Preferences), red when it needs more.
        Label {
            objectName: "coneCount"
            readonly property int owned: Settings.conesOwned
            readonly property bool over: owned > 0 && TrackStore.coneCount > owned
            visible: TrackStore.coneCount >= 0
            text: owned > 0 ? qsTr("Cones %1 / %2").arg(TrackStore.coneCount).arg(owned)
                            : qsTr("%1 cones").arg(TrackStore.coneCount)
            color: over ? "#ff6b6b" : "#d0d0d0"
            font.bold: over
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
