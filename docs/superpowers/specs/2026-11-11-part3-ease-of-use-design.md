# Conestructor v1.0.0 part 3: easier to use

Date: 2026-11-11. Status: approved in conversation section by section; this document is for the owner's review.
Roadmap and part 1: `2026-11-10-v1-roadmap-and-part1-core-canvas-design.md`. Part 2:
`2026-11-10-part2-setup-and-track-files-design.md`; its plan adds its own decisions in
`docs/superpowers/plans/2026-11-10-part2-setup-and-track-files.md`.

## Why

The owner had teammates try the app without help. They thought it had potential, but:

- they did not read the list on the right as a setup procedure, so they did not know what to do first;
- they clicked a ruler or target tile and then clicked where it should go (as in SolidWorks) instead of dragging it,
  and nothing followed the mouse while dragging the ruler or a target;
- they did not know what the ruler and the targets are for, or where to put them;
- once building, they wanted to position elements by their gate nodes rather than only through the panel;
- nothing warned them when an element folded in on itself, which gives strange cones.

Part 3 fixes those, adds the two editing features from the owner's part 1 check that make building easier (turns up to
360° and a line tool), and clears the seven minors deferred from part 2's final review. The cone work the roadmap had
in part 3 moves to part 4.

## Decisions

| Topic | Decision |
|---|---|
| Scope | The roadmap's part 3 splits in two: part 3 "Easier to use" (this document) and part 4 "Cones". Team server becomes part 5 and release part 6. |
| Rulebook | Not applied to elements: people design however they like. Rule warnings are dropped from the roadmap. Cone spacing stays as it is: the FSAE rules give no cone spacing, and today's spacing (gates at most 10 m apart on a 4 m track) already meets the SCCA course-design guidance of gaps at least about 3 track widths. It becomes part 4's notch 3, "SAE standard". |
| Setup guidance | A coach card on the canvas for the current setup step, the matching checklist row highlighted. |
| Placing | Click a tile to pick it up (a ghost follows the mouse), click to put it down; dragging still works. The ruler takes two clicks, one per end, then asks for its real length on the spot. |
| Gate nodes | Open ends can be dragged: pivot and stretch about the other end when it is open, stretch only when it is joined. Nodes snap onto other open ends but do not join. |
| Folds | A ⚠ with the fix on an element whose inside edge crosses over itself. Never blocks. |
| Cones on the track | Post-processing leaves out any cone more than 15 cm inside any element's track band. |
| Turns | 0° to 360°. An element never joins itself. |
| Line tool | A new element type `line`: a straight row of standing cones, Length 20 m, Cone spacing 3 m; not driven, never joined; its cones come after the course. |
| Version | 0.4.0. Branch `part3-ease-of-use`. |

## Guided setup

### The coach card

While setup is not done, a card sits at the top centre of the canvas (above the error banner's place; the banner moves
below it while both show). It names the current step, the first one not done, and says why and what to do:

| Step | Card |
|---|---|
| 1 Photo | **Step 1 of 4: Lot photo.** Start with a birdseye photo of the lot, or use the blueprint to sketch without one. Buttons: *Load lot photo…* and *Use the blueprint*. |
| 2 Ruler (not placed) | **Step 2 of 4: Ruler.** The ruler sets the photo's scale. Click one end of something you know the length of, such as a parking-space line, then the other end. Button: *Place the ruler* (picks it up, as clicking its tile does). |
| 2 Ruler (placed, no length) | **Step 2 of 4: Ruler.** Now type how long that really is. The ruler's length box is open beside it; the card's button *Type its length* opens it again if it was closed. |
| 3 Origin | **Step 3 of 4: Origin.** Every cone is measured from Origin. Put it on something you can find on the real lot, such as the base of a light pole or a drain. Button: *Place Origin*. |
| 4 Direction | **Step 4 of 4: Direction.** x points from Origin toward Direction. Pick a second landmark well away from Origin; farther is more accurate. Button: *Place Direction*. |

- The checklist's title reads "Setup: start here" while setup is not done (it folds to "Setup ✓ (photo, ruler,
  targets)" once done, as in part 2). The current step's row is highlighted (a light border and brighter text); later
  steps are dimmed; done steps keep their tick.
- When all four are done the card goes. If a step comes undone later, the card comes back for it.
- The card does not cover the canvas's middle and passes clicks through outside itself.

### Click-to-place

Every tile (Ruler, Origin, Direction, and the track tiles Straight, Slalom, Chicane, Turn, Line) works two ways:

- **Click the tile** to pick it up. A see-through ghost follows the mouse over the canvas: a track piece as it would land
  (snapping to open ends as it does when dragged, Ctrl to skip), a target as its marker, the ruler as its first end. A
  click on the canvas puts it down. Esc, right-click, or clicking the tile again cancels. The status bar says what to
  do ("Click where Origin goes · Esc to cancel").
- **Drag the tile** onto the canvas, as before. The ruler and the targets now show the same ghost while dragged.
- **The ruler by clicks:** the first click sets one end, a rubber band follows the mouse, the second click sets the
  other end. Dragged from the tile, it lands centred where it is dropped, 160 screen pixels long, as before.
- **The ruler's length box:** once the ruler is put down (either way) without a real length, a small box opens beside
  it on the canvas, "Real length", focused, in display units. Enter sets the length (its own undo step, separate from
  placing the ruler, as today); Esc closes it, leaving the length unset. The panel's Real length field still works.
- While something is picked up, other canvas clicks do not select or drag anything.

## Gate nodes: pivot and stretch

- Only **open ends** (white rings) can be grabbed. Over one, the cursor becomes a crosshair and the ring grows a little.
  Joined ends (green dots) are not grabbed, so a joint is never pulled apart by accident. The rotate handle wins over a
  node; a node wins over the element's band.
- **The other end is open:** it stays where it is, and the dragged end goes to the mouse.
  - Straight and line: length and angle follow the mouse.
  - Turn, slalom, chicane: the element turns about its other end and the lead at the dragged end (Lead-in at the entry,
    Lead-out at the exit) stretches so the end lands on the mouse. When the mouse is closer than the element can reach
    with that lead at zero, the lead stays at zero and the element only turns to face the mouse.
- **The other end is joined:** the drag only stretches. The dragged end moves along the element's own direction at that
  end (the mouse is projected onto that line), the element keeps its rotation, and the chain stays joined.
- Lengths are kept within each setting's limits (a straight at least 1 m, leads 0 to 100 m).
- **Shift** turns in 15° steps (pivot only). **Snapping:** within snap reach of another open end, the dragged end lands
  exactly on it (Ctrl skips this), but they do not join: swinging cannot also make the two ends face each other.
  Joining still comes from moving an element onto an end. Two cones on one spot are merged by post-processing, and the
  driving order follows the arrows, so the cones come out right either way.
- One drag is one undo step: "Stretch Straight". The panel's fields follow during the drag.
- Works on the selected element or any other; dragging a node selects that element alone.

## Folds and cones on the track

### The fold check

An element **folds** when its centreline curves more tightly than half its track width somewhere: the inside edge of
the band then crosses over itself and cones land in strange places.

- Turn: Radius, or Exit radius when the radius changes, below half the track width.
- Chicane and slalom: the tightest curve of the centreline (worked out from its path) below half the track width.
- A folded element shows the ⚠ at its middle (the same sign as a backwards element). The tooltip names the fix:
  - turn: "Folds in on itself: make the radius at least 2 m, or the track narrower." (the figure is half the width, in
    display units);
  - chicane: "Folds in on itself: make the shift length longer or the sideways shift smaller, or the track narrower.";
  - slalom: "Folds in on itself: space the cones further apart or make the weave offset smaller, or the track
    narrower.";
  - an element that is both folded and backwards lists both lines.
- Advice only: placing, saving and post-processing still work.

### Cones on the driving surface

Post-processing leaves out every cone, a line's included, that lies more than 15 cm inside the track band of any
element, its own or another's (distance to that element's centreline less than half its track width minus 0.15 m).
Lines have no band, so they never remove cones.

- This cleans up folds, a 360° loop crossing its own leads, overlapping elements and crossings.
- Cones on a band's edge (every gate cone, slalom apex and pointer cone, turn and chicane cone) are kept: a track
  without folds or overlaps gets exactly the cones it gets today. The port check and the existing post-processing tests
  pin that.
- It runs after cones are made and before duplicates are merged and the order is worked out.

## Turns from 0° to 360°

- Turn angle limits become 0° to 360°. A 360° turn is a full loop: it leaves in the direction it entered, its exit lead
  continuing the entry's line. A skidpad figure 8 is two 360° turns, one Left and one Right, joined.
- Reverse, typed rotation, arrows and the rotate handle work for any angle.
- **An element never joins itself.** A loop with no leads has both ends on one spot; snapping, `joinTouching` and the
  file reader never join an element to itself.

## The line tool

- A new tile, **Line** ("Line: a straight row of cones, for walls and boundaries."), unlocked with the track tiles.
- Settings: **Length** (default 20 m, 1 m to 200 m) and **Cone spacing** (default 3 m, 0.5 m to 50 m). Cones are evenly
  spread along it at most that far apart, both ends included; all standing.
- Drawn as a thin light-grey line with a small dot where each cone will go, and a ring at each end. No band, no arrows.
- It is never driven: no arrows, no backwards ⚠, never joined, and other elements do not snap to it (its nodes snap onto
  other open ends' points like any node, without joining). Both its nodes always pivot and stretch.
- Select, drag, rotate, duplicate, delete, multi-select and box-select work as for other elements. In a multi-selection
  it shares only Length with straights (its spacing is its own setting).
- **Order:** line cones come after every course cone. Lines are taken one at a time, nearest first: each starts from
  whichever of its ends is nearer the last cone so far, and runs to its other end.
- In the `.cone` file its cones carry the line's element id; in `design` it is an element of type `"line"`.
  `docs/cone-format.md` mentions it.

## Part 2's deferred minors

1. **Hand-edited files.** Opening a `.cone` whose design has an element joined to itself, or an element with id
   `ruler`, `origin` or `direction`, is refused as damaged. Joined ends more than 5 cm apart are quietly unjoined on open.
2. **Backup after Don't save.** Whenever the backup is deleted (Don't save, a save, Discard), the app forgets what it last
   backed up, so a still-unsaved track (after a cancelled or refused Open) is backed up again at the next 2-minute tick.
3. **Command line.** A relative path on the command line is made absolute before it is opened and stored.
4. **Arrows.** Each element draws all its arrows as one shape instead of one item per chevron. A window test drags one
   element of a 40-element course and checks the frames keep up (a time budget per move, set from a measurement on the
   owner's machine during the build).
5. **Long names.** The "Save changes to <name>?" question wraps a long name instead of cutting it off.
6. **Save As** starts in the open track's folder with its name filled in (Untitled starts in the last folder used).
7. **Unreadable backup.** A backup that cannot be read shows "The backup couldn't be read and has been removed." once and
   is deleted, so it is not offered again.

## Code

| Piece | Job |
|---|---|
| `logic/elements.mjs` | `line` type (props, geometry, cones); turn angle to 360°; `folds(el)` → fold reasons; tightest curve of a path. |
| `logic/nodes.mjs` (new) | Pivot and stretch: where an element goes and what its length or lead becomes when one end is dragged to a point, for every type, free or with the other end joined; 15° steps. |
| `logic/postprocess.mjs` | Leaves out cones on another band; line cones after the course, nearest first. |
| `logic/snapping.mjs` | Never joins an element to itself; lines never join; node snapping (nearest open end's point). |
| `logic/commands.mjs` | `stretch` command (an element's place and one setting together, one step, named "Stretch X"). |
| `logic/conefile.mjs` | Refuses self-joins and reserved ids; unjoins joined ends that are apart. |
| `logic/setup.mjs` | The current step and its card text. |
| `TrackStore.qml` | Fold warnings beside `backwardIds`. |
| `CanvasView.qml` | One "placing" state for drag and click (ghost for every kind; the ruler's two clicks); node hover and drag; Esc. |
| `CoachCard.qml` (new), `RulerLengthBox.qml` (new) | The card; the length box beside the ruler. |
| `SetupChecklist.qml`, `PaletteTile.qml`, `ElementPalette.qml` | Highlighted current step; tiles pick up on click; the Line tile. |
| `ElementView.qml` | Arrows as one shape; fold ⚠ and tooltip text; line drawing; node hover. |
| `Main.qml`, `main.cpp`, `TrackFile` | Minors 2, 3, 5, 6, 7. |

## Testing

Test-first, as in parts 1 and 2. `app\tests\run.ps1` runs ctest, then qmltestrunner.

- **Logic (qmltestrunner):**
  - nodes: for each type, free and with the other end joined, the dragged end lands on the point (or on the projection
    when stretching only), the other end does not move, limits hold, Shift steps 15°, a mouse too close gives a zero lead;
  - folds: each type folds just past its threshold and not at it; the default elements do not fold;
  - cones on the track: a folded turn, a 360° loop with leads, and two crossing straights lose the right cones; the demo
    track and the port-check track lose none;
  - 360° turns: ends, exit heading, Reverse keeps the footprint, no self-join from snapping or `joinTouching`;
  - line: cone count and spacing, standing, never joined, order after the course nearest first;
  - the `stretch` command and undo;
  - conefile: self-join and reserved ids refused; far-apart joins unjoined; a line round-trips;
  - setup: the current step and its card for every state, including ruler placed without a length.
- **C++ (Qt Test):** an unreadable backup is deleted; a relative command-line path becomes absolute.
- **Window (`tst_qmlload`, offscreen, real mouse and keys):** the coach card shows each step in turn and goes when setup
  is done; clicking each tile then the canvas places it, Esc cancels; the ruler's two clicks and its length box (Enter
  sets, Esc leaves it unset); dragging the ruler and a target shows a ghost; a node drag pivots a free straight and only
  stretches a joined one, one undo step; the fold ⚠ appears and its tooltip names the fix; a line is placed and its cones
  come last; a 360° turn; the long-name question wraps; Save As's starting folder; the 40-element drag timing.

**Owner check** (about 15 minutes): hand the app, unexplained, to a teammate who has not used it and watch whether the
coach card gets them through setup with clicks alone; then build a short course using gate nodes to line pieces up, a
360° turn and a figure 8, a wall with the line tool, fold a turn on purpose and read its ⚠, place cones and check the
fold's stray cones are gone and the wall's cones come last.

## Done

- `app\tests\run.ps1` passes (ctest and qmltestrunner).
- A clean clone builds without the map images.
- The owner check passes.
- Nothing in the repo names the server's public address or the home network.
- Built on branch `part3-ease-of-use`, merged to `main` and pushed after a check of what is being pushed.
