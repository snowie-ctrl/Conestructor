# Conestructor v1.0.0 part 2: setup and track files

Date: 2026-11-10. Status: approved in conversation section by section; this document is for the owner's review.
Roadmap and part 1: `2026-11-10-v1-roadmap-and-part1-core-canvas-design.md`. Part 1's plan adds its own decisions
in `docs/superpowers/plans/2026-11-10-part1-core-canvas.md`.

## Why

Part 1 made the canvas: metres underneath, elements as data, undo, a cone preview and a stop-gap JSON export. Part 2
makes a track something a team keeps and passes around. A new member is walked through setup, a track is one `.cone`
file holding everything (photo included) that other apps can read from a documented format, and the editing gaps the
owner found in the part 1 check are closed: which way an element is driven, exact rotation, and editing several
elements at once.

## Decisions

| Topic | Decision |
|---|---|
| Approach | The file's contents are built and read by a pure JS module (`logic/conefile.mjs`, tested in qmltestrunner). C++ only reads and writes files and holds photo bytes (`PhotoStore`, shown through an image provider), so the bytes never enter the track or its undo snapshots. |
| Track name | The `.cone` file's name without the extension; "Untitled" until first saved. Save As renames. Written into the file's `name` on every save. |
| Photo step | Ticked by loading a lot photo or by choosing "Use the blueprint". |
| Arrows | Each element's own entry → exit (end A → end B). |
| Driving order | Follows the arrows: each joined chain is walked in the direction most of its elements point. This replaces part 1's "walk from the earliest element's open end". |
| Against the track | An element walked backwards shows a ⚠; Reverse direction swaps its entry and exit in place. |
| Typed rotation | Turns the element's whole joined chain about the element's centre; everything stays joined. |
| Multi-select | Ctrl+click, Shift+drag box; shared settings in the panel; drag, delete and duplicate work on the whole selection. |
| File extras | Open Recent, a file named on the command line, drag and drop onto the window, autosave backup with restore. |
| Version | 0.3.0. |

## The `.cone` file

One UTF-8 JSON file per track. Keys are written in this order; the photo is always last, so the readable part is at
the top of the file.

```json
{
  "format": "conestructor-track",
  "version": 1,
  "name": "Duck pond autocross",
  "app": "Conestructor 0.3.0",
  "saved": "2026-11-10T14:03:00Z",
  "units": "m",
  "axes": "x toward Direction target, y to the left, heading degrees counter-clockwise from +x",
  "targets": { "origin": { "x": 0, "y": 0 }, "direction": { "x": 41.2, "y": 0 }, "distance": 41.2 },
  "cones": [
    { "index": 0, "type": "standing", "x": 1.77, "y": 7.76, "heading": 0.0, "element": "e1" }
  ],
  "design": { },
  "photo": { "mediaType": "image/jpeg", "width": 4032, "height": 3024, "data": "<base64>" }
}
```

| Field | Meaning |
|---|---|
| `format` | Always `"conestructor-track"`. |
| `version` | Whole number, 1 for this structure. Changes only when the structure changes. |
| `name` | The track's name (the file name when saved). |
| `app` | The app and version that saved it. |
| `saved` | When it was saved, ISO 8601 UTC. |
| `units`, `axes` | Fixed sentences saying metres and the export frame. |
| `targets` | Origin and Direction in the export frame (Origin is always 0, 0; Direction always on +x), and the distance between them in metres. `null` for a target not yet placed; `distance` is `null` unless both are placed. |
| `cones` | Every cone in driving order, in metres and degrees in the export frame, freshly computed at each save; `[]` when the track cannot be processed yet (the save still works). `index` from 0; `type` `standing` or `leaning`; `heading` the way a leaning cone points (0 for standing cones); `element` the id of the element that made it (`null` for cones part 3 lets people add by hand). |
| `design` | Conestructor's own editable track (see below). Other apps should not rely on it. |
| `photo` | The lot photo: `mediaType` (`image/png` or `image/jpeg`), size in pixels, and the original file's bytes as base64, never re-encoded. `null` when the track uses the blueprint or has no photo. |

Rules for readers, stated in `docs/cone-format.md` and the schema:

- Ignore fields you do not know. New optional fields do not change `version`; only a change of structure does.
- `cones` is always the final list, including any hand edits, so part 3's hand-edited cones fit inside version 1.
  Part 3 adds an optional `"edited": true` on a cone and keeps its edits in `design`.

`design` is the track object exactly as the app holds it (photo pixels and canvas metres, element ids, joins,
`nextId`), with `photo` holding `{ kind, metresPerPixel }` and no bytes. Open then save loses nothing.

The bundled Duck pond and Riverwind images are embedded like any photo, so the file opens on a build without them.

Opening a file the app cannot use leaves the current track untouched and says why in the banner:

- not JSON, or `format` missing or different: "That file isn't a Conestructor track."
- `version` newer than 1: "That track was made with a newer Conestructor."
- `design` missing or malformed: "That track file is damaged."
- a photo that will not decode: the track opens on the blueprint with "The photo in that file couldn't be read; the
  blueprint is shown instead." (photo step unticked).

Docs: `docs/cone-format.md` (purpose, the field table, the example, the rules for readers, a short Python "read the
cones" example) and `docs/cone-format.schema.json` (JSON Schema draft 2020-12). The README links both and repeats the
short example.

## Setup checklist and the photo

The checklist sits at the top of the side panel, in place of the Ruler, Origin and Direction tiles:

```
Setup                                   3 of 4
 ✓ 1  Photo      [Load lot photo…] [Use the blueprint]
 ✓ 2  Ruler      [drag tile]  Drag onto something you know, then type its length
 ✓ 3  Origin     [drag tile]  x and y are measured from here
 ○ 4  Direction  [drag tile]  x points from Origin toward here
Track pieces unlock when setup is done.
```

- A step is done when: Photo, a photo is loaded or the blueprint was chosen; Ruler, it is placed and has a real
  length; Origin, it is placed; Direction, it is placed at least 1 m from Origin.
- A row's drag tile greys out once its item is placed, as in part 1.
- With all four done, the checklist folds to one line, "Setup ✓ (photo, ruler, targets)", which unfolds on click,
  and the track tiles (Straight, Slalom, Chicane, Turn) unlock.
- If a step comes undone later (a target deleted, for example), the checklist unfolds and the track tiles lock
  again. Existing elements stay fully editable; only adding new ones waits.
- File › Load lot photo… stays in the menu.

The track's photo becomes `photo: { kind, ref, metresPerPixel }`:

- `kind`: `"none"` (a new track that has not chosen; the blueprint shows but step 1 is not done), `"blueprint"`, or
  `"image"`.
- `ref`: a small id into the C++ `PhotoStore`, shown as `image://photo/<ref>`; `null` unless `kind` is `"image"`.
  Undo snapshots carry only the id, so undoing a photo change switches ids.
- `PhotoStore` keeps every photo loaded since the last New or Open (undo may go back to one); New and Open empty it
  along with the undo history.
- A new photo keeps the ruler and targets at their old pixels (part 1's ruling stands).

## Files, title and safety nets

**File menu:** New (Ctrl+N) · Open… (Ctrl+O) · Open Recent › · Save (Ctrl+S) · Save As… (Ctrl+Shift+S) · Load lot
photo… · Quit. Export cones (JSON) is removed.

**Saving.** Save on an Untitled track opens Save As. The window title is `Conestructor 0.3 — <name>`, with `*` after
the name while there are unsaved changes. Unsaved means the track differs from what was last saved or opened, so
undoing back to the saved state clears the `*`; the selection, zoom and cone preview are not changes. The file is
written through a temporary file and renamed into place (`QSaveFile`); a failed save shows a banner and the track
stays unsaved.

**Unsaved-changes warning** on New, Open (any route: menu, Open Recent, drop) and closing the window: "Save changes
to <name>?" with Save, Don't save, Cancel. Save on an Untitled track goes through Save As; cancelling that cancels
the whole action.

**Open Recent:** the last 8 files, newest first, kept in `Conestructor.ini`. A file that has gone is removed from
the list with a banner. "Clear list" at the bottom.

**Command line:** `Conestructor.exe "D:\tracks\Duck pond.cone"` opens that track at start-up. A bad file shows the
banner over an empty track.

**Drag and drop onto the window:** a `.cone` file opens (with the warning when needed); a PNG or JPG becomes the lot
photo (one undo step); anything else gets "Drop a .cone track or a PNG or JPG photo."

**Autosave backup.** Every 2 minutes, when there are changes since the last save or backup, the app writes
`%APPDATA%\Conestructor\autosave.cone` (photo included) and records the track's path, if any, in `autosave.ini` beside
it. A normal close (after Save or Don't save) and a successful save delete the backup. At start-up, if a backup is
there: "Conestructor closed without saving <name> (backed up at 14:02). Restore it?" with Restore and Discard.
Restore opens it as unsaved with its original name and path, so Ctrl+S writes back to the original. A command-line
file waits until the question is answered. A backup that fails to write shows nothing (it is a safety net), but is
tried again next time.

## Editing

### Arrows and driving order

- White chevrons on each element's centreline point entry → exit, about one every 8 m and at least two per element,
  sized in screen pixels so they read at any zoom. They dim with the element under the cone preview.
- Each joined chain is walked in the direction most of its elements point. A tie, or a single element, goes entry
  → exit. A closed loop starts at its earliest element, in the majority direction. Separate chains are still
  stitched nearest end first.
- An element walked backwards shows a small ⚠ at its middle; its tooltip says "Runs against the track: right-click ›
  Reverse direction".

### Reverse direction

Right-click › Reverse direction, or Edit › Reverse direction; one undo step; works on a multi-selection. It swaps the
element's entry and exit in place: the centreline and both ends stay where they were, and joins stay joined (their
A/B labels swap). Per type: lead-in and lead-out swap; a turn's Direction flips and its Radius and Exit radius swap; a
slalom's First turn is set so the same cones are weaved; a chicane keeps its Direction; a straight just turns 180°.

### Typed rotation

The panel's Rotation row becomes a field: degrees, counter-clockwise from the Origin → Direction axis (the export
frame), up and down arrows step 1°, Shift+arrow 15°. It shows once both targets exist, like the position row. Typing
turns the element's whole joined chain about the element's centre, everything stays joined, and it is one undo step
("Rotate Straight"). An unjoined element just turns. Position stays read-only.

### Multi-select

- Ctrl+click adds or removes an element; a Ctrl+click that removes one starts no drag.
- Shift+drag on empty canvas draws a box selecting every element it touches; Ctrl+Shift adds to the selection.
- A plain click, or a click on empty canvas, selects one element or nothing, as in part 1.
- Only track elements multi-select; clicking the ruler or a target selects it alone.
- Every selected element has the white outline; the rotate handle shows only with one selected.
- Panel: "3 elements selected", then every setting they all show now, in the usual order (Track width for any mix;
  Lead-in and Lead-out for slaloms, chicanes and turns; Direction for chicanes and turns; Exit radius only if all are
  Changing). Matching values show normally; differing values show an empty field with "mixed" greyed in it, or no
  choice pressed. Typing sets all of them, each clamped to its own limits, in one undo step ("Change Track width
  (3 elements)").
- Drag: dragging any selected element moves the whole selection. Joins inside the selection stay; joins to
  unselected elements break. If one of the selection's open ends comes within snap reach of an outside open end, the
  whole group shifts and turns as one to join it; Ctrl skips snapping.
- Delete removes all of them; Ctrl+D copies all of them 2 m offset, keeping the joins between the copies, and selects
  the copies. Each is one step.

## Code

| Piece | Job |
|---|---|
| `logic/conefile.mjs` (new) | Track → document (every field but the photo bytes) and document → track with every check; the setup status (which steps are done). |
| `logic/selection.mjs` (new) | The settings several elements share, with their common value or "mixed"; which elements a box touches. |
| `logic/postprocess.mjs` | Chains walked in the arrows' majority direction; reports the elements walked backwards. |
| `logic/elements.mjs` | `reversed(el)` per type; arrow positions along the path. |
| `logic/commands.mjs` | New commands, each undoable and named: `setProps` (several ids), `removeMany`, `duplicateMany` (keeps inner joins), `placeMany` (group drag and snap), `rotateChain`, `reverse`; `setPhoto` takes `{ kind, ref }`. |
| `TrackStore.qml` | `selectedIds` beside `selectedId`; `filePath`, `name`, `dirty` (the track's text against the saved text); New, Open and Save go through it. |
| C++ `PhotoStore` and image provider | Photo bytes, media type and size by id; loads from a file path or a `qrc:` path. |
| C++ `TrackFile` | `save(path, documentText, photoId)` writes the JS-built text with the photo added last, through `QSaveFile`; `open(path)` parses, moves the photo into `PhotoStore`, and hands the rest to QML. Autosave write, find and delete. |
| C++ `Settings` | The recent files list. |
| `main.cpp` | A file named on the command line. |
| QML | `SetupChecklist.qml` (new); the palette shows only track tiles; `ElementView` draws arrows and ⚠; `PropertyPanel` multi-select and typed rotation; `CanvasView` Ctrl+click, box and group drag; `Main.qml` File menu, warning dialog, title, drop area, autosave timer and the restore question. |

`FileIO`'s JSON export and its test are removed (what remains of `FileIO` may fold into `TrackFile`).

## Testing

Test-first, as in part 1. `app\tests\run.ps1` runs ctest, then qmltestrunner.

- **Logic (qmltestrunner):** `conefile` round trip (track → document → track is identical) and every refusal (bad
  format, newer version, missing or malformed design); setup status for each step; the saved document checked against
  `docs/cone-format.schema.json` by a small validator in the tests covering the keywords the schema uses, so the
  schema cannot drift from the app; `reversed` keeps the centreline and ends for every type and both radius types;
  driving order follows the arrows and a backwards element is reported; every new command followed by undo restores
  the track exactly; shared settings and "mixed"; the box hit-test.
- **C++ (Qt Test):** save then open with a real PNG (bytes identical, `format` the first key and `photo` the last);
  a save that cannot write leaves the old file; `PhotoStore` and the provider; the recent files list; autosave write,
  find and delete.
- **Window (`tst_qmlload`, offscreen, real mouse and keys):** the checklist locks and unlocks the track tiles;
  Ctrl+click and a shared field set every selected element; Shift+drag box; a group drag keeps inner joins; typed
  rotation turns the chain; Reverse from the menu; the title gains `*` after an edit and loses it on save; New with
  unsaved changes asks first and Cancel keeps the track; a saved file opens back identical; a command-line file opens.

**Owner check** (about 15 minutes): start a new track through the checklist with a real lot photo; build a chain,
reverse a back-to-front turn and see its ⚠ clear; type 90° on the first straight and watch the chain turn; Ctrl+click
three elements and set their track width; box-select a group and drag it onto an open end; save, close (no question)
and reopen from Open Recent; edit, then try to close (the warning); end the app from Task Manager and restore the
backup at start-up; drop a `.cone` and a photo onto the window; open the `.cone` in a text editor and check the top of
it reads sensibly.

## Done

- `app\tests\run.ps1` passes (ctest and qmltestrunner).
- A clean clone builds without the map images.
- The owner check passes.
- Nothing in the repo names the server's public address or the home network.
- Built on branch `part2-setup-files`, merged to `main` and pushed after a check of what is being pushed.
