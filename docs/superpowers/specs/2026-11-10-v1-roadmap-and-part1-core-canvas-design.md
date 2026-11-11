# Conestructor v1.0.0: roadmap, and part 1 (core canvas) design

Date: 2026-11-10. Status: approved in conversation section by section; this document is for the owner's review.

## Why

Conestructor lets a Formula SAE team design an autocross track ahead of time over a birdseye photo of a lot, then
post-process it into an ordered list of cone positions. A later mobile app (its own branch, not part of v1) turns
those positions into GPS points and walks a person to each cone, so the track on the lot matches the design.

v1.0.0 turns the working prototype into something a new team member can learn quickly, and that sponsors, employers
and other teams can understand from the README. Other FSAE teams may use it later; other apps (simulators, for
example) may read its track files.

## Decisions (all parts)

| Topic | Decision |
|---|---|
| Distribution | A packaged Windows zip on GitHub Releases that runs without Qt installed. |
| Licence | MIT. Third-party files (Ubuntu Mono font) keep their own licences. |
| Track file | One `.cone` file per track: plain UTF-8 JSON, readable by any JSON parser. Holds everything: targets, ordered cones, the editable design, and the background photo (last, base64). |
| Format for other apps | `docs/cone-format.md` (field table, example) plus a JSON Schema; `format` name and version field at the top; the version changes only when the structure does. README links both and shows a short "read the cones" example. |
| Units in files | Metres. |
| Axes in files | x from the Origin target toward the Direction target; y 90° to the left of x seen from above; headings in degrees counter-clockwise from +x. (The prototype's y pointed right; this is fixed.) |
| Units on screen | A preference: feet and inches (default), decimal feet, or metres. |
| Server | Upload and download over HTTP through a public subdomain, LAN address tried first. No SSH. |
| Server address | Sensitive. Never in the repo, the release, the docs or commit messages; examples use `<public host>`. |
| Team access | A **team code** typed once into Preferences and saved locally. It carries the server address and that team's key. The app works fully without one; only upload and download need it. |
| Teams | Multi-team on the server: each team has its own key and sees only its own tracks. v1 creates one team (the owner's); how other teams get keys is decided later. |
| Cone density | A track slider with five notches, default **SAE standard** (notch 3); per-element override; an "Outside cones" switch on turns; a "Cones we own" budget with a live count in the status bar. |
| Car outline | A true-size rectangle (dimensions in Preferences), optionally showing a top-down car image scaled inside it. Never exported or counted. |
| Setup | A checklist in the side panel (photo, ruler, Origin, Direction) that unlocks the element palette. |
| Rulebook | Defaults and warnings follow the rulebook. Read so far: Formula Student Rules 2026 v1.1, D 6.1.1 (autocross): straights at most 80 m, slalom cones 7.5 m to 12 m apart in a line, track at least 3 m wide, turning diameter at least 9 m. The US FSAE 2026 figures are still to be confirmed from the owner's copy before part 3. |

## Roadmap

Each part gets its own spec, plan and build, in its own session, on its own branch, merged to `main` and pushed.

1. **Core canvas** (this document). Metres underneath, zoom and pan, elements as data with real-unit defaults,
   plain-word properties, Preferences (units), rotate, delete, duplicate, undo, working view toggles, on-screen errors,
   housekeeping, licence.
2. **Setup and track files.** The setup checklist; `.cone` save and open (photo embedded); `docs/cone-format.md` and
   the schema; unsaved-changes warning; window title with the track name; the JSON export replaced by `.cone`. From
   the owner's part 1 check: arrows through each element showing the direction of travel; an element's rotation
   typed in the panel; Ctrl+click to select several elements, with the panel showing and changing the settings they
   share (track width, for example). The `.cone` format leaves room for part 3's hand-edited cones.
3. **Cones.** Density notches and per-element overrides, outside cones on turns, the cone budget, spacing checked
   against the rulebook, rule warnings (advice only, a small ⚠ on the element), the car outline and the Tools menu.
   From the owner's part 1 check: turns from 0° to 360° (one element for a full circle, so a skidpad figure 8 is
   two turns); a line tool for straight rows of cones (boundaries and walls); after Place cones, deleting single cones
   and changing a cone's type and pointing direction, which re-processing replaces; the cone count shown as n/m
   against the cones the team owns (Preferences), red when over.
4. **Team server.** `server/` in the repo (moved from `coneRoutes.py`): multi-team tables, team keys, HTTP upload of a
   `.cone` file with a small thumbnail, a team track list and download; nginx for the subdomain passing only
   `/api/cone/`; a LAN-only admin prefix for deleting tracks and adding team keys; Preferences › Team (team code);
   File › Open gains a Team tracks list; Upload to team.
5. **Release v1.0.0.** Release script (`windeployqt`, MSVC runtime), packaged zip checked on a clean PATH, README for
   new members, sponsors and employers (purpose, the pipeline, a getting-started walk-through with screenshots, the
   file format), the GitHub release and tag.

The mobile app is out of scope for v1 and lives on its own branch later.

## Part 1: core canvas

### Architecture

The track is plain data. Nothing drawn on screen keeps its own copy.

```
track = {
  photo:   { path, metresPerPixel },            // metresPerPixel comes from the ruler
  ruler:   { a: {x, y}, b: {x, y}, realLength },// ends in photo pixels, realLength in metres
  targets: { origin: {x, y} | null, direction: {x, y} | null },  // photo pixels
  elements: [ { id, type, x, y, rotation, props: {...}, joins: { A: {id, end} | null, B: ... } } ]
}
```

- **Canvas metres** are the internal coordinates for elements: origin at the photo's top-left, x right, y down.
  The export frame is produced only on export (`frame.mjs`).
- Ruler ends and targets are pinned to photo pixels. If the ruler's real length changes after elements are placed,
  element positions are rescaled about the photo origin so they stay on the same spots of the photo, and their sizes
  (in metres) do not change. This is one undoable step.

Logic lives in pure JavaScript modules in `app/qml/logic/`, tested with qmltestrunner:

| Module | Job |
|---|---|
| `units.mjs` | Format metres as ft-in, decimal feet or metres; parse what people type (`12' 6"`, `12.5 ft`, `3.81 m`, a bare number in the current unit). |
| `elements.mjs` | Per type: defaults, property list (key, label, kind, limits), centreline path, end positions and headings, cones. |
| `snapping.mjs` | Nearest open end within the snap distance; placing an element so its end meets another's facing the opposite way; keeping a joined chain glued after an edit (ported from the prototype's `Element.qml`). |
| `frame.mjs` | Canvas metres ↔ export frame (Origin, Direction, y to the left, headings counter-clockwise). |
| `postprocess.mjs` | Cones for every element in canvas metres, de-duplication at joins, ordering along joined chains, stitching separate chains by nearest end (ported from `ConeUtils.js`). |
| `commands.mjs` | Every edit as a command with its inverse: add, move, rotate, set property, delete, join, unjoin, set ruler, set target, set photo. An undo stack with redo; consecutive changes to one field merge into one step. |

QML only draws and forwards input:

- `TrackStore` (singleton): holds the track, runs commands through the undo stack, emits `changed`.
- `CanvasView`: the world layer (photo, ruler, targets, elements, cone preview) under one transform; zoom and pan.
- `ElementView`: draws one element from data (translucent band in the element's colour, dashed centreline, end markers,
  link dot on joined ends); selection outline and rotate handle.
- `Palette`, `PropertyPanel`, `PreferencesDialog`, `StatusBar`, `ErrorBanner`.

C++ stays small: `Settings` (an `.ini` in AppData; later parts add the team code), `FileIO` (read and write files),
and the JSON cone export. They are registered as QML singletons (`QML_ELEMENT`/`QML_SINGLETON`), not as late context
properties. The prototype's database upload is removed from the menu until part 4 replaces it.

### Canvas, photo, ruler and targets

- **Photo:** File › *Load lot photo…* (PNG, JPG). Without one, the blueprint background shows. Part 1 stores the path;
  part 2 embeds the photo in `.cone`. The local Duck pond and Riverwind images appear under View › Backgrounds only when
  present at build time.
- **Zoom and pan:** the scroll wheel zooms toward the cursor, from "whole photo fits" down to single cones; drag on
  empty canvas, middle-drag or Space+drag pans; View › *Fit to photo* (F). Window size changes only what is visible,
  never the scale.
- **Ruler:** dragged from the palette; two round end handles; one setting, *Real length*, in display units; drawn with
  end ticks and its length label. One per track (its palette tile greys out once placed). Until the ruler has a real
  length, track elements in the palette are greyed out with the hint "Set the ruler first."
- **Targets:** two palette tiles, **Origin** and **Direction**, one of each, labelled on the canvas. With both placed,
  a dashed arrow runs from Origin through Direction, and the distance between them is shown.
- **Status bar:** the cursor's position in the export frame once both targets exist (for example `x 12.3 m · y −4.0 m`,
  or in feet), the zoom level, and messages.

### Track elements

| Element | Settings (defaults) |
|---|---|
| Straight | Length 20 m · Track width 4 m |
| Slalom | Lead-in 6 m · Lead-out 6 m · Cones 4 · Cone spacing 10 m · Weave offset 1.5 m · First turn Left · Track width 4 m |
| Chicane | Lead-in 6 m · Lead-out 6 m · Shift length 12 m · Sideways shift 6 m · Direction Left · Track width 4 m |
| Turn (was Hairpin) | Lead-in 6 m · Lead-out 6 m · Turn angle 180° · Radius 6 m · Radius type Constant · Exit radius (shown only when Changing) · Direction Right · Track width 4 m |

- The palette tooltip for Turn reads "Turn: anything from a sweeper to a hairpin."
- Setting kinds: **length** (unit-aware field with up and down arrows), **angle** (degrees), **count** (whole number),
  **choice** (a Left/Right switch). Each has physical limits (for example track width 1 m to 20 m, turn angle 0° to
  180°); a value outside them is clamped with a short note. Rulebook limits are part 3's warnings and never block.
- Position and rotation show at the top of the panel in the export frame once both targets exist.
- Changes apply as you type; there is no Apply button.
- Cones in part 1 carry over the prototype's placement, converted to metres (pairs along straights, leaning cones in
  turns and slaloms; cone base 10.5 in, leaning length 18 in). Part 3 replaces the spacing rules with density notches.

### Editing, menus and Preferences

- **Select** by clicking; the selected element gets an outline and a rotate handle (Shift snaps to 15°). Dragging or
  rotating unjoins the element; it can snap again on release. Ctrl while dragging turns snapping off. Dragging off the
  edge no longer deletes.
- **Delete**/Backspace deletes (neighbours unjoin); **Ctrl+D** duplicates (unjoined, offset 2 m); right-click offers
  Duplicate and Delete; **Ctrl+Z**, **Ctrl+Y**/**Ctrl+Shift+Z** undo and redo, with the step named in the Edit menu
  (for example "Undo Move Straight").
- **Errors** appear in a banner over the canvas, with the element at fault highlighted and a *Show me* button that pans
  to it: "Set the ruler's real length", "Place the Direction target", "Nothing to process yet: add some track".
- **Cone preview:** Process › *Place cones* overlays cones and dims the elements; View › *Show cones* (C) and
  *Show route line* (R) toggle them; Process › *Clear preview* removes the overlay.
- **Menus:**
  - File: New · Load lot photo… · Export cones (JSON)… · Quit
  - Edit: Undo · Redo · Duplicate · Delete · Preferences… (Ctrl+,)
  - View: Fit to photo · Show cones · Show route line · Backgrounds (only when local images are present)
  - Process: Place cones · Clear preview
  - The Tools menu returns in part 3 with the car outline.
- **Preferences:** one section in part 1, **Units** (Feet and inches default, Decimal feet, Metres). Changing it
  relabels every field, the status bar and the ruler at once. Saved in `Conestructor.ini` in AppData. Parts 3 and 4
  add Cones, Car and Team sections.
- **Window title:** "Conestructor 0.2 — Untitled"; the version comes from CMake.

### JSON export in part 1

Until part 2 replaces it with `.cone`, File › *Export cones (JSON)…* writes:

```json
{
  "units": "m",
  "axes": "x toward Direction target, y to the left, heading degrees counter-clockwise from +x",
  "targetDistance": 41.2,
  "cones": [ { "index": 0, "type": "standing", "x": 1.77, "y": 7.76, "heading": 0.0 } ]
}
```

### Errors and edge cases

- Post-process refuses, with a banner, when the ruler has no real length, a target is missing, Origin and Direction
  are closer than 1 m, or there are no track elements.
- A photo that fails to load shows a banner and keeps the previous background.
- Settings that fail to save show a banner and the app carries on with defaults.
- Typed values that do not parse leave the field red with the old value kept until fixed or Esc.

### Testing

Scripts copied from Gluttony's pattern: `tests\build.ps1` (builds the app and the tests) and `tests\run.ps1` (C++
tests through ctest, then qmltestrunner).

- `units`: format and parse round trips, every unit, bad input.
- `elements`: end positions and headings per type against hand-worked numbers (a 20 m straight's ends at ±10 m; a 180°
  turn of radius 6 m exits 12 m to the side, heading back); each path starts and ends exactly at its ends.
- `snapping`: joining puts both ends on one point facing opposite ways; moving one element of a chain keeps it glued.
- `frame`: Origin maps to (0, 0); Direction lands on +x at the right distance; a point left of the axis has +y;
  headings are counter-clockwise.
- `postprocess`: driving order along a joined chain; a reversed element walked the right way; duplicates at joins
  removed.
- `commands`: every command followed by undo restores the track exactly; redo re-applies it.
- Port check: a fixed sample track through the prototype's cone code (kept as a test fixture) and the new code; the
  cone lists match after converting units and axes.
- C++ (Qt Test): settings round trip; the JSON export writes metres in the export frame.

**Owner check** (about 10 minutes): load a lot photo, set the ruler on a parking space, place both targets, build a
short track of all four elements with joins, zoom, pan and resize the window, undo and redo, switch units, place cones,
export, and check that one visible cone has believable x and y in the JSON.

### Housekeeping

- The inner `Conestructor/` folder becomes `app/`. (`coneRoutes.py` moves to `server/` in part 4.)
- Remove `archived/` (git history keeps it), `test.cpp`, the unused `resources.qrc` and the duplicated `ConeUtils.js`
  functions (the file is replaced by `postprocess.mjs`).
- Add an MIT `LICENSE`.
- Version 0.2.0.
- `.gitignore` gains `app/config/secrets.json` ahead of part 4.

### Done

- All automated tests pass.
- A clean copy of the repo builds without the map images.
- The owner check passes.
- Nothing in the repo names the server's public address.
- Built on branch `part1-core-canvas`, merged to `main` and pushed after a check of what is being pushed.
