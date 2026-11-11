import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/elements.mjs" as Elements
import "logic/frame.mjs" as Frame
import "logic/units.mjs" as Units

// The settings of whatever is selected. For an element: where it is and which way it points in the export frame
// (once both targets exist), then its settings in plain words.
ScrollView {
    id: panel
    clip: true
    contentWidth: availableWidth

    readonly property var el: TrackStore.selectedElement
    readonly property string kind: el ? "element" : TrackStore.selectedId
    // Changes only when the selection or the set of visible settings changes, so fields are not rebuilt while typing.
    readonly property string fieldsKey: el ? el.id + ":" + Elements.propList(el.type, el.props).map(p => p.key).join(",") : ""
    property var defs: []
    onFieldsKeyChanged: defs = el ? Elements.propList(el.type, el.props) : []

    readonly property var framePosition: el && TrackStore.frame ? Frame.toFrame(TrackStore.frame, el) : null
    readonly property real frameRotation: el && TrackStore.frame ? Frame.headingToFrame(TrackStore.frame, el.rotation) : 0

    ColumnLayout {
        width: panel.availableWidth
        spacing: 8

        Label {
            text: panel.kind === "element" ? Elements.NAMES[panel.el.type]
                  : panel.kind === "ruler" ? qsTr("Ruler")
                  : panel.kind === "origin" ? qsTr("Origin target")
                  : panel.kind === "direction" ? qsTr("Direction target")
                  : qsTr("Nothing selected")
            font.bold: true
            font.pixelSize: 16
            color: "#ffffff"
        }
        Label {
            visible: panel.kind === ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Click something on the canvas to change it.")
            color: "#b0b0b0"
        }

        Label {
            visible: panel.framePosition !== null
            text: panel.framePosition ? qsTr("Position   x %1 · y %2").arg(Units.format(panel.framePosition.x, Settings.units))
                                                                     .arg(Units.format(panel.framePosition.y, Settings.units)) : ""
            color: "#b0b0b0"
        }
        // Degrees counter-clockwise from the Origin -> Direction axis. Typing turns the element's whole joined chain.
        PropField {
            visible: panel.framePosition !== null
            def: ({ key: "rotation", label: qsTr("Rotation"), kind: "angle", min: -360, max: 360 })
            value: panel.frameRotation
            stepSize: 1
            bigStep: 15
            onEdited: (v) => TrackStore.run("rotateChain", { id: panel.el.id,
                                                             rotation: Frame.headingFromFrame(TrackStore.frame, v),
                                                             mergeKey: "rotation:" + panel.el.id })
            onFinished: TrackStore.seal()
        }

        Repeater {
            model: panel.defs
            PropField {
                required property var modelData
                def: modelData
                value: panel.el ? panel.el.props[modelData.key] : 0
                onEdited: (v) => {
                    const choice = modelData.kind === "choice"   // read first: changing a choice can rebuild this field
                    TrackStore.run("setProp", { id: panel.el.id, key: modelData.key, value: v })
                    if (choice)
                        TrackStore.seal()
                }
                onFinished: TrackStore.seal()
            }
        }

        Label {
            visible: panel.kind === "ruler"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Drag the ruler's ends onto something you know the length of, such as a parking space, then type its real length.")
            color: "#b0b0b0"
        }
        PropField {
            visible: panel.kind === "ruler"
            def: ({ key: "realLength", label: qsTr("Real length"), kind: "length", min: 0.1, max: 1000 })
            value: TrackStore.track.ruler ? TrackStore.track.ruler.realLength : 0
            emptyWhenZero: true
            onEdited: (v) => {
                const r = TrackStore.track.ruler
                TrackStore.run("setRuler", { a: r.a, b: r.b, realLength: v, mergeKey: "ruler-length" })
            }
            onFinished: TrackStore.seal()
        }

        Label {
            visible: panel.kind === "origin" || panel.kind === "direction"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: panel.kind === "origin" ? qsTr("x and y are measured from here. Drag it to move it.")
                                          : qsTr("x points from Origin toward here. Drag it to move it.")
            color: "#b0b0b0"
        }
        Label {
            visible: panel.kind === "direction" && TrackStore.frame !== null
            text: TrackStore.frame ? qsTr("From Origin: %1").arg(Units.format(TrackStore.frame.distance, Settings.units)) : ""
            color: "#b0b0b0"
        }
    }
}
