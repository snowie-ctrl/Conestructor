# Conestructor v1.0.0 part 4: cones

Date: 2026-11-11. Status: approved in conversation section by section; this document is for the owner's review.
Roadmap and part 1: `2026-11-10-v1-roadmap-and-part1-core-canvas-design.md`. Part 2:
`2026-11-10-part2-setup-and-track-files-design.md`. Part 3: `2026-11-11-part3-ease-of-use-design.md`; each plan in
`docs/superpowers/plans/` adds its own decisions.

## Why

Once a course is laid out, the team needs the cone list to be exactly what goes on the lot, and to fit the cones the team
owns. Part 4 lets them choose how densely cones are placed (for the whole track and per element), add cones on the
outside of turns, see the count against their budget, and touch up single cones by hand before saving or uploading. It
adds a true-size car outline for checking that the car fits through tight sections, and clears the nine minors deferred
from part 3's final review.

## Decisions

| Topic | Decision |
|---|---|
| Density | A track setting with five notches: Fewest ×2, Fewer ×1.5, **SAE standard** ×1 (today's spacing, the default), More ×0.75, Most ×0.5. The factor multiplies the largest gap between gate pairs, turn inside cones, chicane cones and turn outside cones. Slalom apex cones (their own Cone spacing) and lines (their own spacing) are not affected. |
| Per-element density | Each driven element has a Cone density setting: Same as track (default) or one of the five notches. |
| Outside cones | A switch on turns, Off by default: standing cones along the outer edge of the arc. |
| Cone budget | Preferences › Cones › *Cones we own*; the status bar shows the count as n/m, red when over. |
| Touch-ups | After Place cones: delete a cone, move it, switch standing/leaning, change where a leaning cone points, add a cone. They belong to one round of Place cones: clearing the preview or placing again brings every cone back; nothing is remembered between rounds. |
| The lock | While touch-ups exist the track is locked: elements, the ruler, the targets and the density cannot change. Undoing back past the first touch-up, or clearing, unlocks it. |
| Storage | The first touch-up freezes the placed cones into the track (`touchUps`); later touch-ups edit that list. Saved as `design.touchUps`; the file's `cones` is that list. |
| Car outline | One true-size car, shown from Tools › Car outline; dragged and rotated; not saved in the track or the file, not undoable, never counted or exported. |
| Rulebook | Still not applied to elements; no warnings (part 3). |
| Format | Version stays 1: the new fields are optional. |
| Version | 0.5.0. Branch `part4-cones`. |

## Density

### The notches

| Notch | Name | Factor | Gate pairs (straights, leads) | Turn inside cones | Chicane cones | Turn outside cones |
|---|---|---|---|---|---|---|
| 1 | Fewest | ×2 | 20 m | 4.9 m | 3.7 m | 10 m |
| 2 | Fewer | ×1.5 | 15 m | 3.7 m | 2.7 m | 7.5 m |
| 3 | SAE standard | ×1 | 10 m | 2.4 m (8 ft) | 1.8 m (6 ft) | 5 m |
| 4 | More | ×0.75 | 7.5 m | 1.8 m | 1.4 m | 3.75 m |
| 5 | Most | ×0.5 | 5 m | 1.2 m | 0.9 m | 2.5 m |

The figures are the largest gap: cones are spread evenly along each run, as few as keep every gap at or under it (as
today). On notch 3 every element places exactly the cones it places today; the port check and the existing
post-processing tests pin that.

- The track's notch is `track.density` (1 to 5, default 3). A file without it reads as 3.
- An element's notch is its own Cone density setting when set, otherwise the track's.
- Lines and slalom apex cones ignore density.

### The Cones box

A small box in the side panel, between the palette and the property panel:

- **Density**: a slider with five labelled notches and the notch's name under it ("SAE standard"). Moving it is one undo
  step, "Change density". Greyed out until setup is done, and while the track is locked.
- **Place cones**: the same as Process › Place cones.
- While the track is locked, a line: "Touched up: 4 changes. The track is locked; Clear preview to change it."

### Per-element override

Straights, slaloms, chicanes and turns get a **Cone density** setting, shown in the property panel as a drop-down:
*Same as track (SAE standard)* (the track's notch named in brackets), Fewest, Fewer, SAE standard, More, Most. It is a
shared setting in a multi-selection, so several elements can be set at once. Stored as `props.density`: 0 for Same as
track, 1 to 5 for a notch.

### Outside cones on turns

Turns get **Outside cones**, an Off/On switch, Off by default (`props.outsideCones`, `"off"` or `"on"`). On adds standing
cones along the outer edge of the arc's interior (both ends of the arc already have the leads' gate pairs), at most 5 m
apart on notch 3, scaled by the element's notch. They are kept by the "cones on the driving surface" check (they lie on
the band's edge) and come in the turn's cone order after its inside cones.

### The count

- The status bar shows **Cones 132 / 150** when a budget is set, red when the count is over it, and **132 cones** when no
  budget is set.
- It counts what Place cones would place now (or the touched-up list while touched up), whether or not the preview is
  showing, line cones and added cones included.
- It is worked out a quarter of a second after the last change, so a drag does not process the track on every mouse
  move. It is hidden while the track cannot be processed (setup not done, no elements).
- **Preferences › Cones › Cones we own**: a whole number, 1 to 9999; blank means no budget.

## Touch-ups

### Picking cones

- While placed cones are showing (the preview is on and View › Show cones is ticked), a click within a cone's footprint
  plus 4 screen pixels selects that cone. Cones win over the dimmed elements under them; elsewhere clicks act as before.
- Ctrl+click adds a cone to the selection or takes it out. A Shift+drag box from empty canvas selects cones while cones
  are showing, and elements otherwise.
- Cones and elements are never selected together: picking a cone drops any element, ruler or target selection, and the
  other way round.
- A selected cone has a highlight ring. Hiding the cones, or clearing the preview, drops the cone selection.

### What can be done to a cone

| Touch-up | How | Undo step |
|---|---|---|
| Delete | Delete or Backspace, right-click › Delete cone, or the panel's Delete button. Works on several cones. | "Delete cone" / "Delete 5 cones" |
| Move | Drag the cone. Cones do not snap. One drag is one step. Its x and y can also be typed in the panel. | "Move cone" |
| Standing / Leaning | The panel's Type switch, or right-click › Make leaning / Make standing. A cone made leaning keeps its heading. Works on several cones. | "Make leaning" / "Make standing" |
| Pointing | A leaning cone's direction, typed in the panel in degrees counter-clockwise from the Origin → Direction axis (as element rotation is), or turned with a rotate handle on the selected leaning cone (Shift for 15° steps). | "Turn cone" |
| Add | Process › Add cone picks up a standing cone that follows the mouse, as part 3's tiles do; a click puts it down; Esc, right-click or choosing it again cancels. Or right-click on the canvas › Add a cone here. | "Add cone" |

- Touch-ups need placed cones showing: Process › Add cone and the right-click cone items are off otherwise.
- A cone's panel shows "Cone 37 of 132", where it came from ("From Turn e4", or "Added by hand"), its position (x and y
  in the export frame, typed), Type, Pointing (leaning only) and a Delete button.
- With several cones selected the panel shows "5 cones selected", Type (when they share one) and Delete.
- Touched-up cones (moved, retyped, turned or added) show a small blue dot on them, so changed cones are easy to find.
  Deleted cones are gone.
- Added cones come after every other cone in the driving order, in the order they were added. A moved cone keeps its
  place in the order. `index` always counts the final order.

### Freezing and the lock

- The first touch-up after Place cones copies the placed cones into the track as `touchUps` and applies itself, as one
  undo step. From then on the track is locked.
- **Locked:** the palette tiles, the density slider and every element setting are greyed out; dragging, rotating and gate
  nodes do nothing; Delete, Duplicate and Reverse on elements do nothing; the ruler and the targets cannot be placed,
  moved or deleted. A greyed tile's tooltip, and the status bar on a blocked drag, say "Clear preview to change the
  track".
- **Still possible while locked:** touch-ups, loading a lot photo, the View toggles, Preferences, the car outline, saving,
  New and Open.
- The commands enforce the lock (every track command except the touch-ups, clearing them and the photo is refused), so
  the canvas and panels only grey things out; nothing depends on them to keep the track safe.

### Ending touch-ups

- **Clear preview** with touch-ups present asks "Clear 4 touch-ups and unlock the track?" (Clear, Cancel). Clear removes
  `touchUps` (one undo step, "Clear touch-ups") and hides the preview.
- **Place cones** with touch-ups present asks the same question, then places a fresh list.
- Undo back past the first touch-up removes `touchUps` and unlocks the track; the preview stays on and refreshes.
- Without touch-ups, Clear preview and Place cones work as today (not undo steps), and the preview refreshes as the track
  is edited.

### Saving and opening

- The touched-up list is saved in `design.touchUps`: `{ "cones": [ { "type", "x", "y", "heading", "element", "edited" } ] }`
  in canvas metres (the design's own coordinates).
- The file's `cones` is that list in the export frame: `edited: true` on cones that were moved, retyped, turned or added;
  `element: null` on added cones; `index` the final order. Without touch-ups `cones` is worked out as today.
- Opening a file with touch-ups shows the preview with them, and the track is locked. A `touchUps` that cannot be read
  (not a list, a cone without a number or a known type) makes the file "damaged", as other design errors do.
- `docs/cone-format.md` and the schema describe `edited`, `element: null`, `design.density` and `design.touchUps`.

## The car outline

- **Tools** is a new menu between View and Process with one item, **Car outline**, a checkable toggle.
- The outline is one true-size car drawn above the elements and cones: a white rectangle with a small triangle at the
  front. With a car image set, the image fills the rectangle, stretched to it, its top being the car's front.
- Turning it on puts it in the middle of the view, pointing along the Origin → Direction axis (screen-right before the
  targets exist). Turning it off and on again keeps its place until the app closes.
- Drag its body to move it; a rotate handle (as on elements) turns it, Shift for 15° steps. Clicking it does not change the
  track selection. It never snaps or joins. It works while the track is locked.
- It is not saved in the track or the file, not undoable, and never counted or exported.
- Its size follows Preferences at once.

## Preferences

One scrolling column, three sections:

1. **Units**: as today.
2. **Cones**: *Cones we own* (whole number, blank for none).
3. **Car**: *Length* (default 2.9 m) and *Width* (default 1.4 m) in display units, 0.5 m to 10 m; *Top-down image*:
   Choose… (PNG, JPG), the file name, and Clear. When the image file is missing the outline is drawn without it and the
   section says "Image not found".

All are saved in `Conestructor.ini` by the C++ `Settings` (`conesOwned`, `carLength`, `carWidth`, `carImage`).

## Part 3's deferred minors

1. **Fold tooltip:** the two-line warning tooltip joins its lines with `"\n"` instead of a literal line break.
2. **Length box:** *Type its length* focuses the box when it is already open but has lost focus; Esc on the canvas
   closes an open box, leaving the length unset as the box's own Esc does.
3. **Save As on Untitled** starts with the name "Untitled" in the last folder used, not the previous track's file name.
4. **A ghost left behind:** a cancelled tile drag clears its ghost; the ghost hides while the mouse is outside the canvas
   and comes back on re-entry while the tile is still in hand. The canvas mouse area ends any half-done gesture when
   the press is cancelled.
5. **A wall cone at a gate:** when a line's cone and a course cone are within the de-duplication distance, the course
   cone is kept, whichever element comes first in the list.
6. **Hand-edited joins slightly apart:** joined ends up to 5 cm apart in an opened file are glued exactly together (the
   chain settled), so the next edit does not quietly unjoin them.
7. **Fold tests:** a folded turn loses the right cones; the chicane and slalom fold just past their thresholds and not at
   them.
8. **Reverse on a line:** the right-click menu hides Reverse direction for a line, and for a selection of lines only.
9. **Line dots:** a window test grabs the canvas and checks that a line's cone dots are drawn.

## Code

| Piece | Job |
|---|---|
| `logic/density.mjs` (new) | The notches (names, factors); an element's effective notch. |
| `logic/conerows.mjs`, `logic/elements.mjs` | Gaps × factor; turns' outside cones; the `density` and `outsideCones` settings; an element's cones worked out apart from its cached path, since the path does not depend on density. |
| `logic/postprocess.mjs` | The track's density; course cones beat line cones when de-duplicating (minor 5). |
| `logic/touchups.mjs` (new) | Freeze; delete, move, retype, point and add cones; picking a cone; the file's cone list from touch-ups. |
| `logic/commands.mjs` | `setDensity`; the touch-up commands and `clearTouchUps`; every other track command refused while locked. |
| `logic/conefile.mjs` | Reads and writes `density` and `touchUps`; `cones` from touch-ups; glues near joins (minor 6). |
| `TrackStore.qml` | `locked`, the cone selection, the debounced count. |
| `ConesBox.qml` (new) | Density slider, Place cones, the locked line. |
| `CarOutline.qml` (new) | The car. |
| `ConePreview.qml`, `CanvasView.qml` | Cone picking, dragging, the rotate handle, Add cone, the selection ring and blue dots; minors 2 and 4. |
| `PropertyPanel.qml`, `PropField.qml` | The cone panel; the notch drop-down; greyed fields while locked. |
| `ElementPalette.qml`, `PaletteTile.qml` | Greyed tiles while locked. |
| `StatusBar.qml` | The count n/m. |
| `PreferencesDialog.qml` | Cones and Car sections. |
| `Main.qml` | Tools menu, Process › Add cone, the clear and place-again questions, minors 1, 3 and 8. |
| `services/Settings` | `conesOwned`, `carLength`, `carWidth`, `carImage`. |
| `docs/cone-format.md`, `docs/cone-format.schema.json` | `edited`, `element: null`, `design.density`, `design.touchUps`. |

## Testing

Test-first, as in parts 1 to 3. `app\tests\run.ps1` runs ctest, then qmltestrunner.

- **Logic (qmltestrunner):**
  - notch 3 gives exactly today's cones for every type (the port check is unchanged);
  - each notch scales each kind of gap; an element's own notch beats the track's; lines and slalom apexes ignore it;
  - outside cones: off gives today's cones, on adds standing cones on the outer edge within the gap, kept by the
    driving-surface check;
  - freezing and each touch-up (delete one and several, move, retype, point, add), each undone exactly;
  - the lock refuses every element, ruler, target and density command and allows the touch-ups, clearing and the photo;
  - `.cone` round trip with touch-ups: `edited`, `element: null`, `index`; reopened locked; a damaged `touchUps`
    refused; a file without `density` reads as notch 3;
  - minors 5, 6 and 7.
- **C++ (Qt Test):** the new settings round-trip and keep within their limits.
- **Window (`tst_qmlload`, offscreen, real mouse and keys):** the slider and the drop-down change the cones; the status
  bar count and n/m turning red over budget; clicking, Ctrl+clicking and box-selecting cones; deleting, moving,
  retyping, turning and adding a cone; the lock greys the palette and a drag does nothing; Clear preview asks and
  unlocks; undo past the first touch-up unlocks; save, reopen, still locked; the car outline shows, drags, rotates and
  follows Preferences; minors 1 to 4, 8 and 9.

**Owner check** (about 15 minutes): build a course; slide the density and watch the count; set a budget below it and
see it go red; turn on outside cones on a hairpin and give one slalom its own notch; place cones, delete two, move one
off a "drain", turn a leaning cone and add one; save, reopen and see it is still locked; clear and see every cone back;
set a car image and drive the outline through the tightest section.

## Done

- `app\tests\run.ps1` passes (ctest and qmltestrunner).
- A clean clone builds without the map images.
- The owner check passes.
- Nothing in the repo names the server's public address or the home network.
- Built on branch `part4-cones`, merged to `main` and pushed after a check of what is being pushed.
