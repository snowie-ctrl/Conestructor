import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/elements.mjs" as Elements
import "logic/frame.mjs" as Frame
import "logic/selection.mjs" as Selection
import "logic/units.mjs" as Units

// The settings of whatever is selected. For an element: where it is and which way it points in the export frame
// (once both targets exist), then its settings in plain words.
ScrollView {
    id: panel
    clip: true
    contentWidth: availableWidth

    readonly property var el: TrackStore.selectedElement
    readonly property var many: TrackStore.selectedElements.length > 1 ? TrackStore.selectedElements : []
    readonly property var placed: TrackStore.previewOn && TrackStore.preview ? TrackStore.preview.canvasCones : []
    readonly property var pickedCones: TrackStore.coneSelection.map(i => placed[i]).filter(c => c !== undefined)
    readonly property var cone: pickedCones.length === 1 ? pickedCones[0] : null
    readonly property string kind: cone ? "cone" : pickedCones.length > 1 ? "cones"
                                   : el ? "element" : many.length > 1 ? "many" : TrackStore.selectedId

    readonly property var coneFrame: cone && TrackStore.frame ? Frame.toFrame(TrackStore.frame, cone) : null

    function moveConeTo(x, y) {
        const index = TrackStore.coneSelection[0]
        const p = Frame.fromFrame(TrackStore.frame, { x: x, y: y })
        TrackStore.run("moveCone", { index: index, x: p.x, y: p.y, mergeKey: "cone-position:" + index })
    }

    function elementName(id) {
        const e = TrackStore.element(id)
        return e ? Elements.NAMES[e.type] : ""
    }
    readonly property var shared: Selection.sharedProps(many)
    // Changes only when the selection or the set of shared settings changes, so fields are not rebuilt while typing.
    readonly property string sharedKey: many.map(e => e.id).join(",") + ":" + shared.map(s => s.def.key).join(",")
    property var sharedDefs: []
    onSharedKeyChanged: sharedDefs = shared.map(s => s.def)

    function sharedEntry(key) {
        return shared.find(s => s.def.key === key) || null
    }
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
            text: panel.kind === "cone" ? qsTr("Cone %1 of %2").arg(panel.cone.index + 1).arg(panel.placed.length)
                  : panel.kind === "cones" ? qsTr("%1 cones selected").arg(panel.pickedCones.length)
                  : panel.kind === "element" ? Elements.NAMES[panel.el.type]
                  : panel.kind === "many" ? qsTr("%1 elements selected").arg(panel.many.length)
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
            objectName: "lockedPanelNote"
            visible: TrackStore.locked && panel.kind !== "" && panel.kind !== "cone" && panel.kind !== "cones"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Clear preview to change the track.")
            color: "#ffb74d"
        }

        Label {
            visible: panel.framePosition !== null
            text: panel.framePosition ? qsTr("Position   x %1 · y %2").arg(Units.format(panel.framePosition.x, Settings.units))
                                                                     .arg(Units.format(panel.framePosition.y, Settings.units)) : ""
            color: "#b0b0b0"
        }
        // Degrees counter-clockwise from the Origin -> Direction axis. Typing turns the element's whole joined chain.
        PropField {
            enabled: !TrackStore.locked
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
                enabled: !TrackStore.locked
                required property var modelData
                def: modelData
                value: panel.el ? panel.el.props[modelData.key] : 0
                onEdited: (v) => {
                    const once = modelData.kind === "choice" || modelData.kind === "notch"   // read first: it can rebuild this field
                    TrackStore.run("setProp", { id: panel.el.id, key: modelData.key, value: v })
                    if (once)
                        TrackStore.seal()
                }
                onFinished: TrackStore.seal()
            }
        }

        Repeater {
            model: panel.sharedDefs
            PropField {
                enabled: !TrackStore.locked
                required property var modelData
                readonly property var entry: panel.sharedEntry(modelData.key)
                def: modelData
                mixed: entry !== null && entry.mixed
                value: entry && !entry.mixed ? entry.value : (modelData.kind === "choice" ? "" : 0)
                onEdited: (v) => {
                    const once = modelData.kind === "choice" || modelData.kind === "notch"   // read first: it can rebuild this field
                    TrackStore.run("setProps", { ids: panel.many.map(e => e.id), key: modelData.key, value: v })
                    if (once)
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
            enabled: !TrackStore.locked
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

        Label {
            visible: panel.kind === "cone"
            text: !panel.cone ? "" : panel.cone.element === null ? qsTr("Added by hand")
                  : qsTr("From %1 %2").arg(panel.elementName(panel.cone.element)).arg(panel.cone.element)
            color: "#b0b0b0"
        }
        PropField {
            visible: panel.coneFrame !== null
            def: ({ key: "coneX", label: qsTr("Position x"), kind: "length", min: -10000, max: 10000 })
            value: panel.coneFrame ? panel.coneFrame.x : 0
            onEdited: (v) => panel.moveConeTo(v, panel.coneFrame.y)
            onFinished: TrackStore.seal()
        }
        PropField {
            visible: panel.coneFrame !== null
            def: ({ key: "coneY", label: qsTr("Position y"), kind: "length", min: -10000, max: 10000 })
            value: panel.coneFrame ? panel.coneFrame.y : 0
            onEdited: (v) => panel.moveConeTo(panel.coneFrame.x, v)
            onFinished: TrackStore.seal()
        }
        // Where a leaning cone points: degrees counter-clockwise from the Origin -> Direction axis.
        PropField {
            visible: panel.coneFrame !== null && panel.cone.type === "leaning"
            def: ({ key: "conePointing", label: qsTr("Pointing"), kind: "angle", min: -360, max: 360 })
            value: panel.coneFrame ? Frame.headingToFrame(TrackStore.frame, panel.cone.heading) : 0
            stepSize: 1
            bigStep: 15
            onEdited: (v) => TrackStore.run("pointCone", { index: TrackStore.coneSelection[0],
                                                           heading: Frame.headingFromFrame(TrackStore.frame, v),
                                                           mergeKey: "cone-pointing:" + TrackStore.coneSelection[0] })
            onFinished: TrackStore.seal()
        }
        PropField {
            readonly property var types: panel.pickedCones.map(c => c.type)
            visible: panel.kind === "cone" || panel.kind === "cones"
            def: ({ key: "coneType", label: qsTr("Type"), kind: "choice", choices: ["standing", "leaning"],
                    labels: [qsTr("Standing"), qsTr("Leaning")] })
            mixed: types.some(t => t !== types[0])
            value: types.length > 0 ? types[0] : ""
            onEdited: (v) => TrackStore.setConeTypes(v)
        }
        Button {
            visible: panel.kind === "cone" || panel.kind === "cones"
            text: panel.kind === "cones" ? qsTr("Delete %1 cones").arg(panel.pickedCones.length) : qsTr("Delete cone")
            onClicked: TrackStore.deleteSelected()
        }
    }
}
