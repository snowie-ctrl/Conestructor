import QtQuick
import QtQuick.Controls
import QtQml.Models
import QtQuick.Dialogs
import QtQuick.Layouts
import Conestructor
import "logic/demo.mjs" as Demo

ApplicationWindow {
    id: window
    width: 1600
    height: 960
    visible: true
    title: "Conestructor " + AppInfo.shortVersion + " — Untitled"
    color: "#1f1f1f"

    palette.window: "#262626"
    palette.windowText: "#e8e8e8"
    palette.base: "#1b1b1b"
    palette.text: "#f0f0f0"
    palette.button: "#333333"
    palette.buttonText: "#f0f0f0"
    palette.highlight: "#2f6fd6"
    palette.highlightedText: "#ffffff"
    palette.toolTipBase: "#333333"
    palette.toolTipText: "#f0f0f0"

    function newTrack() {
        TrackStore.run("newTrack")
        TrackStore.seal()
        TrackStore.clearPreview()
        canvasView.fitPending = true
        canvasView.tryFit()
    }

    function setBackground(path) {
        TrackStore.run("setPhoto", { path: path })
        TrackStore.seal()
    }

    function backgroundName(name) {
        return ({ duckPondBirdeye: qsTr("Duck pond"), riverwindBirdeye: qsTr("Riverwind") })[name] || name
    }

    // For screenshots (CONESTRUCTOR_DEMO) and the smoke test.
    function loadDemo(withCones) {
        TrackStore.loadTrack(Demo.demoTrack())
        canvasView.fitPending = true
        canvasView.tryFit()
        if (withCones)
            TrackStore.placeCones()
    }

    function conesPlaced() {
        return TrackStore.previewOn && TrackStore.preview ? TrackStore.preview.cones.length : 0
    }

    menuBar: MenuBar {
        Menu {
            id: fileMenu
            title: qsTr("&File")
            Action { text: qsTr("&New"); shortcut: StandardKey.New; onTriggered: window.newTrack() }
            Action { text: qsTr("Load lot photo…"); onTriggered: photoDialog.open() }
            MenuSeparator {}
            Action { text: qsTr("&Quit"); shortcut: StandardKey.Quit; onTriggered: Qt.quit() }
        }
        Menu {
            id: editMenu
            title: qsTr("&Edit")
            Action {
                text: TrackStore.canUndo ? qsTr("Undo %1").arg(TrackStore.undoLabel) : qsTr("Undo")
                enabled: TrackStore.canUndo
                shortcut: StandardKey.Undo
                onTriggered: TrackStore.undo()
            }
            Action {
                text: TrackStore.canRedo ? qsTr("Redo %1").arg(TrackStore.redoLabel) : qsTr("Redo")
                enabled: TrackStore.canRedo
                shortcut: "Ctrl+Y"
                onTriggered: TrackStore.redo()
            }
            MenuSeparator {}
            Action {
                text: qsTr("Duplicate")
                shortcut: "Ctrl+D"
                enabled: TrackStore.selectedElement !== null
                onTriggered: TrackStore.duplicateSelected()
            }
            Action {
                text: qsTr("Delete")
                shortcut: StandardKey.Delete
                enabled: TrackStore.selectedId !== ""
                onTriggered: TrackStore.deleteSelected()
            }
        }
        Menu {
            id: viewMenu
            title: qsTr("&View")
            Action { text: qsTr("Fit to photo"); shortcut: "F"; onTriggered: canvasView.fitToPhoto() }
            Action {
                text: qsTr("Show cones")
                shortcut: "C"
                checkable: true
                checked: TrackStore.showCones
                onTriggered: TrackStore.showCones = checked
            }
            Action {
                text: qsTr("Show route line")
                shortcut: "R"
                checkable: true
                checked: TrackStore.showRoute
                onTriggered: TrackStore.showRoute = checked
            }
            Menu {
                id: backgroundsMenu
                title: qsTr("Backgrounds")
                MenuItem { text: qsTr("Blueprint"); onTriggered: window.setBackground("") }
                Instantiator {
                    model: AppInfo.localBackgrounds
                    delegate: MenuItem {
                        required property string modelData
                        text: window.backgroundName(modelData)
                        onTriggered: window.setBackground("qrc:/qt/qml/Conestructor/assets/images/" + modelData + ".png")
                    }
                    onObjectAdded: (index, object) => backgroundsMenu.insertItem(index + 1, object)
                    onObjectRemoved: (index, object) => backgroundsMenu.removeItem(object)
                }
            }
        }
        Menu {
            title: qsTr("&Process")
            Action { text: qsTr("Place cones"); onTriggered: TrackStore.placeCones() }
            Action { text: qsTr("Clear preview"); enabled: TrackStore.previewOn; onTriggered: TrackStore.clearPreview() }
        }
    }

    // The Backgrounds menu exists only when this build bundled local lot pictures.
    Component.onCompleted: {
        if (AppInfo.localBackgrounds.length === 0)
            viewMenu.removeMenu(backgroundsMenu)
    }

    Shortcut { sequences: ["Ctrl+Shift+Z"]; onActivated: TrackStore.redo() }
    Shortcut { sequences: ["Backspace"]; onActivated: TrackStore.deleteSelected() }

    Connections {
        target: TrackStore
        function onProblem(message, target) { banner.show(message, target) }
        function onProblemsCleared() { banner.hide() }
    }
    Connections {
        target: Settings
        function onSaveFailed(message) { banner.show(message, null) }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        CanvasView {
            id: canvasView
            objectName: "canvasView"
            Layout.fillWidth: true
            Layout.fillHeight: true

            ErrorBanner {
                id: banner
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                onShowMe: (target) => canvasView.showTarget(target)
            }
        }

        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: "#262626"

            ColumnLayout {
                id: sideColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                ElementPalette {
                    canvas: canvasView
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    footer: StatusBar { canvas: canvasView }

    FileDialog {
        id: photoDialog
        title: qsTr("Load lot photo")
        nameFilters: [qsTr("Photos (*.png *.jpg *.jpeg)")]
        onAccepted: probe.check(selectedFile)
    }

    // Tries a chosen photo before it replaces the background, so one that fails to load leaves the old one.
    Image {
        id: probe
        visible: false
        asynchronous: false
        sourceSize: Qt.size(64, 64)
        property string pending: ""

        function check(url) {
            source = ""
            pending = url.toString()
            source = url
        }

        onStatusChanged: {
            if (pending === "" || (status !== Image.Ready && status !== Image.Error))
                return
            if (status === Image.Ready)
                window.setBackground(pending)
            else
                TrackStore.report(qsTr("Could not open that photo. The background is unchanged."), null)
            pending = ""
            Qt.callLater(() => { probe.source = "" })
        }
    }
}
