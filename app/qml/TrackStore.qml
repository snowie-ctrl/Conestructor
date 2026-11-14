pragma Singleton
import QtQuick
import Conestructor
import "logic/commands.mjs" as Commands
import "logic/conefile.mjs" as ConeFile
import "logic/density.mjs" as Density
import "logic/elements.mjs" as Elements
import "logic/frame.mjs" as Frame
import "logic/postprocess.mjs" as Post
import "logic/touchups.mjs" as Touchups

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
    // A track opened from the team has no file until it is saved; its name is the one it was uploaded with.
    property string teamName: ""
    readonly property bool fromTeam: filePath === "" && teamName !== ""
    readonly property string name: filePath !== "" ? TrackFile.baseName(filePath)
                                 : teamName !== "" ? teamName : qsTr("Untitled")
    readonly property string trackText: JSON.stringify(track)
    property string savedText: JSON.stringify(Commands.emptyTrack())
    readonly property bool dirty: trackText !== savedText

    // What is selected: element ids, or one of "ruler", "origin", "direction" on its own.
    property var selection: []
    // The one thing selected, or "" when nothing or several are.
    readonly property string selectedId: selection.length === 1 ? selection[0] : ""
    readonly property var selectedElements: {
        const ids = selection
        return track.elements.filter(e => ids.indexOf(e.id) >= 0)
    }
    // The one element selected, or null.
    readonly property var selectedElement: selection.length === 1 && selectedElements.length === 1 ? selectedElements[0] : null

    // Cones picked for touch-ups: positions in the placed list (preview.canvasCones). Never selected with elements. Dropped
    // when the cones are hidden or cleared, and when the number of touched-up cones changes (see setTrack).
    property var coneSelection: []
    onShowConesChanged: coneSelection = []
    onPreviewOnChanged: if (!previewOn) coneSelection = []

    // Elements driven against the rest of their chain: they show a warning (Reverse direction fixes it).
    readonly property var backwardIds: Post.backwards(track.elements)
    // Elements whose inside edge crosses over itself: they show a warning too (advice only).
    readonly property var foldedIds: track.elements.filter(e => Elements.folds(e)).map(e => e.id)

    // Touch-ups lock the track: only the cones, the photo, New and Open change it until they are cleared (commands.mjs).
    readonly property bool locked: Commands.locked(track)
    readonly property int touchUpChanges: Touchups.changes(track.touchUps)
    readonly property int density: Density.trackNotch(track)

    // How many cones Place cones would put down now (the touched-up list while locked), or -1 while the track cannot be
    // processed. Worked out a quarter of a second after the last change, so a drag does not process the track on every
    // mouse move.
    property int coneCount: -1
    property Timer countTimer: Timer {
        interval: 250
        onTriggered: store.countCones()
    }
    onTrackChanged: countTimer.restart()

    function countCones() {
        const r = locked ? Touchups.result(track) : Post.run(track)
        coneCount = r.error ? -1 : r.cones.length
    }

    // Said whenever something on a locked track is pressed or asked for.
    function lockedNote() {
        message = qsTr("Clear preview to change the track")
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
    // A different track took this one's place (New, Open, Restore, the demo): anything half-done on the canvas stops.
    signal trackReplaced()

    function setTrack(t) {
        // The picked cones are positions in the placed list. They still name the same cones only while the touched-up list
        // keeps its length, and when the first touch-up freezes the very list on show without changing its length (a
        // move, retype or turn). Any other change (a delete, an add, undoing past the first touch-up, or a change to an
        // untouched track, which places its cones again) would make them name other cones.
        const before = track.touchUps
        const after = t.touchUps
        const samePositions = before ? after && after.cones.length === before.cones.length
                            : after && after.cones.length === after.placed
        if (!samePositions && coneSelection.length > 0)
            coneSelection = []
        track = t
        const kept = selection.filter(id => exists(id))
        if (kept.length !== selection.length)
            selection = kept
        syncStack()
        if (locked && !previewOn)
            previewOn = true            // a touched-up track always shows its cones
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

    // The track text last backed up (Main's two-minute timer), so an unchanged track is not written again. Deleting the
    // backup forgets it, so a track still unsaved afterwards is backed up again.
    property string backedUpText: ""

    function deleteBackup() {
        TrackFile.deleteBackup()
        backedUpText = ""
    }

    // Ends the current step: the next change, even to the same field, is a new undo step.
    function seal() {
        stack.seal()
    }

    function loadTrack(t) {
        stack.clear()
        previewOn = false
        preview = null
        selection = []
        coneSelection = []
        setTrack(t)
        trackReplaced()
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
        teamName = ""
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
        teamName = ""
        markSaved()
        Settings.addRecentFile(path)
        deleteBackup()
        message = qsTr("Saved %1").arg(path)
        return true
    }

    // Reads a track file: { track, warning, photoRef }, or null after a banner says why not (this track is untouched).
    function readTrack(path) {
        const r = TrackFile.open(path)
        if (r.error === "missing")
            Settings.removeRecentFile(path)
        return readOpened(r)
    }

    // A track file's contents as TrackFile.open or TeamServer.download gave them ({ text, photoRef, photoError } or
    // { error, message }): { track, warning, photoRef }, or null after a banner says why not.
    function readOpened(r) {
        if (r.error) {
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
        teamName = ""
        show(read)
        markSaved()
        Settings.addRecentFile(path)
        message = qsTr("Opened %1").arg(path)
        return true
    }

    // A track downloaded from the team (`r` from TeamServer.download), under the name it was uploaded with. It has no
    // file until saved, is not unsaved and is not a recent file.
    function openFromTeam(r, trackName) {
        const read = readOpened(r)
        if (!read)
            return false
        filePath = ""
        teamName = trackName
        show(read)
        markSaved()
        message = qsTr("Opened %1 from the team").arg(trackName)
        return true
    }

    // What Upload to team sends the cones of: the touched-up list while locked, otherwise what Place cones would place
    // now ({ cones, canvasCones, targetDistance }); null after a banner says why the track cannot be processed.
    function uploadResult() {
        const result = locked ? Touchups.result(track) : Post.run(track)
        if (result.error) {
            report(result.error.message, result.error.target)
            return null
        }
        return result
    }

    // Opens the autosave backup as unsaved changes to the track it came from (`backup` from TrackFile.findBackup).
    function restoreBackup(backup) {
        const read = readTrack(backup.path)
        if (!read)
            return false
        filePath = backup.trackPath
        // A track from the team has no file; the backup notes keep its name (an Untitled one is backed up as Untitled).
        teamName = backup.trackPath === "" && backup.name !== qsTr("Untitled") ? backup.name : ""
        show(read)
        savedText = ""          // nothing on disk matches it: it stays unsaved until saved
        message = qsTr("Restored %1 from the backup made at %2").arg(name).arg(backup.time)
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

    function isSelected(id) {
        return selection.indexOf(id) >= 0
    }

    // Selects `id` alone ("" selects nothing).
    function select(id) {
        if (coneSelection.length > 0)
            coneSelection = []
        const next = id === "" ? [] : [id]
        if (JSON.stringify(next) === JSON.stringify(selection))
            return
        stack.seal()
        selection = next
    }

    // Adds an element to the selection or takes it out (Ctrl+click). A ruler or target selected before is dropped.
    function toggle(id) {
        stack.seal()
        coneSelection = []
        const elementsOnly = selection.filter(s => element(s) !== null)
        selection = elementsOnly.indexOf(id) >= 0 ? elementsOnly.filter(s => s !== id) : elementsOnly.concat([id])
    }

    // Selects these elements, or adds them to the elements already selected.
    function selectMany(ids, add) {
        stack.seal()
        coneSelection = []
        const start = add ? selection.filter(s => element(s) !== null) : []
        selection = start.concat(ids.filter(id => start.indexOf(id) < 0))
    }

    function selectLast() {
        const list = track.elements
        if (list.length > 0)
            select(list[list.length - 1].id)
    }

    function isConeSelected(index) {
        return coneSelection.indexOf(index) >= 0
    }

    // Selects these cones, or adds them to the cones selected; any element, ruler or target selection is dropped.
    function selectCones(indices, add) {
        stack.seal()
        selection = []
        const start = add ? coneSelection : []
        coneSelection = start.concat(indices.filter(i => start.indexOf(i) < 0))
    }

    // Ctrl+click on a cone.
    function toggleCone(index) {
        stack.seal()
        selection = []
        coneSelection = isConeSelected(index) ? coneSelection.filter(i => i !== index) : coneSelection.concat([index])
    }

    // Makes the selected cones standing or leaning (one step).
    function setConeTypes(type) {
        if (coneSelection.length === 0)
            return
        run("setConeType", { indices: coneSelection, type: type })
        stack.seal()
    }

    // A standing cone added by hand where the person clicked (canvas metres); it is selected.
    function addConeAt(x, y) {
        run("addCone", { x: x, y: y })
        stack.seal()
        if (previewOn && preview && preview.canvasCones)
            selectCones([preview.canvasCones.length - 1], false)
    }

    function deleteSelected() {
        if (coneSelection.length > 0) {
            const indices = coneSelection
            coneSelection = []
            run("deleteCones", { indices: indices })
            stack.seal()
            return
        }
        if (selection.length === 0)
            return
        if (locked) {
            lockedNote()
            return
        }
        const id = selectedId
        if (id === "ruler") {
            if (elementCount > 0) {
                report(qsTr("Delete the track elements before the ruler: their sizes are measured with it."), null)
                return
            }
            run("removeRuler")
        } else if (id === "origin" || id === "direction") {
            run("setTarget", { which: id, point: null })
        } else {
            run("removeMany", { ids: selectedElements.map(e => e.id) })
        }
        stack.seal()
    }

    // Copies every selected element (joins between them kept) and selects the copies.
    function duplicateSelected() {
        if (locked) {
            lockedNote()
            return
        }
        const ids = selectedElements.map(e => e.id)
        if (ids.length === 0)
            return
        run("duplicateMany", { ids: ids })
        stack.seal()
        selection = track.elements.slice(track.elements.length - ids.length).map(e => e.id)
    }

    function reverseSelected() {
        if (locked) {
            lockedNote()
            return
        }
        const ids = selectedElements.map(e => e.id)
        if (ids.length === 0)
            return
        run("reverse", { ids: ids })
        stack.seal()
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

    // Place cones again starts a fresh round: touch-ups are cleared first (one undo step; Main asks before).
    function placeCones() {
        if (locked) {
            run("clearTouchUps")
            seal()
        }
        const result = processed()
        preview = result
        previewOn = result !== null
        if (result)
            message = qsTr("Placed %1 cones").arg(result.cones.length)
    }

    function refreshPreview() {
        const result = locked ? Touchups.result(track) : Post.run(track)
        if (result.error) {
            previewOn = false
            preview = null
            report(result.error.message, result.error.target)
        } else {
            preview = result
        }
    }

    // Touch-ups end with the preview (one undo step; Main asks before).
    function clearPreview() {
        if (locked) {
            run("clearTouchUps")
            seal()
        }
        previewOn = false
        preview = null
    }
}
