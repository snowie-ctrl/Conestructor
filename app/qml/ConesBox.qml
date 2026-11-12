import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/density.mjs" as Density
import "logic/setup.mjs" as Setup

// The side panel's Cones box: the track's cone density (five notches; SAE standard is the spacing the app has always
// used), Place cones, and, while touch-ups lock the track, how to unlock it.
ColumnLayout {
    id: box
    signal placeCones()

    spacing: 4
    readonly property bool usable: Setup.status(TrackStore.track).done && !TrackStore.locked

    Label {
        text: qsTr("Cones")
        font.bold: true
        color: "#ffffff"
    }
    // A mouse drag along the slider is one undo step; each arrow-key step is its own.
    Slider {
        objectName: "densitySlider"
        Layout.fillWidth: true
        from: 1
        to: 5
        stepSize: 1
        snapMode: Slider.SnapAlways
        value: TrackStore.density
        enabled: box.usable
        onMoved: TrackStore.run("setDensity", { notch: Math.round(value), mergeKey: pressed ? "density" : "" })
        onPressedChanged: if (!pressed) TrackStore.seal()
    }
    RowLayout {
        Layout.fillWidth: true
        Label {
            text: Density.NAMES[1]
            color: "#909090"
            font.pixelSize: 11
        }
        Label {
            objectName: "densityName"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Density.NAMES[TrackStore.density]
            color: "#f0f0f0"
        }
        Label {
            text: Density.NAMES[5]
            color: "#909090"
            font.pixelSize: 11
        }
    }
    Button {
        Layout.fillWidth: true
        text: qsTr("Place cones")
        onClicked: box.placeCones()
    }
    Label {
        objectName: "lockedNote"
        visible: TrackStore.locked
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("Touched up: %1. The track is locked; Clear preview to change it.")
              .arg(TrackStore.touchUpChanges === 1 ? qsTr("1 change") : qsTr("%1 changes").arg(TrackStore.touchUpChanges))
        color: "#ffb74d"
    }
}
