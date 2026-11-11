import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/elements.mjs" as Elements
import "logic/setup.mjs" as Setup

// The track tiles dragged onto the canvas. They unlock once setup is done (SetupChecklist holds the ruler and
// target tiles).
GridLayout {
    id: grid      // not "palette": inside each tile that name means the tile's own palette property
    required property CanvasView canvas

    columns: 2
    rowSpacing: 8
    columnSpacing: 8

    readonly property bool unlocked: Setup.status(TrackStore.track).done
    readonly property var tiles: Elements.TYPES.map(type => ({ kind: type, name: Elements.NAMES[type],
                                                               colour: Elements.COLOURS[type], tip: Elements.TIPS[type] }))

    Repeater {
        model: grid.tiles
        delegate: PaletteTile {
            required property var modelData
            canvas: grid.canvas
            kind: modelData.kind
            name: modelData.name
            colour: modelData.colour
            tip: modelData.tip
            usable: grid.unlocked
            lockedTip: qsTr("Finish setup first.")
        }
    }
}
