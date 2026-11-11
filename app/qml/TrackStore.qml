pragma Singleton
import QtQuick
import Conestructor
import "logic/commands.mjs" as Commands
import "logic/conefile.mjs" as ConeFile
import "logic/frame.mjs" as Frame
import "logic/postprocess.mjs" as Post

// The track being edited and every change to it. The track is plain data (see logic/commands.mjs); every edit runs
// as a command through the undo stack, and the canvas and panels draw from `track`. Nothing drawn keeps a copy.
// It also knows which file the track came from and whether it has changed since.
QtObject {
    id: store

    property var track: Commands.emptyTrack()
    readonly property real mpp: track.photo.metresPerPixel
    readonly property int elementCount: track.elements.length
    readonly property var frame: Frame.makeFrame(track.targets.origin, track.targets.direction, mpp)

    // The open file ("" until first saved), the track's name, and whether it differs from what was last saved or
    // opened (undoing back to that state clears it).
    property string filePath: ""
    readonly property string name: filePath !== "" ? TrackFile.baseName(filePath) : qsTr("Untitled")
    readonly property string trackText: JSON.stringify(track)
    property string savedText: JSON.stringify(Commands.emptyTrack())
    readonly property bool dirty: trackText !== savedText

    // "" (nothing), an element id, "ruler", "origin" or "direction".
    property string selectedId: ""
    readonly property var selectedElement: {
        const id = selectedId
        return track.elements.find(e => e.id === id) || null
    }

    property string message: ""
    property bool previewOn: false
    property var preview: null
    property bool showCones: true
    property bool showRoute: true

    property bool canUndo: false
    property bool canRedo: false
    property string undoLabel: ""
    property string redoLabel: ""

    property var stack: new Commands.UndoStack()
    property int gestureSerial: 0

    // Something the person needs to fix; `target` says what "Show me" pans to ({ kind, id? }) or is null.
    signal problem(string message, var target)
    signal problemsCleared()

    function setTrack(t) {
        track = t
        if (selectedId !== "" && !exists(selectedId))
            selectedId = ""
        syncStack()
        if (previewOn)
            refreshPreview()
    }

    function syncStack() {
        canUndo = stack.canUndo()
        canRedo = stack.canRedo()
        undoLabel = stack.undoLabel()
        redoLabel = stack.redoLabel()
    }

    function run(name, args) {
        const after = Commands.run(stack, track, name, args || {})
        if (after !== track)
            setTrack(after)
    }

    function undo() {
        const t = stack.undo()
        if (t)
            setTrack(t)
        syncStack()
    }

    function redo() {
        const t = stack.redo()
        if (t)
            setTrack(t)
        syncStack()
    }

    // Ends the current step: the next change, even to the same field, is a new undo step.
    function seal() {
        stack.seal()
    }

    function loadTrack(t) {
        stack.clear()
        previewOn = false
        preview = null
        selectedId = ""
        setTrack(t)
    }

    function markSaved() {
        savedText = trackText
    }

    function photoRef() {
        return track.photo.kind === "image" && track.photo.ref !== null ? track.photo.ref : -1
    }

    function documentText(trackName) {
        return ConeFile.documentText(track, { name: trackName, app: "Conestructor " + AppInfo.version,
                                              saved: ConeFile.timestamp(new Date()) })
    }

    // A fresh untitled track with no undo history; photos from before are forgotten.
    function newTrack() {
        PhotoStore.clear(-1)
        filePath = ""
        loadTrack(Commands.emptyTrack())
        markSaved()
        problemsCleared()
    }

    // Writes the track to `path` (a .cone file); false after a banner says why not.
    function saveTo(path) {
        const error = TrackFile.save(path, documentText(TrackFile.baseName(path)), photoRef())
        if (error !== "") {
            report(error, null)
            return false
        }
        filePath = path
        markSaved()
        Settings.addRecentFile(path)
        TrackFile.deleteBackup()
        message = qsTr("Saved %1").arg(path)
        return true
    }

    // Reads a track file: { track, warning, photoRef }, or null after a banner says why not (this track is untouched).
    function readTrack(path) {
        const r = TrackFile.open(path)
        if (r.error) {
            if (r.error === "missing")
                Settings.removeRecentFile(path)
            report(r.error === "notJson" ? ConeFile.MESSAGES.notTrack : r.message, null)
            return null
        }
        let doc = null
        try {
            doc = JSON.parse(r.text)
        } catch (e) {
            doc = null
        }
        const result = ConeFile.fromDocument(doc, r.photoRef)
        if (result.error) {
            if (r.photoRef >= 0)
                PhotoStore.remove(r.photoRef)
            report(result.error, null)
            return null
        }
        return { track: result.track, warning: result.warning, photoRef: r.photoRef }
    }

    // Puts a track read by readTrack in place of this one, with no undo history.
    function show(read) {
        PhotoStore.clear(read.photoRef)
        loadTrack(read.track)
        if (read.warning !== "")
            report(read.warning, null)
        else
            problemsCleared()
    }

    function openPath(path) {
        const read = readTrack(path)
        if (!read)
            return false
        filePath = path
        show(read)
        markSaved()
        Settings.addRecentFile(path)
        message = qsTr("Opened %1").arg(path)
        return true
    }

    // A key shared by every step of one drag, so the drag undoes as one step.
    function newGestureKey() {
        gestureSerial += 1
        return "gesture" + gestureSerial
    }

    function exists(id) {
        if (id === "ruler")
            return track.ruler !== null
        if (id === "origin" || id === "direction")
            return track.targets[id] !== null
        return track.elements.some(e => e.id === id)
    }

    function element(id) {
        return track.elements.find(e => e.id === id) || null
    }

    function select(id) {
        if (selectedId === id)
            return
        stack.seal()
        selectedId = id
    }

    function selectLast() {
        const list = track.elements
        if (list.length > 0)
            select(list[list.length - 1].id)
    }

    function deleteSelected() {
        const id = selectedId
        if (id === "")
            return
        if (id === "ruler") {
            if (elementCount > 0) {
                report(qsTr("Delete the track elements before the ruler: their sizes are measured with it."), null)
                return
            }
            run("removeRuler")
        } else if (id === "origin" || id === "direction") {
            run("setTarget", { which: id, point: null })
        } else {
            run("remove", { id: id })
        }
        stack.seal()
    }

    function duplicateSelected() {
        if (!selectedElement)
            return
        run("duplicate", { id: selectedElement.id })
        stack.seal()
        selectLast()
    }

    function report(text, target) {
        problem(text, target || null)
    }

    // The track's cones, or null after reporting what is missing.
    function processed() {
        const result = Post.run(track)
        if (result.error) {
            report(result.error.message, result.error.target)
            return null
        }
        problemsCleared()
        return result
    }

    function placeCones() {
        const result = processed()
        preview = result
        previewOn = result !== null
        if (result)
            message = qsTr("Placed %1 cones").arg(result.cones.length)
    }

    function refreshPreview() {
        const result = Post.run(track)
        if (result.error) {
            previewOn = false
            preview = null
            report(result.error.message, result.error.target)
        } else {
            preview = result
        }
    }

    function clearPreview() {
        previewOn = false
        preview = null
    }
}
