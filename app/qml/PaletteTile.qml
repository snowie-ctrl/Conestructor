import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor

// One tile in the side panel: click it to pick it up, or drag it onto the canvas. A track element, the ruler or a target.
Rectangle {
    id: tile
    required property CanvasView canvas
    required property string kind
    required property string name
    required property color colour
    required property string tip
    property bool usable: true
    property string lockedTip: ""

    Layout.fillWidth: true
    Layout.preferredHeight: 52
    implicitWidth: 110
    implicitHeight: 52
    radius: 6
    color: area.containsMouse && usable ? "#3a3a3a" : "#303030"
    opacity: usable ? 1 : 0.4
    border.color: tile.canvas.placingBy === "click" && tile.canvas.placingKind === tile.kind ? "#2f6fd6" : "transparent"
    border.width: 2

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 8
        width: 6
        radius: 3
        color: tile.colour
    }
    Label {
        anchors.centerIn: parent
        text: tile.name
        color: "#f0f0f0"
    }

    ToolTip.visible: area.containsMouse
    ToolTip.delay: 400
    ToolTip.text: !usable && lockedTip !== "" ? lockedTip : tip

    // A press that moves less than a drag's distance before release is a click: it picks the tile up (the next canvas
    // click puts it down). Further is a drag onto the canvas, as before.
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        property point pressedAt
        property bool dragging: false
        onPressed: (mouse) => {
            if (!tile.usable) {
                mouse.accepted = false
                return
            }
            pressedAt = Qt.point(mouse.x, mouse.y)
            dragging = false
        }
        onPositionChanged: (mouse) => {
            if (!pressed)
                return
            if (!dragging) {
                if (Math.hypot(mouse.x - pressedAt.x, mouse.y - pressedAt.y) < Qt.styleHints.startDragDistance)
                    return
                dragging = true
                tile.canvas.beginPlacing(tile.kind)
            }
            const p = mapToItem(tile.canvas, mouse.x, mouse.y)
            tile.canvas.updatePlacing(p.x, p.y, (mouse.modifiers & Qt.ControlModifier) !== 0)
        }
        onReleased: (mouse) => {
            if (!dragging) {
                tile.canvas.clickTile(tile.kind)
                return
            }
            dragging = false
            const p = mapToItem(tile.canvas, mouse.x, mouse.y)
            tile.canvas.finishPlacing(p.x, p.y)
        }
    }
}
