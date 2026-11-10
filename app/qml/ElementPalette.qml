import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/elements.mjs" as Elements

// Tiles dragged onto the canvas. One ruler and one of each target per track (their tiles grey out once placed);
// track elements wait for the ruler's real length.
GridLayout {
    id: grid      // not "palette": inside each tile that name means the tile's own palette property
    required property CanvasView canvas

    columns: 2
    rowSpacing: 8
    columnSpacing: 8

    readonly property bool rulerReady: TrackStore.mpp > 0
    readonly property var tiles: [
        { kind: "ruler", name: qsTr("Ruler"), colour: "#f5cb42",
          tip: qsTr("Ruler: drag its ends onto something you know the length of, then type that length.") },
        { kind: "origin", name: qsTr("Origin"), colour: "#00ffff", tip: qsTr("Origin target: x and y are measured from here.") },
        { kind: "direction", name: qsTr("Direction"), colour: "#00ffff", tip: qsTr("Direction target: x points from Origin toward it.") },
        { kind: "straight", name: Elements.NAMES.straight, colour: Elements.COLOURS.straight, tip: Elements.TIPS.straight },
        { kind: "slalom", name: Elements.NAMES.slalom, colour: Elements.COLOURS.slalom, tip: Elements.TIPS.slalom },
        { kind: "chicane", name: Elements.NAMES.chicane, colour: Elements.COLOURS.chicane, tip: Elements.TIPS.chicane },
        { kind: "turn", name: Elements.NAMES.turn, colour: Elements.COLOURS.turn, tip: Elements.TIPS.turn }
    ]

    function available(kind) {
        if (kind === "ruler")
            return TrackStore.track.ruler === null
        if (kind === "origin" || kind === "direction")
            return TrackStore.track.targets[kind] === null
        return rulerReady
    }

    Repeater {
        model: grid.tiles
        delegate: Rectangle {
            id: tile
            required property var modelData
            readonly property bool usable: grid.available(modelData.kind)
            readonly property bool isTrack: Elements.TYPES.indexOf(modelData.kind) >= 0

            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 6
            color: area.containsMouse && usable ? "#3a3a3a" : "#303030"
            opacity: usable ? 1 : 0.4

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 8
                width: 6
                radius: 3
                color: tile.modelData.colour
            }
            Label {
                anchors.centerIn: parent
                text: tile.modelData.name
                color: "#f0f0f0"
            }

            ToolTip.visible: area.containsMouse
            ToolTip.delay: 400
            ToolTip.text: !usable && isTrack ? qsTr("Set the ruler first.") : modelData.tip

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                onPressed: (mouse) => {
                    if (!tile.usable) {
                        mouse.accepted = false
                        return
                    }
                    grid.canvas.beginPlacing(tile.modelData.kind)
                }
                onPositionChanged: (mouse) => {
                    if (!pressed)
                        return
                    const p = mapToItem(grid.canvas, mouse.x, mouse.y)
                    grid.canvas.updatePlacing(p.x, p.y, (mouse.modifiers & Qt.ControlModifier) !== 0)
                }
                onReleased: (mouse) => {
                    const p = mapToItem(grid.canvas, mouse.x, mouse.y)
                    grid.canvas.finishPlacing(p.x, p.y)
                }
            }
        }
    }

    Label {
        Layout.columnSpan: 2
        Layout.fillWidth: true
        visible: !grid.rulerReady
        text: qsTr("Set the ruler first.")
        color: "#b0b0b0"
        wrapMode: Text.WordWrap
    }
}
