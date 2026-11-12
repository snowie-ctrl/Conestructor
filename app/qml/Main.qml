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
    title: "Conestructor " + AppInfo.shortVersion + " — " + TrackStore.name + (TrackStore.dirty ? "*" : "")
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

    // What waits on the unsaved-changes question: it runs once the track is saved or let go.
    property var pendingAction: null
    // Set once the person has answered for the track, so closing does not ask twice.
    property bool closing: false
    // False while a backup from an earlier session waits on the Restore question: closing then keeps it.
    property bool backupAnswered: true

    function fitSoon() {
        canvasView.fitPending = true
        canvasView.tryFit()
    }

    // Runs `action` now when nothing is unsaved; otherwise asks first (Save, Don't save, Cancel).
    function whenSaved(action) {
        if (!TrackStore.dirty) {
            action()
            return
        }
        pendingAction = action
        unsavedDialog.open()
    }

    function takePending() {
        const action = pendingAction
        pendingAction = null
        return action || function() {}
    }

    // Saves to the open file, or asks where first; `then` runs once it is saved.
    function save(then) {
        if (TrackStore.filePath === "") {
            saveAs(then)
            return
        }
        if (TrackStore.saveTo(TrackStore.filePath) && then)
            then()
    }

    // Where Save As starts: beside the open track, with its name filled in. An Untitled track starts wherever the
    // dialog was last (null).
    function saveAsStart() {
        if (TrackStore.filePath === "")
            return null
        return { folder: TrackFile.folderUrl(TrackStore.filePath), file: TrackFile.fileUrl(TrackStore.filePath) }
    }

    function saveAs(then) {
        saveDialog.afterSave = then || null
        const start = saveAsStart()
        if (start) {
            saveDialog.currentFolder = start.folder
            saveDialog.selectedFile = start.file
        }
        saveDialog.open()
    }

    function newTrack() {
        whenSaved(() => {
            TrackStore.newTrack()
            window.fitSoon()
        })
    }

    function openTrack(path) {
        if (TrackStore.openPath(path))
            fitSoon()
    }

    function chooseTrack() {
        whenSaved(() => openDialog.open())
    }

    function openRecent(path) {
        whenSaved(() => window.openTrack(path))
    }

    onClosing: (close) => {
        if (closing || !TrackStore.dirty) {
            if (backupAnswered)
                TrackStore.deleteBackup()
            return
        }
        close.accepted = false
        whenSaved(() => {
            window.closing = true
            TrackStore.deleteBackup()
            window.close()
        })
    }

    // Loads a lot photo (a file dialog's URL, a path or a qrc: URL) as one undo step; a banner if it can't be read.
    function loadPhoto(url) {
        const r = PhotoStore.load(url.toString())
        if (r.error) {
            TrackStore.report(r.error, null)
            return
        }
        TrackStore.run("setPhoto", { kind: "image", ref: r.ref })
        TrackStore.seal()
    }

    function useBlueprint() {
        TrackStore.run("setPhoto", { kind: "blueprint" })
        TrackStore.seal()
    }

    function backgroundName(name) {
        return ({ duckPondBirdeye: qsTr("Duck pond"), riverwindBirdeye: qsTr("Riverwind") })[name] || name
    }

    // For screenshots (CONESTRUCTOR_DEMO) and the tests: the example track, counted as saved.
    function loadDemo(withCones) {
        TrackStore.newTrack()
        TrackStore.loadTrack(Demo.demoTrack())
        TrackStore.markSaved()
        fitSoon()
        if (withCones)
            TrackStore.placeCones()
    }

    // Called once by main.cpp when the window opens: offers a backup left by a crash, then opens `file` (the track
    // named on the command line, or "").
    function start(file) {
        file = TrackFile.absolutePath(file)
        const backup = TrackFile.findBackup()
        if (backup.path) {
            backupAnswered = false
            restoreDialog.backup = backup
            restoreDialog.file = file
            restoreDialog.open()
        } else if (file !== "") {
            openTrack(file)
        }
    }

    function afterRestoreQuestion(file) {
        if (file !== "")
            whenSaved(() => window.openTrack(file))
    }

    // A file dropped on the window: a .cone opens, a PNG or JPG becomes the lot photo.
    function dropped(url) {
        const path = TrackFile.toLocalPath(url)
        const lower = path.toLowerCase()
        if (lower.endsWith(".cone"))
            whenSaved(() => window.openTrack(path))
        else if (/\.(png|jpe?g)$/.test(lower))
            loadPhoto(url)
        else
            TrackStore.report(qsTr("Drop a .cone track or a PNG or JPG photo."), null)
    }

    // Every two minutes: backs up unsaved changes that are not backed up yet. A failed write says nothing (it is a
    // safety net) and is tried again next time.
    function backUp() {
        if (!TrackStore.dirty || TrackStore.trackText === TrackStore.backedUpText)
            return
        const error = TrackFile.writeBackup(TrackStore.documentText(TrackStore.name), TrackStore.photoRef(),
                                            TrackStore.filePath, TrackStore.name)
        if (error === "")
            TrackStore.backedUpText = TrackStore.trackText
    }

    Timer {
        interval: 120000
        repeat: true
        running: true
        onTriggered: window.backUp()
    }

    function conesPlaced() {
        return TrackStore.previewOn && TrackStore.preview ? TrackStore.preview.cones.length : 0
    }

    // Runs `action` at once, or after asking to clear the touch-ups when there are some (Clear preview, Place cones).
    function whenUntouched(action) {
        if (!TrackStore.locked) {
            action()
            return
        }
        touchUpsDialog.action = action
        touchUpsDialog.open()
    }

    // Process › Place cones and the Cones box's button.
    function placeCones() {
        whenUntouched(() => TrackStore.placeCones())
    }

    function clearPreview() {
        whenUntouched(() => TrackStore.clearPreview())
    }

    menuBar: MenuBar {
        Menu {
            id: fileMenu
            title: qsTr("&File")
            Action { text: qsTr("&New"); shortcut: StandardKey.New; onTriggered: window.newTrack() }
            Action { text: qsTr("&Open…"); shortcut: StandardKey.Open; onTriggered: window.chooseTrack() }
            Menu {
                id: recentMenu
                title: qsTr("Open &Recent")
                enabled: Settings.recentFiles.length > 0
                Instantiator {
                    model: Settings.recentFiles
                    delegate: MenuItem {
                        required property string modelData
                        text: modelData
                        onTriggered: window.openRecent(modelData)
                    }
                    onObjectAdded: (index, object) => recentMenu.insertItem(index, object)
                    onObjectRemoved: (index, object) => recentMenu.removeItem(object)
                }
                MenuSeparator {}
                MenuItem { text: qsTr("Clear list"); onTriggered: Settings.clearRecentFiles() }
            }
            Action { text: qsTr("&Save"); shortcut: StandardKey.Save; onTriggered: window.save(null) }
            Action { text: qsTr("Save &As…"); shortcut: "Ctrl+Shift+S"; onTriggered: window.saveAs(null) }
            MenuSeparator {}
            Action { text: qsTr("Load lot photo…"); onTriggered: photoDialog.open() }
            MenuSeparator {}
            Action { text: qsTr("&Quit"); shortcut: StandardKey.Quit; onTriggered: window.close() }
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
                enabled: TrackStore.selectedElements.length > 0
                onTriggered: TrackStore.duplicateSelected()
            }
            Action {
                text: qsTr("Delete")
                shortcut: StandardKey.Delete
                enabled: TrackStore.selection.length > 0 || TrackStore.coneSelection.length > 0
                onTriggered: TrackStore.deleteSelected()
            }
            Action {
                text: qsTr("Reverse direction")
                enabled: TrackStore.selectedElements.length > 0
                onTriggered: TrackStore.reverseSelected()
            }
            MenuSeparator {}
            Action { text: qsTr("Preferences…"); shortcut: "Ctrl+,"; onTriggered: preferences.open() }
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
                MenuItem { text: qsTr("Blueprint"); onTriggered: window.useBlueprint() }
                Instantiator {
                    model: AppInfo.localBackgrounds
                    delegate: MenuItem {
                        required property string modelData
                        text: window.backgroundName(modelData)
                        onTriggered: window.loadPhoto("qrc:/qt/qml/Conestructor/assets/images/" + modelData + ".png")
                    }
                    onObjectAdded: (index, object) => backgroundsMenu.insertItem(index + 1, object)
                    onObjectRemoved: (index, object) => backgroundsMenu.removeItem(object)
                }
            }
        }
        Menu {
            title: qsTr("&Process")
            Action { text: qsTr("Place cones"); onTriggered: window.placeCones() }
            Action { text: qsTr("Add cone"); enabled: canvasView.conesShown; onTriggered: canvasView.addCone() }
            Action { text: qsTr("Clear preview"); enabled: TrackStore.previewOn; onTriggered: window.clearPreview() }
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

            CoachCard {
                id: coach
                canvas: canvasView
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                onLoadPhoto: photoDialog.open()
                onUseBlueprint: window.useBlueprint()
            }

            ErrorBanner {
                id: banner
                anchors.top: coach.visible ? coach.bottom : parent.top
                anchors.topMargin: coach.visible ? 8 : 12
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

                SetupChecklist {
                    objectName: "setupChecklist"
                    canvas: canvasView
                    Layout.fillWidth: true
                    onLoadPhoto: photoDialog.open()
                    onUseBlueprint: window.useBlueprint()
                }

                ElementPalette {
                    canvas: canvasView
                    Layout.fillWidth: true
                }

                ConesBox {
                    Layout.fillWidth: true
                    onPlaceCones: window.placeCones()
                }

                PropertyPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }

    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (drop.hasUrls && drop.urls.length > 0) {
                drop.accept(Qt.CopyAction)
                window.dropped(drop.urls[0])
            }
        }
    }

    footer: StatusBar { canvas: canvasView }

    FileDialog {
        id: photoDialog
        title: qsTr("Load lot photo")
        nameFilters: [qsTr("Photos (*.png *.jpg *.jpeg)")]
        onAccepted: window.loadPhoto(selectedFile)
    }

    FileDialog {
        id: openDialog
        title: qsTr("Open track")
        nameFilters: [qsTr("Conestructor tracks (*.cone)")]
        onAccepted: window.openTrack(TrackFile.toLocalPath(selectedFile))
    }

    FileDialog {
        id: saveDialog
        property var afterSave: null      // runs once saved ("result" is the dialog's own)
        title: qsTr("Save track")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("Conestructor tracks (*.cone)")]
        defaultSuffix: "cone"
        onAccepted: {
            const then = afterSave
            afterSave = null
            if (TrackStore.saveTo(TrackFile.toLocalPath(selectedFile)) && then)
                then()
        }
        onRejected: afterSave = null
    }

    Dialog {
        id: unsavedDialog
        objectName: "unsavedDialog"
        implicitWidth: 420      // fixed: Fusion's Dialog sizing loops with a custom button box
        anchors.centerIn: Overlay.overlay
        modal: true
        title: qsTr("Unsaved changes")
        Label {
            objectName: "unsavedQuestion"
            width: unsavedDialog.availableWidth
            wrapMode: Text.Wrap
            text: qsTr("Save changes to %1?").arg(TrackStore.name)
        }
        footer: DialogButtonBox {
            Button { text: qsTr("Save"); DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole }
            Button { text: qsTr("Don't save"); DialogButtonBox.buttonRole: DialogButtonBox.DestructiveRole }
            Button { text: qsTr("Cancel"); DialogButtonBox.buttonRole: DialogButtonBox.RejectRole }
        }
        onAccepted: window.save(window.takePending())
        onDiscarded: {
            const action = window.takePending()
            unsavedDialog.close()
            TrackStore.deleteBackup()
            action()
        }
        onRejected: window.pendingAction = null
    }

    Dialog {
        id: touchUpsDialog
        objectName: "touchUpsDialog"
        property var action: null
        implicitWidth: 420      // fixed: Fusion's Dialog sizing loops with a custom button box
        anchors.centerIn: Overlay.overlay
        modal: true
        title: qsTr("Touched-up cones")
        Label {
            width: touchUpsDialog.availableWidth
            wrapMode: Text.Wrap
            text: TrackStore.touchUpChanges === 1 ? qsTr("Clear 1 touch-up and unlock the track?")
                  : qsTr("Clear %1 touch-ups and unlock the track?").arg(TrackStore.touchUpChanges)
        }
        footer: DialogButtonBox {
            Button { text: qsTr("Clear"); DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole }
            Button { text: qsTr("Cancel"); DialogButtonBox.buttonRole: DialogButtonBox.RejectRole }
        }
        onAccepted: {
            const run = action
            action = null
            if (run)
                run()
        }
        onRejected: action = null
    }

    Dialog {
        id: restoreDialog
        objectName: "restoreDialog"
        property var backup: ({})
        property string file: ""
        implicitWidth: 460      // fixed: Fusion's Dialog sizing loops with a custom button box
        anchors.centerIn: Overlay.overlay
        modal: true
        closePolicy: Popup.NoAutoClose
        title: qsTr("Restore unsaved work?")
        Label {
            width: restoreDialog.availableWidth
            wrapMode: Text.WordWrap
            text: qsTr("Conestructor closed without saving %1 (backed up at %2). Restore it?")
                  .arg(restoreDialog.backup.name || "").arg(restoreDialog.backup.time || "")
        }
        footer: DialogButtonBox {
            Button { text: qsTr("Restore"); DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole }
            Button { text: qsTr("Discard"); DialogButtonBox.buttonRole: DialogButtonBox.DestructiveRole }
        }
        onAccepted: {
            window.backupAnswered = true
            if (TrackStore.restoreBackup(backup)) {
                window.fitSoon()
            } else {
                TrackStore.deleteBackup()
                TrackStore.report(qsTr("The backup couldn't be read and has been removed."), null)
            }
            window.afterRestoreQuestion(file)
        }
        onDiscarded: {
            window.backupAnswered = true
            restoreDialog.close()
            TrackStore.deleteBackup()
            window.afterRestoreQuestion(file)
        }
    }

    PreferencesDialog { id: preferences }
}
