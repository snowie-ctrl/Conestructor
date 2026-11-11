# Conestructor v1 part 3 (easier to use) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app learnable without help: a coach card that walks through setup, tiles that place by clicking as well as dragging (the ruler by two clicks, then its length typed on the spot), gate nodes that pivot and stretch an element, a fold warning with stray cones left out, turns up to 360°, a line tool for walls, and part 2's seven deferred minors.

**Architecture:** Part 1 and 2's shape stays: the track is plain data in `TrackStore`, every edit is a pure command with snapshot undo (`logic/commands.mjs`), logic lives in tested `.mjs` modules and QML only draws and forwards input. New logic: a `line` element type, the fold check and tightest-curve maths in `elements.mjs`, leaving out cones on the driving surface and ordering line cones in `postprocess.mjs`, pivot-and-stretch maths in a new `nodes.mjs`, the current setup step and its card text in `setup.mjs`. `CanvasView` gets one placing state shared by dragging and clicking, and node dragging; two new QML files draw the coach card and the ruler's length box.

**Tech Stack:** Qt 6.11.1 (MSVC 2022 64-bit), Qt Quick / Controls (Fusion) / Shapes / Dialogs, CMake + Ninja, Qt Test (C++), qmltestrunner (QML/JS), PowerShell scripts in `app/tests`.

**Spec:** `docs/superpowers/specs/2026-11-11-part3-ease-of-use-design.md` (the roadmap is in `2026-11-10-v1-roadmap-and-part1-core-canvas-design.md`; part 2's spec and plan explain files, arrows, driving order and multi-select).

## Global Constraints

- The repo is public. Never write the team server's public subdomain or the home-network address into code, docs, tests or commit messages; examples use `<public host>`.
- The two satellite images (`app/assets/images/duckPondBirdeye.png`, `riverwindBirdeye.png`) stay gitignored and are bundled only when present at build time. A clean clone must build without them.
- Files use metres. Export frame: x from the Origin target toward the Direction target; y 90° to the left of x seen from above; headings in degrees counter-clockwise from +x.
- The `.cone` format stays version 1: `format`, `version`, `name`, `app`, `saved`, `units`, `axes`, `targets`, `cones`, `design`, `photo`, the photo last. A line is an element of type `"line"` in `design`; its cones carry its id.
- Photo bytes never enter the track object or its undo snapshots.
- The rulebook is not applied to elements: no rule warnings. The only ⚠s are "runs against the track" (part 2) and "folds in on itself" (this part). Nothing blocks placing, saving or post-processing.
- Cone placement for a track without folds or overlaps is unchanged: the port check (`tst_portcheck`) and the existing post-processing tests pass untouched.
- Version 0.4.0 from CMake; window title `Conestructor 0.4 — <name>`.
- Logic lives in pure JavaScript modules in `app/qml/logic/`, tested with qmltestrunner; QML only draws and forwards input; C++ services are QML singletons (`QML_ELEMENT`/`QML_SINGLETON`).
- `tst_qmlload` keeps `QTest::failOnWarning` in `init()`: any QML warning fails a test.
- Qt Quick gotchas from parts 1 and 2: don't name an id or property after an Item property used inside delegates (`palette`, `layer`, `state`, `data`, `children`); `FileDialog` has a final `result` property; a Repeater delegate rebuilt by its own handler must not touch its ids after emitting; Repeater delegates have no QObject parent (tests walk `childItems()`); a Fusion `Dialog` with a custom footer needs a fixed `implicitWidth`; a focused `PropField` does not refresh its text on value change; an item with `anchors` inside a Layout warns (wrap it in a Rectangle instead).
- Build: `powershell -NoProfile -File app\tests\build.ps1`; test: `powershell -NoProfile -File app\tests\run.ps1` (one QML file: `run.ps1 -NoCpp -Qml tst_nodes.qml`; one C++ test: `run.ps1 -NoQml -R tst_qmlload`). Qt 6.11.1 MSVC at `D:\allNewQT6\6.11.1\msvc2022_64`, CMake/Ninja under `D:\allNewQT6\Tools`.
- Work on branch `part3-ease-of-use`; merge to `main` and push only after the owner's check and a look at what is being pushed.
- Every commit message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (passed as a second `-m`).

## Decisions this plan adds to the spec

- **Node snapping happens only while pivoting without Shift.** A stretch-only drag (other end joined) moves the end along a line, and a Shift drag keeps a 15° angle, so neither can land exactly on another end; they do not snap.
- **Shift on a node drag** snaps the element's rotation to 15° steps counted from the Origin → Direction axis (from the screen's x axis before the targets exist), then stretches along that direction (the mouse projected onto it).
- **Too close:** when the mouse is nearer the fixed end than the dragged end can come, the stretched setting takes the value that brings the end closest and the element turns to face the mouse. For a straight, a line or a lead that runs straight away from the fixed end this is the setting's minimum (the spec's "the lead stays at zero"); for a hairpin's lead-out it is the lead length at which the end is nearest.
- **A line's spacing setting is `spacing`** (label "Cone spacing"), not the slalom's `coneSpacing`, so a slalom and a line never share it in a multi-selection. A line is picked (click, box, rotate handle) within 0.5 m of its centreline (`Elements.LINE_REACH`).
- **A hand-edited file's join to or from a line is quietly removed on open**, like joined ends more than 5 cm apart (`ConeFile.JOIN_SLACK`).
- **Folds:** a turn folds when its radius (or, when Changing, the smaller of Radius and Exit radius) is below half the track width and its angle is above 0; a slalom or chicane folds when the tightest circle through three consecutive points of its centreline (`Elements.tightestRadius`, cached with the geometry) is below half the track width. Straights and lines never fold.
- **Cones on the driving surface** are found with a bounding-box test per band before measuring distances, so a 40-element course stays quick to process.
- **The unreadable-backup check lives in QML** (`Main.qml`'s Restore handler), so it is tested in `tst_qmlload`, not in C++ as the spec's Testing section says. **The relative command-line path** is made absolute by `TrackFile.absolutePath`, called from `Main.start`; `main.cpp` does not change. It is tested in `tst_trackfile` and `tst_qmlload`.
- **The drag-timing budget** in `tst_qmlload` is measured during Task 6 (before and after the arrows change) and set to twice the measured time per move, rounded up to the next 10 ms; both measurements go in the commit message.
- **A tile press that moves less than the system drag distance before release is a click** (it picks the tile up); more is a drag (as before).
- **`tst_qmlload` gains a small `Loaded` helper** (load Main, find canvas and store, element lookup, metres → screen, drag, click) for the new window tests; existing tests are left as they are.

## Review Focus

1. **Undo while the ruler's length box is open** (Edit › Undo removes the ruler just placed): the box closes and does not come back on its own; no stray `setRuler` runs. Pinned in Task 8 (`tilesPlaceByClicking`).
2. **Typing a length in the box in the display units** (`18' 6"` with feet and inches; `abc`): `18' 6"` sets 5.6388 m and closes the box; `abc` turns the text red and keeps the box open with the ruler unscaled. Pinned in Task 8 (`tilesPlaceByClicking`).
3. **A node dragged onto its own element's other end** (closing a lead-less 360° loop, or folding a straight back on itself): it never snaps or joins to itself. Pinned in Task 4 (`test_nodesSnapOnlyOntoOtherOpenEnds`) and Task 1 (`test_aLoopNeverJoinsItself`).
4. **A line inside a multi-selection dragged near an open end** (or a straight dragged near a line's end): the group snap ignores line ends and the line never joins. Pinned in Task 2 (`test_aGroupWithALineSnapsOnlyByItsTrackEnds`).
5. **Switching tiles while one is picked up** (click Origin, then click Direction; click Direction again; Esc; right-click): only one thing is ever picked up, clicking the same tile again or Esc or right-click drops it, and nothing is placed until a canvas click. Pinned in Task 8 (`tilesPlaceByClicking`).

## File structure

```
app/CMakeLists.txt                     version 0.4.0; CoachCard.qml, RulerLengthBox.qml, logic/nodes.mjs
app/qml/logic/elements.mjs             turn angle to 360°; line type; reach(); tightestRadius, folds, foldAdvice
app/qml/logic/snapping.mjs             lines never join (findSnap, findGroupSnap, joinTouching)
app/qml/logic/postprocess.mjs          chains skip lines; removeOnTrack; appendLines (line cones after the course)
app/qml/logic/selection.mjs            boxHits uses Elements.reach
app/qml/logic/nodes.mjs                NEW: stretchKey, drag (pivot and stretch), snapPoint
app/qml/logic/commands.mjs             + stretch command ("Stretch Straight")
app/qml/logic/conefile.mjs             reserved ids and self-joins refused; far-apart joins and joins to lines removed
app/qml/logic/setup.mjs                + current(track), CARDS
app/qml/logic/conerows.mjs             comment only (part 4 owns density)
app/qml/TrackStore.qml                 foldedIds; backedUpText and deleteBackup() (minor 2)
app/qml/ElementView.qml                arrows and line dots as one shape each; line drawing; fold ⚠; hovered node ring
app/qml/CanvasView.qml                 placing by click or drag, ghosts, ruler two clicks, length box; nodes; fold tip text
app/qml/PaletteTile.qml                click picks up, drag places; picked-up border
app/qml/RulerLengthBox.qml             NEW: the "Real length" box beside a new ruler
app/qml/CoachCard.qml                  NEW: the current setup step's card
app/qml/SetupChecklist.qml             "Setup: start here"; current step highlighted, later steps dimmed; click hints
app/qml/Main.qml                       coach card; banner below it; minors 2, 5, 6, 7; start() makes the path absolute
app/qml/PreferencesDialog.qml          comment only
app/services/TrackFile.h/.cpp          + absolutePath, folderUrl, fileUrl
app/tests/qml/tst_elements.qml         360° turns, line, reach, folds
app/tests/qml/tst_snapping.qml         no self-join, lines never join
app/tests/qml/tst_postprocess.qml      line order, lines alone, cones on the track
app/tests/qml/tst_selection.qml        line shares Length; box picks a line
app/tests/qml/tst_nodes.qml            NEW: pivot and stretch
app/tests/qml/tst_commands.qml         figure 8; stretch
app/tests/qml/tst_conefile.qml         repairs; a line round-trips
app/tests/qml/tst_setup.qml            current step and cards
app/tests/tst_trackfile.cpp            absolutePath, folderUrl, fileUrl
app/tests/tst_qmlload.cpp              titles 0.4; Loaded helper; folds and lines; drag timing; nodes; click-to-place;
                                       coach card; minors 2, 3, 5, 6, 7
docs/cone-format.md                    line cones come after the course
README.md                              part 3 status
```

---

### Task 1: Turns up to 360°, never joined to themselves, version 0.4.0

**Files:**
- Modify: `app/qml/logic/elements.mjs:24` (comment) and `:47` (turn angle limit)
- Modify: `app/CMakeLists.txt:3` (version)
- Modify: `app/tests/tst_qmlload.cpp` (five window titles `0.3` → `0.4`)
- Test: `app/tests/qml/tst_elements.qml`, `app/tests/qml/tst_snapping.qml`, `app/tests/qml/tst_commands.qml`

**Interfaces:**
- Consumes: `Elements.clampProp`, `Elements.geometry`, `Elements.reversed`, `Elements.endsWorld`, `Snapping.findSnap`, `Snapping.joinTouching` (all existing).
- Produces: turn `angle` limits 0 to 360. Later tasks rely on 360° turns working with Reverse and never self-joining.

- [ ] **Step 1: Create the branch**

```bash
git checkout -b part3-ease-of-use
```

- [ ] **Step 2: Write the failing tests**

Add to `app/tests/qml/tst_elements.qml`, inside the `TestCase`:

```qml
    function test_aTurnGoesUpToAFullCircle() {
        const full = Elements.clampProp("turn", "angle", 360)
        compare(full.value, 360)
        verify(!full.clamped)
        compare(Elements.clampProp("turn", "angle", 400).value, 360)
    }

    function test_aFullLoopLeavesTheWayItCameIn() {
        const g = Elements.geometry("turn", Object.assign(Elements.defaults("turn"), { angle: 360 }))
        fuzzyCompare(g.ends.B.heading, 0, 1e-9)
        fuzzyCompare(g.ends.B.x - g.ends.A.x, 12, 1e-6)      // lead-in 6 m and lead-out 6 m along the entry line
        fuzzyCompare(g.ends.B.y - g.ends.A.y, 0, 1e-6)
    }

    function test_aFullLoopReversesInPlace() {
        const el = { id: "e1", type: "turn", x: 10, y: 20, rotation: 30,
                     props: Object.assign(Elements.defaults("turn"), { angle: 360, leadOut: 2 }), joins: { A: null, B: null } }
        const r = Object.assign({}, el, Elements.reversed(el))
        const before = Elements.endsWorld(el)
        const after = Elements.endsWorld(r)
        fuzzyCompare(after.A.x, before.B.x, 1e-6)
        fuzzyCompare(after.A.y, before.B.y, 1e-6)
        fuzzyCompare(after.B.x, before.A.x, 1e-6)
        fuzzyCompare(after.B.y, before.A.y, 1e-6)
    }
```

Add to `app/tests/qml/tst_snapping.qml`:

```qml
    // A full loop with no leads has both ends on one spot: it must never join itself.
    function test_aLoopNeverJoinsItself() {
        const loop = el("e1", "turn", { angle: 360, leadIn: 0, leadOut: 0 })
        const ends = Elements.endsWorld(loop)
        verify(Math.hypot(ends.A.x - ends.B.x, ends.A.y - ends.B.y) < 1e-6, "both ends on one spot")
        compare(Snapping.findSnap([loop], loop, 5), null)
        Snapping.joinTouching([loop], "e1")
        compare(loop.joins.A, null)
        compare(loop.joins.B, null)
    }
```

Add to `app/tests/qml/tst_commands.qml`:

```qml
    // A skidpad figure 8: two full loops, one each way, joined.
    function test_aFigureEightIsTwoJoinedLoops() {
        const s = new Commands.UndoStack()
        let t = Commands.emptyTrack()
        t = Commands.run(s, t, "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 })
        t = Commands.run(s, t, "add", { type: "turn", x: 30, y: 30, props: { angle: 360, leadOut: 0, radius: 9 } })
        t = Commands.run(s, t, "add", { type: "turn", x: 0, y: 0, props: { angle: 360, leadIn: 0, radius: 9, direction: "left" },
                                        snap: { ownEnd: "A", id: "e1", end: "B" } })
        compare(byId(t, "e1").joins.B.id, "e2")
        verify(endsMeet(t, "e1", "B", "e2", "A"))
        compare(byId(t, "e1").joins.A, null)
        compare(byId(t, "e2").joins.B, null)
    }
```

- [ ] **Step 3: Run them to see the limit test fail**

Run: `powershell -NoProfile -File app\tests\run.ps1 -NoCpp`
Expected: `test_aTurnGoesUpToAFullCircle` FAILS (`360` is clamped to `180`). The geometry, reverse, self-join and figure 8 tests already pass: they pin behaviour that must stay true.

- [ ] **Step 4: Raise the limit and set the version**

In `app/qml/logic/elements.mjs` replace line 24's comment and the turn's angle definition:

```js
// Physical limits only. The rulebook is not applied to elements: people design however they like (part 3).
```

```js
        { key: "angle", label: "Turn angle", kind: "angle", min: 0, max: 360 },
```

In `app/CMakeLists.txt`: `project(Conestructor VERSION 0.4.0 LANGUAGES CXX)`.

In `app/tests/tst_qmlload.cpp` replace every `Conestructor 0.3 \u2014` with `Conestructor 0.4 \u2014` (five places).

- [ ] **Step 5: Build and run everything**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`, `qml: N passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add app/qml/logic/elements.mjs app/CMakeLists.txt app/tests
git commit -m "Turns go up to 360° (a figure 8 is two joined loops); version 0.4.0" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The line element (logic)

**Files:**
- Modify: `app/qml/logic/elements.mjs` (type, settings, geometry, `reach`, `LINE_REACH`; `hitTest` and `rotateHandle` use `reach`)
- Modify: `app/qml/logic/snapping.mjs` (`findSnap`, `findGroupSnap`, `joinTouching` skip lines)
- Modify: `app/qml/logic/postprocess.mjs` (`chains` skips lines; `appendLines`; `run`)
- Modify: `app/qml/logic/selection.mjs` (`boxHits` uses `Elements.reach`)
- Test: `tst_elements.qml`, `tst_snapping.qml`, `tst_postprocess.qml`, `tst_selection.qml`

**Interfaces:**
- Consumes: Task 1's limits.
- Produces: `Elements.TYPES` gains `"line"` (the palette shows a fifth tile with no further change); `Elements.NAMES.line === "Line"`, `COLOURS.line === "#c8c8c8"`, `TIPS.line`; line props `{ length: 20, spacing: 3 }`; `Elements.LINE_REACH = 0.5`; `Elements.reach(el) -> number` (half the track width, or `LINE_REACH` for a line); `Post.appendLines(ordered, lines, groups) -> cone[]`.

- [ ] **Step 1: Write the failing tests**

`app/tests/qml/tst_elements.qml`:

```qml
    function test_aLineIsARowOfStandingCones() {
        compare(JSON.stringify(Elements.defaults("line")), JSON.stringify({ length: 20, spacing: 3 }))
        compare(Elements.NAMES.line, "Line")
        compare(Elements.TIPS.line, "Line: a straight row of cones, for walls and boundaries.")
        const g = Elements.geometry("line", Elements.defaults("line"))
        compare(g.cones.length, 8)                       // 20 m at most 3 m apart: 7 gaps of 2.857 m
        fuzzyCompare(g.cones[0].x, -10, 1e-9)
        fuzzyCompare(g.cones[7].x, 10, 1e-9)
        fuzzyCompare(g.cones[1].x - g.cones[0].x, 20 / 7, 1e-9)
        verify(g.cones.every(c => c.type === "standing" && c.y === 0 && c.heading === 0))
        compare(Elements.geometry("line", { length: 21, spacing: 3 }).cones.length, 8)   // exactly 3 m apart
        fuzzyCompare(g.ends.A.x, -10, 1e-9)
        compare(g.ends.A.heading, 180)
        compare(g.ends.B.heading, 0)
    }

    function test_aLineIsPickedWithinHalfAMetre() {
        const line = { id: "e1", type: "line", x: 0, y: 0, rotation: 0, props: Elements.defaults("line"),
                       joins: { A: null, B: null } }
        compare(Elements.hitTest([line], { x: 3, y: 0.4 }, 0), "e1")
        compare(Elements.hitTest([line], { x: 3, y: 0.6 }, 0), "")
        compare(Elements.reach(line), 0.5)
        compare(Elements.reach({ type: "straight", props: { trackWidth: 4 } }), 2)
        const handle = Elements.rotateHandle(line, 1)
        fuzzyCompare(handle.y, -1.5, 1e-9)               // half a metre of reach plus the 1 m asked for
    }
```

`app/tests/qml/tst_snapping.qml`:

```qml
    function test_linesNeverJoin() {
        const line = el("e1", "line", {}, 0, 0, 0)               // ends at x -10 and 10
        const straight = el("e2", "straight", {}, 20.5, 0, 0)    // its A end half a metre from the line's B end
        compare(Snapping.findSnap([line, straight], straight, 5), null)
        compare(Snapping.findSnap([line, straight], line, 5), null)
        const touching = el("e3", "straight", {}, 20, 0, 0)      // its A end on the line's B end
        const list = [line, touching]
        Snapping.joinTouching(list, "e3")
        Snapping.joinTouching(list, "e1")
        compare(touching.joins.A, null)
        compare(line.joins.B, null)
    }

    // Review focus 4: a group with a line in it snaps only by its track elements' ends, and never onto a line.
    function test_aGroupWithALineSnapsOnlyByItsTrackEnds() {
        const outside = el("e1", "straight", {}, 0, 0, 0)         // B end at x 10
        const line = el("e2", "line", {}, 20.3, 0, 0)             // A end at x 10.3
        const far = el("e3", "straight", {}, 0, 50, 0)
        compare(Snapping.findGroupSnap([outside, line, far], [line, far], 5), null)
        const wall = el("e4", "line", {}, 0, 0, 0)                // B end at x 10
        const near = el("e5", "straight", {}, 20.3, 0, 0)         // A end at x 10.3
        compare(Snapping.findGroupSnap([wall, near], [near], 5), null)
    }
```

`app/tests/qml/tst_postprocess.qml`:

```qml
    function test_lineConesComeAfterTheCourseNearestFirst() {
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],                                          // course: x 0 to 20
            ["add", { type: "line", x: 60, y: 20, props: { length: 10, spacing: 5 } }],          // far wall: x 55 to 65
            ["add", { type: "line", x: 30, y: 5, rotation: 180, props: { length: 10, spacing: 5 } }]  // near: A x 35, B x 25
        ]))
        const cones = Post.run(t).canvasCones
        compare(cones.length, 12)
        verify(cones.slice(0, 6).every(c => c.element === "e1"), "the course first")
        // The near wall next, from its end nearer the course's last cone (x 25 is nearer x 20 than x 35 is).
        compare(cones[6].element, "e3")
        fuzzyCompare(cones[6].x, 25, 1e-9)
        fuzzyCompare(cones[8].x, 35, 1e-9)
        // Then the far wall, from its end nearer x 35.
        compare(cones[9].element, "e2")
        fuzzyCompare(cones[9].x, 55, 1e-9)
    }

    function test_linesAloneStillProcess() {
        const t = build(scale().concat(targets(), [["add", { type: "line", x: 10, y: 5 }]]))
        const r = Post.run(t)
        verify(!r.error, r.error ? r.error.message : "")
        compare(r.cones.length, 8)
        compare(JSON.stringify(Post.backwards(t.elements)), "[]")
        compare(JSON.stringify(Post.chains(t.elements)), "[]")
    }
```

`app/tests/qml/tst_selection.qml`:

```qml
    function test_aLineAndAStraightShareOnlyTheLength() {
        compare(keys(Selection.sharedProps([el("e1", "straight"), el("e2", "line")])), "length")
        compare(keys(Selection.sharedProps([el("e1", "turn"), el("e2", "line")])), "")
    }

    function test_theBoxPicksALineWithinHalfAMetre() {
        const line = el("e1", "line")
        compare(JSON.stringify(Selection.boxHits([line], { x: -1, y: 0.4 }, { x: 1, y: 1 })), JSON.stringify(["e1"]))
        compare(JSON.stringify(Selection.boxHits([line], { x: -1, y: 0.6 }, { x: 1, y: 1 })), "[]")
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\run.ps1 -NoCpp`
Expected: the new tests FAIL (`defaults("line")` is undefined; `geometry("line")` throws).

- [ ] **Step 3: Add the line to `elements.mjs`**

Replace the four tables at the top and add the line's settings and defaults:

```js
export const TYPES = ["straight", "slalom", "chicane", "turn", "line"]
export const NAMES = { straight: "Straight", slalom: "Slalom", chicane: "Chicane", turn: "Turn", line: "Line" }
export const COLOURS = { straight: "#b603fc", slalom: "#c9691a", chicane: "#1a46c9", turn: "#34eb7a", line: "#c8c8c8" }
export const TIPS = {
    straight: "Straight: a run between two rows of cones.",
    slalom: "Slalom: a line of cones to weave through.",
    chicane: "Chicane: a sideways step in the track.",
    turn: "Turn: anything from a sweeper to a hairpin.",
    line: "Line: a straight row of cones, for walls and boundaries."
}
```

In `PROPS`, after `turn: [...]`:

```js
    ,
    // A line is not driven: no track width, no leads. Its spacing is its own setting, never shared with a slalom's.
    line: [
        { key: "length", label: "Length", kind: "length", min: 1, max: 200 },
        { key: "spacing", label: "Cone spacing", kind: "length", min: 0.5, max: 50 }
    ]
```

In `DEFAULTS`: `line: { length: 20, spacing: 3 }`.

After `function turn(p) {...}`:

```js
// A straight row of standing cones, evenly spread at most `spacing` apart, both ends included.
function line(p) {
    const half = p.length / 2
    const gaps = Math.max(1, Math.ceil(p.length / p.spacing - 1e-9))
    const cones = []
    for (let i = 0; i <= gaps; i++)
        cones.push({ x: -half + p.length * i / gaps, y: 0, heading: 0, type: "standing" })
    return { path: [{ x: -half, y: 0 }, { x: half, y: 0 }],
             ends: { A: { x: -half, y: 0, heading: 180 }, B: { x: half, y: 0, heading: 0 } }, cones: cones }
}
```

`const BUILD = { straight: straight, slalom: slalom, chicane: chicane, turn: turn, line: line }`

After `pointSegmentDistance`:

```js
// How far from its centreline an element can be picked: half its track width, or half a metre for a line (which has
// no band).
export const LINE_REACH = 0.5

export function reach(el) {
    return el.type === "line" ? LINE_REACH : el.props.trackWidth / 2
}
```

In `hitTest`: `if (distanceToPath(el, p) <= reach(el) + tolerance)`.
In `rotateHandle`: `return toWorld(el, { x: 0, y: -(span + reach(el) + extraMetres) })` with the loop variable renamed from `reach` to `span`:

```js
export function rotateHandle(el, extraMetres) {
    const g = geometry(el.type, el.props)
    let span = 0
    for (const p of g.path)
        span = Math.max(span, Math.abs(p.y))
    return toWorld(el, { x: 0, y: -(span + reach(el) + extraMetres) })
}
```

- [ ] **Step 4: Lines never join (`snapping.mjs`)**

In `findSnap`, first line of the body: `if (moving.type === "line") return null`, and in the loop `if (el.id === moving.id || el.type === "line") continue`.

In `joinTouching`, after `const self = byId(elements, id)`: `if (self.type === "line") return`, and in the inner loop `if (el.id === id || el.type === "line" || self.joins[ownEnd]) continue`.

In `findGroupSnap`: `for (const g of group) { if (g.type === "line") continue; ...` and in the target loop `if (ids.indexOf(el.id) >= 0 || el.type === "line") continue`.

Update the file's header comment: `// Lines (walls and boundaries) are never joined: nothing snaps to them and they snap to nothing.`

- [ ] **Step 5: Line cones after the course (`postprocess.mjs`)**

In `chains`, both loops skip lines:

```js
    for (const el of elements) {
        if (el.type === "line" || visited.indexOf(el.id) >= 0 || (el.joins.A !== null && el.joins.B !== null))
            continue
```

```js
    for (const el of elements) {
        if (el.type === "line" || visited.indexOf(el.id) >= 0)
            continue
```

After `stitch`:

```js
// Line cones (walls and boundaries) after the course: one line at a time, the nearest first, each from whichever of
// its ends is nearer the last cone so far.
export function appendLines(ordered, lines, groups) {
    const rows = lines.map(l => groups.find(g => g.id === l.id).cones).filter(r => r.length > 0)
    let out = ordered.slice()
    while (rows.length > 0) {
        const last = out.length > 0 ? out[out.length - 1] : null
        let best = 0
        let flip = false
        if (last) {
            let bestDistance = Infinity
            rows.forEach((r, i) => {
                const toStart = distance(last, r[0])
                const toEnd = distance(last, r[r.length - 1])
                if (toStart < bestDistance) {
                    bestDistance = toStart
                    best = i
                    flip = false
                }
                if (toEnd < bestDistance) {
                    bestDistance = toEnd
                    best = i
                    flip = true
                }
            })
        }
        const row = rows.splice(best, 1)[0]
        out = out.concat(flip ? row.slice().reverse() : row)
    }
    return out
}
```

In `run`, replace `const ordered = stitch(buildChains(track.elements, groups))` with:

```js
    const course = stitch(buildChains(track.elements, groups))
    const ordered = appendLines(course, track.elements.filter(e => e.type === "line"), groups)
```

- [ ] **Step 6: The box picks lines (`selection.mjs`)**

In `boxHits`: `const h = Elements.reach(el)`.

- [ ] **Step 7: Run everything**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: all pass. If an existing test iterates `Elements.TYPES` and assumes a track width (for example a palette count in `tst_qmlload`), update it to expect the fifth tile; say so in the commit message.

- [ ] **Step 8: Commit**

```bash
git add app/qml/logic app/tests
git commit -m "Line element: a straight row of standing cones, never joined, its cones after the course nearest first" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The fold check and cones on the driving surface

**Files:**
- Modify: `app/qml/logic/elements.mjs` (`tightestRadius`, `geometry` caches it, `folds`, `foldAdvice`)
- Modify: `app/qml/logic/postprocess.mjs` (`ON_TRACK_METRES`, `onTrack`, `removeOnTrack`, `run`)
- Test: `tst_elements.qml`, `tst_postprocess.qml`

**Interfaces:**
- Consumes: Task 2's `line` type (lines never fold and have no band).
- Produces: `Elements.tightestRadius(path) -> number` (Infinity for a straight path); `Elements.folds(el) -> bool`; `Elements.foldAdvice(el, formatLength) -> string` (`""` when it does not fold; `formatLength(metres) -> string`); `Post.ON_TRACK_METRES = 0.15`; `Post.removeOnTrack(groups, elements)` (changes `groups`).

- [ ] **Step 1: Write the failing tests**

`app/tests/qml/tst_elements.qml`:

```qml
    function typed(type, props) {
        return { id: "e1", type: type, x: 0, y: 0, rotation: 0, props: Object.assign(Elements.defaults(type), props || {}),
                 joins: { A: null, B: null } }
    }

    function test_tightestRadiusOfACircle() {
        const points = []
        for (let i = 0; i <= 12; i++)
            points.push({ x: 5 * Math.cos(i * Math.PI / 6), y: 5 * Math.sin(i * Math.PI / 6) })
        fuzzyCompare(Elements.tightestRadius(points), 5, 1e-9)
        // Repeated points (an empty lead) are skipped; points in a line are no curve at all.
        compare(Elements.tightestRadius([{ x: 0, y: 0 }, { x: 0, y: 0 }, { x: 1, y: 0 }, { x: 2, y: 0 }]), Infinity)
    }

    function test_noDefaultElementFolds() {
        for (const type of Elements.TYPES)
            verify(!Elements.folds(typed(type)), type)
        verify(!Elements.folds(typed("straight", { trackWidth: 20 })))
    }

    function test_aTurnFoldsBelowHalfItsWidth() {
        verify(!Elements.folds(typed("turn", { radius: 2 })), "at half the width it does not fold")
        verify(Elements.folds(typed("turn", { radius: 1.9 })))
        verify(Elements.folds(typed("turn", { radiusType: "changing", radius: 6, exitRadius: 1.5 })))
        verify(!Elements.folds(typed("turn", { radiusType: "constant", radius: 6, exitRadius: 1.5 })), "exit radius unused")
        verify(!Elements.folds(typed("turn", { radius: 1, angle: 0 })), "no turn, no fold")
    }

    function test_tightChicanesAndSlalomsFold() {
        verify(Elements.folds(typed("chicane", { shiftLength: 2, shift: 6 })))
        verify(Elements.folds(typed("slalom", { coneSpacing: 2, weaveOffset: 3 })))
    }

    function test_foldAdviceNamesTheFix() {
        const metres = m => m.toFixed(1) + " m"
        compare(Elements.foldAdvice(typed("turn", { radius: 1 }), metres),
                "Folds in on itself: make the radius at least 2.0 m, or the track narrower.")
        compare(Elements.foldAdvice(typed("chicane", { shiftLength: 2 }), metres),
                "Folds in on itself: make the shift length longer or the sideways shift smaller, or the track narrower.")
        compare(Elements.foldAdvice(typed("slalom", { coneSpacing: 2, weaveOffset: 3 }), metres),
                "Folds in on itself: space the cones further apart or make the weave offset smaller, or the track narrower.")
        compare(Elements.foldAdvice(typed("turn"), metres), "")
    }
```

`app/tests/qml/tst_postprocess.qml`, with two more imports at the top:

```qml
import "../../qml/logic/demo.mjs" as Demo
import "fixtures/sampletrack.mjs" as Sample
```

```qml
    function total(groups) {
        return groups.reduce((n, g) => n + g.cones.length, 0)
    }

    function test_crossingStraightsLoseTheConesOnEachOther() {
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 20, y: 20 }],
            ["add", { type: "straight", x: 20, y: 20, rotation: 90 }]
        ]))
        const groups = Post.coneGroups(t.elements)
        compare(total(groups), 12)
        Post.removeOnTrack(groups, t.elements)
        compare(total(groups), 8)
        verify(groups.every(g => g.cones.every(c => Math.hypot(c.x - 20, c.y - 20) > 3)), "the middle pairs went")
        compare(Post.run(t).cones.length, 8)
    }

    function test_aLoopOverItsLeadsLosesTheConesItRunsOver() {
        const t = build(scale().concat(targets(), [["add", { type: "turn", x: 20, y: 20, props: { angle: 360 } }]]))
        const groups = Post.coneGroups(t.elements)
        const before = total(groups)
        Post.removeOnTrack(groups, t.elements)
        verify(total(groups) < before, before + " -> " + total(groups))
    }

    function test_aLineAcrossTheTrackLosesItsConesOnIt() {
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 20, y: 20 }],
            ["add", { type: "line", x: 20, y: 20, rotation: 90, props: { length: 10, spacing: 1 } }]
        ]))
        const groups = Post.coneGroups(t.elements)
        Post.removeOnTrack(groups, t.elements)
        const wall = groups.find(g => g.id === "e2").cones
        // 11 cones a metre apart across the track: those at 19, 20 and 21 go; 18 and 22 sit on its edges and stay.
        compare(wall.length, 8)
        verify(wall.every(c => Math.abs(c.y - 20) >= 1.85), JSON.stringify(wall.map(c => c.y)))
        compare(groups.find(g => g.id === "e1").cones.length, 6, "a line has no band: it removes nothing")
    }

    function test_aCleanTrackLosesNothing() {
        for (const t of [Demo.demoTrack(), Sample.track()]) {
            const groups = Post.coneGroups(t.elements)
            const before = total(groups)
            Post.removeOnTrack(groups, t.elements)
            compare(total(groups), before)
        }
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\run.ps1 -NoCpp`
Expected: FAIL (`Elements.tightestRadius`, `Elements.folds`, `Post.removeOnTrack` are not functions).

- [ ] **Step 3: Fold check in `elements.mjs`**

After `function line(p) {...}` and before `const BUILD`:

```js
// The radius of the circle through three points; Infinity when they lie in a line.
function circumradius(a, b, c) {
    const ab = Math.hypot(b.x - a.x, b.y - a.y)
    const bc = Math.hypot(c.x - b.x, c.y - b.y)
    const ca = Math.hypot(a.x - c.x, a.y - c.y)
    const cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    if (Math.abs(cross) < 1e-12)
        return Infinity
    return ab * bc * ca / (2 * Math.abs(cross))
}

// The tightest curve along a centreline: the smallest circle through three consecutive points. Repeated points (a
// lead of no length) are skipped.
export function tightestRadius(path) {
    const points = path.filter((p, i) => i === 0 || Math.hypot(p.x - path[i - 1].x, p.y - path[i - 1].y) > 1e-9)
    let r = Infinity
    for (let i = 1; i < points.length - 1; i++)
        r = Math.min(r, circumradius(points[i - 1], points[i], points[i + 1]))
    return r
}
```

In `geometry`, cache the tightest curve with the rest:

```js
    if (!g) {
        g = BUILD[type](props)
        g.tightest = tightestRadius(g.path)
```

After `geometry`:

```js
// ---- Folding ----

// Whether the element's centreline curves more tightly than half its track width somewhere, so the inside edge of its
// band crosses over itself and its cones land in strange places. Advice only: it never blocks anything.
export function folds(el) {
    if (el.type === "straight" || el.type === "line")
        return false
    const half = el.props.trackWidth / 2
    if (el.type === "turn") {
        const p = el.props
        if (!(p.angle > 0))
            return false
        const r = p.radiusType === "changing" ? Math.min(p.radius, p.exitRadius) : p.radius
        return r < half
    }
    return geometry(el.type, el.props).tightest < half
}

// What to change so a folded element stops folding ("" when it does not fold). `formatLength(metres)` writes a length
// in the display units.
export function foldAdvice(el, formatLength) {
    if (!folds(el))
        return ""
    if (el.type === "turn")
        return "Folds in on itself: make the radius at least " + formatLength(el.props.trackWidth / 2)
               + ", or the track narrower."
    if (el.type === "chicane")
        return "Folds in on itself: make the shift length longer or the sideways shift smaller, or the track narrower."
    return "Folds in on itself: space the cones further apart or make the weave offset smaller, or the track narrower."
}
```

- [ ] **Step 4: Cones on the driving surface in `postprocess.mjs`**

After `coneGroups`:

```js
// A cone more than this far inside any element's band is on the driving surface and is left out.
export const ON_TRACK_METRES = 0.15

// The bands of the driven elements (lines have none): centreline in canvas metres, half the track width, and a box
// around the band for a quick first test.
function bands(elements) {
    return elements.filter(e => e.type !== "line").map(e => {
        const path = Elements.pathWorld(e)
        const half = e.props.trackWidth / 2
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
        for (const p of path) {
            x0 = Math.min(x0, p.x); y0 = Math.min(y0, p.y)
            x1 = Math.max(x1, p.x); y1 = Math.max(y1, p.y)
        }
        return { path: path, half: half, x0: x0 - half, y0: y0 - half, x1: x1 + half, y1: y1 + half }
    })
}

function onTrack(cone, band) {
    if (cone.x < band.x0 || cone.x > band.x1 || cone.y < band.y0 || cone.y > band.y1)
        return false
    const limit = band.half - ON_TRACK_METRES
    for (let i = 1; i < band.path.length; i++)
        if (Elements.pointSegmentDistance(cone, band.path[i - 1], band.path[i]) < limit)
            return true
    return false
}

// Leaves out every cone (a line's too) on the driving surface of any element, its own or another's: folds, a loop over
// its own leads, overlaps and crossings. Cones on a band's edge stay. Changes `groups`.
export function removeOnTrack(groups, elements) {
    const list = bands(elements)
    for (const g of groups)
        g.cones = g.cones.filter(c => !list.some(b => onTrack(c, b)))
}
```

In `run`, after `const groups = coneGroups(track.elements)`:

```js
    removeOnTrack(groups, track.elements)
```

Update the file's header comment: `// Cones on another element's driving surface are left out (part 3), then duplicates at joins are merged.`

- [ ] **Step 5: Run everything**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: all pass, `tst_portcheck` included. If the port check or `test_aCleanTrackLosesNothing` fails, the sample or demo track has a cone more than 15 cm inside a band: stop and report which cone and band (it would mean the spec's "a clean track loses nothing" does not hold).

- [ ] **Step 6: Commit**

```bash
git add app/qml/logic app/tests/qml
git commit -m "Fold check (tightest curve below half the track width) and cones on the driving surface left out" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Pivot and stretch (`nodes.mjs`) and the `stretch` command

**Files:**
- Create: `app/qml/logic/nodes.mjs`
- Modify: `app/CMakeLists.txt` (add `qml/logic/nodes.mjs` after `qml/logic/conefile.mjs`)
- Modify: `app/qml/logic/commands.mjs` (`stretch` command and its label)
- Test: create `app/tests/qml/tst_nodes.qml`; add to `app/tests/qml/tst_commands.qml`

**Interfaces:**
- Consumes: `Elements.geometry`, `endsWorld`, `PROPS`, `clamp`, `normalizeAngle`.
- Produces:
  - `Nodes.stretchKey(el, end) -> "length" | "leadIn" | "leadOut"`
  - `Nodes.drag(el, end, point, opts) -> { x, y, rotation, key, value }`; `opts = { pivot: bool, step: number (0 or 15), frameTheta: number }`; `point` in canvas metres.
  - `Nodes.snapPoint(elements, id, point, maxDistance) -> { x, y } | null`
  - command `stretch` with args `{ id, x, y, rotation, key, value, mergeKey }`, label `"Stretch " + type name`.

- [ ] **Step 1: Write the failing tests**

Create `app/tests/qml/tst_nodes.qml`:

```qml
import QtQuick
import QtTest
import "../../qml/logic/elements.mjs" as Elements
import "../../qml/logic/nodes.mjs" as Nodes

TestCase {
    name: "Nodes"

    function el(id, type, props, x, y, rotation) {
        return { id: id, type: type, x: x || 0, y: y || 0, rotation: rotation || 0,
                 props: Object.assign(Elements.defaults(type), props || {}), joins: { A: null, B: null } }
    }

    // The element with a drag's result applied.
    function apply(e, r) {
        const props = Object.assign({}, e.props)
        props[r.key] = r.value
        return Object.assign({}, e, { x: r.x, y: r.y, rotation: r.rotation, props: props })
    }

    function near(p, q) {
        return Math.hypot(p.x - q.x, p.y - q.y) < 1e-6
    }

    function unit(degrees) {
        return { x: Math.cos(degrees * Math.PI / 180), y: Math.sin(degrees * Math.PI / 180) }
    }

    function test_whichSettingStretches() {
        compare(Nodes.stretchKey(el("e1", "straight"), "A"), "length")
        compare(Nodes.stretchKey(el("e1", "line"), "B"), "length")
        compare(Nodes.stretchKey(el("e1", "turn"), "A"), "leadIn")
        compare(Nodes.stretchKey(el("e1", "slalom"), "B"), "leadOut")
    }

    function test_aFreeStraightPivotsAboutItsOtherEnd() {
        const s = el("e1", "straight")                         // A at (-10, 0), B at (10, 0)
        const r = Nodes.drag(s, "B", { x: -10, y: 15 }, { pivot: true, step: 0 })
        const after = Elements.endsWorld(apply(s, r))
        verify(near(after.A, { x: -10, y: 0 }), JSON.stringify(after.A))
        verify(near(after.B, { x: -10, y: 15 }), JSON.stringify(after.B))
        compare(r.key, "length")
        fuzzyCompare(r.value, 15, 1e-9)
        fuzzyCompare(r.rotation, 90, 1e-9)
        const back = Nodes.drag(s, "A", { x: 10, y: -5 }, { pivot: true, step: 0 })
        const turned = Elements.endsWorld(apply(s, back))
        verify(near(turned.B, { x: 10, y: 0 }))
        verify(near(turned.A, { x: 10, y: -5 }))
    }

    function test_everyTypeSwingsRoundItsOtherEnd_data() {
        return [
            { tag: "turn exit", type: "turn", end: "B" },
            { tag: "turn entry", type: "turn", end: "A" },
            { tag: "slalom exit", type: "slalom", end: "B" },
            { tag: "chicane entry", type: "chicane", end: "A" },
            { tag: "line exit", type: "line", end: "B" }
        ]
    }

    function test_everyTypeSwingsRoundItsOtherEnd(row) {
        const e = el("e1", row.type, {}, 5, 5, 10)
        const other = row.end === "A" ? "B" : "A"
        const before = Elements.endsWorld(e)
        // Swing the dragged end 20 degrees about the other end, and pull it 3 m further out.
        const arm = { x: before[row.end].x - before[other].x, y: before[row.end].y - before[other].y }
        const length = Math.hypot(arm.x, arm.y)
        const k = (length + 3) / length
        const c = Math.cos(20 * Math.PI / 180)
        const s = Math.sin(20 * Math.PI / 180)
        const point = { x: before[other].x + (arm.x * c - arm.y * s) * k, y: before[other].y + (arm.x * s + arm.y * c) * k }
        const r = Nodes.drag(e, row.end, point, { pivot: true, step: 0 })
        const after = Elements.endsWorld(apply(e, r))
        verify(near(after[other], before[other]), "the other end stays")
        verify(near(after[row.end], point), JSON.stringify(after[row.end]) + " vs " + JSON.stringify(point))
        verify(r.value > e.props[r.key], "it stretched")
    }

    function test_aMouseTooCloseLeavesTheShortestElementFacingIt() {
        const s = el("e1", "straight")
        const r = Nodes.drag(s, "B", { x: -10, y: -0.3 }, { pivot: true, step: 0 })
        compare(r.value, 1)
        fuzzyCompare(r.rotation, -90, 1e-9)
        verify(near(Elements.endsWorld(apply(s, r)).A, { x: -10, y: 0 }))
    }

    function test_aJoinedOtherEndOnlyStretches() {
        const t = el("e1", "turn")
        const before = Elements.endsWorld(t)
        const u = unit(before.B.heading)
        // 4 m further along the exit and 3 m off to the side: only the 4 m counts.
        const point = { x: before.B.x + 4 * u.x - 3 * u.y, y: before.B.y + 4 * u.y + 3 * u.x }
        const r = Nodes.drag(t, "B", point, { pivot: false, step: 0 })
        compare(r.rotation, t.rotation)
        fuzzyCompare(r.value, 10, 1e-9)
        const after = Elements.endsWorld(apply(t, r))
        verify(near(after.A, before.A))
        verify(near(after.B, { x: before.B.x + 4 * u.x, y: before.B.y + 4 * u.y }))
    }

    function test_settingsStayWithinTheirLimits() {
        compare(Nodes.drag(el("e1", "straight"), "B", { x: 300, y: 0 }, { pivot: true, step: 0 }).value, 200)
        const t = el("e2", "turn")
        const ends = Elements.endsWorld(t)
        const u = unit(ends.B.heading)
        // Pulled back 10 m past where its lead-out starts: the lead-out stops at zero.
        compare(Nodes.drag(t, "B", { x: ends.B.x - 10 * u.x, y: ends.B.y - 10 * u.y }, { pivot: false, step: 0 }).value, 0)
    }

    function test_shiftTurnsInFifteenDegreeSteps() {
        const s = el("e1", "straight")                         // A at (-10, 0)
        const point = { x: -10 + 10 * Math.cos(37 * Math.PI / 180), y: 10 * Math.sin(37 * Math.PI / 180) }
        const r = Nodes.drag(s, "B", point, { pivot: true, step: 15, frameTheta: 0 })
        fuzzyCompare(r.rotation, 30, 1e-9)
        fuzzyCompare(r.value, 10 * Math.cos(7 * Math.PI / 180), 1e-9)   // the mouse projected onto the 30° line
        verify(near(Elements.endsWorld(apply(s, r)).A, { x: -10, y: 0 }))
        // Steps count from the Origin -> Direction axis.
        fuzzyCompare(Nodes.drag(s, "B", point, { pivot: true, step: 15, frameTheta: 10 }).rotation, 40, 1e-9)
    }

    // Review focus 3: a node never snaps onto its own element's other end, a joined end, or nothing in reach.
    function test_nodesSnapOnlyOntoOtherOpenEnds() {
        const a = el("e1", "straight")                         // ends at x -10 and 10
        const b = el("e2", "straight", {}, 30, 0, 0)           // ends at x 20 and 40
        const wall = el("e3", "line", {}, 0, 20, 0)            // ends at (-10, 20) and (10, 20)
        const loop = el("e4", "turn", { angle: 360, leadIn: 0, leadOut: 0 }, 0, -40, 0)
        const list = [a, b, wall, loop]
        compare(JSON.stringify(Nodes.snapPoint(list, "e1", { x: 20.5, y: 0.3 }, 1)), JSON.stringify({ x: 20, y: 0 }))
        compare(Nodes.snapPoint(list, "e1", { x: 10.2, y: 0 }, 1), null)
        compare(JSON.stringify(Nodes.snapPoint(list, "e1", { x: 9.5, y: 19.8 }, 1)), JSON.stringify({ x: 10, y: 20 }))
        const loopEnds = Elements.endsWorld(loop)
        compare(Nodes.snapPoint(list, "e4", loopEnds.A, 1), null)
        b.joins.A = { id: "e9", end: "B" }
        compare(Nodes.snapPoint(list, "e1", { x: 20.5, y: 0.3 }, 1), null)
    }
}
```

Add to `app/tests/qml/tst_commands.qml`:

```qml
    function test_stretchMovesAndChangesOneSettingAsOneStep() {
        const s = new Commands.UndoStack()
        const t0 = base()
        const t1 = Commands.run(s, t0, "stretch", { id: "e3", x: 1, y: 2, rotation: 400, key: "length", value: 30, mergeKey: "g1" })
        compare(byId(t1, "e3").rotation, 40)
        const t2 = Commands.run(s, t1, "stretch", { id: "e3", x: 1, y: 3, rotation: 40, key: "length", value: 300, mergeKey: "g1" })
        compare(byId(t2, "e3").props.length, 200)            // kept within its limits
        compare(s.undoLabel(), "Stretch Straight")
        compare(s.done.length, 1)
        compare(JSON.stringify(s.undo()), JSON.stringify(t0))
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\run.ps1 -NoCpp`
Expected: `tst_nodes.qml` fails to load (no `nodes.mjs`); the stretch test fails with "Unknown command stretch".

- [ ] **Step 3: Write `app/qml/logic/nodes.mjs`**

```js
// Gate nodes: dragging an element's open end. With the other end open too, the element pivots about its other end and
// stretches (a straight's or line's length, otherwise the lead at the dragged end) so the dragged end lands on the
// mouse. With the other end joined it only stretches, along its own direction, so the chain stays joined.
// Tests: tests/qml/tst_nodes.qml.
import * as Elements from "./elements.mjs"

const DEG = Math.PI / 180

// The setting a drag on `end` stretches.
export function stretchKey(el, end) {
    if (el.type === "straight" || el.type === "line")
        return "length"
    return end === "A" ? "leadIn" : "leadOut"
}

function turned(v, degrees) {
    const c = Math.cos(degrees * DEG)
    const s = Math.sin(degrees * DEG)
    return { x: v.x * c - v.y * s, y: v.x * s + v.y * c }
}

function dot(a, b) {
    return a.x * b.x + a.y * b.y
}

// Where `el` goes when its `end` is dragged to `point` (canvas metres): { x, y, rotation, key, value }. opts.pivot: the
// other end is open, so the element may turn as well as stretch. opts.step: degrees to snap the rotation to (0 for
// none), counted from the export frame's axis, whose angle on the canvas is opts.frameTheta.
export function drag(el, end, point, opts) {
    const other = end === "A" ? "B" : "A"
    const key = stretchKey(el, end)
    const def = Elements.PROPS[el.type].find(p => p.key === key)
    const keep = v => Elements.clamp(def, v).value
    const current = el.props[key]
    const g = Elements.geometry(el.type, el.props)
    // In the element's own frame the dragged end sits at c + L·u from the other end, L being the stretched setting:
    // stretching moves that end straight out along its own heading.
    const u = { x: Math.cos(g.ends[end].heading * DEG), y: Math.sin(g.ends[end].heading * DEG) }
    const c = { x: g.ends[end].x - g.ends[other].x - current * u.x, y: g.ends[end].y - g.ends[other].y - current * u.y }
    const fixed = Elements.endsWorld(el)[other]
    const want = { x: point.x - fixed.x, y: point.y - fixed.y }

    let rotation = el.rotation
    let value = current
    if (opts.pivot) {
        // |c + L·u| = |want|: the setting that puts the end as far from the other end as the mouse is.
        const cu = dot(c, u)
        const disc = cu * cu - dot(c, c) + dot(want, want)
        if (disc < 0) {
            value = keep(-cu)                    // the mouse is nearer than the end can come: as near as it gets
        } else {
            const far = -cu + Math.sqrt(disc)
            const close = -cu - Math.sqrt(disc)
            const closeFits = close >= def.min && close <= def.max
            value = closeFits && Math.abs(close - current) < Math.abs(far - current) ? close : keep(far)
        }
        const v = { x: c.x + value * u.x, y: c.y + value * u.y }
        rotation = Math.atan2(want.y, want.x) / DEG - Math.atan2(v.y, v.x) / DEG
        if (opts.step > 0) {
            const theta = opts.frameTheta || 0
            rotation = theta - Math.round(Elements.normalizeAngle(theta - rotation) / opts.step) * opts.step
        }
        rotation = Elements.normalizeAngle(rotation)
    }
    if (!opts.pivot || opts.step > 0) {
        // Stretch only, at this rotation: the mouse projected onto the line the end moves along.
        const q = turned(want, -rotation)
        value = keep(dot({ x: q.x - c.x, y: q.y - c.y }, u))
    }
    const props = Object.assign({}, el.props)
    props[key] = value
    const moved = Elements.endsWorld(Object.assign({}, el, { rotation: rotation, props: props }))[other]
    return { x: el.x + fixed.x - moved.x, y: el.y + fixed.y - moved.y, rotation: rotation, key: key, value: value }
}

// The nearest open end of another element within maxDistance (metres) of `point`, as { x, y }, or null. A node lands
// on it exactly but does not join it.
export function snapPoint(elements, id, point, maxDistance) {
    let best = null
    let bestDistance = maxDistance
    for (const el of elements) {
        if (el.id === id)
            continue
        const ends = Elements.endsWorld(el)
        for (const end of ["A", "B"]) {
            if (el.joins[end])
                continue
            const d = Math.hypot(ends[end].x - point.x, ends[end].y - point.y)
            if (d < bestDistance) {
                bestDistance = d
                best = { x: ends[end].x, y: ends[end].y }
            }
        }
    }
    return best
}
```

Add `qml/logic/nodes.mjs` to `QML_FILES` in `app/CMakeLists.txt`.

- [ ] **Step 4: The `stretch` command**

In `COMMANDS` in `commands.mjs`, after `placeMany`:

```js
    ,
    // A gate-node drag: the element's new place and one stretched setting, as one step.
    stretch(t, a) {
        const el = find(t, a.id)
        el.x = a.x
        el.y = a.y
        el.rotation = Elements.normalizeAngle(a.rotation)
        el.props[a.key] = Elements.clampProp(el.type, a.key, a.value).value
        Snapping.unjoinApart(t.elements)
        return t
    }
```

In `label`: `case "stretch": return "Stretch " + named(a.id)`.

- [ ] **Step 5: Run everything**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add app/CMakeLists.txt app/qml/logic app/tests/qml
git commit -m "Pivot and stretch maths for gate nodes (nodes.mjs) and the Stretch command" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Hand-edited files repaired or refused (minor 1); lines in files

**Files:**
- Modify: `app/qml/logic/conefile.mjs`
- Modify: `docs/cone-format.md` (the `cones` row)
- Test: `app/tests/qml/tst_conefile.qml`

**Interfaces:**
- Consumes: Task 2's `line` type (`Elements.TYPES`), `Elements.endsWorld`.
- Produces: `ConeFile.JOIN_SLACK = 0.05`; `fromDocument` refuses ids `ruler`, `origin`, `direction` and self-joins as `MESSAGES.damaged`; removes joins whose ends are more than 5 cm apart or that involve a line.

- [ ] **Step 1: Write the failing tests**

In `app/tests/qml/tst_conefile.qml`:

```qml
    // Two straights joined e1.B - e2.A, as a document to edit by hand.
    function joinedDoc() {
        const s = new Commands.UndoStack()
        let t = Commands.emptyTrack()
        t = Commands.run(s, t, "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 })
        t = Commands.run(s, t, "add", { type: "straight", x: 10, y: 5 })
        t = Commands.run(s, t, "add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } })
        return doc(t)
    }

    function test_selfJoinsAndReservedIdsAreDamaged() {
        const self = joinedDoc()
        self.design.elements[0].joins.A = { id: "e1", end: "A" }
        compare(ConeFile.fromDocument(self, -1).error, ConeFile.MESSAGES.damaged)
        for (const id of ["ruler", "origin", "direction"]) {
            const d = joinedDoc()
            d.design.elements[0].id = id
            d.design.elements[1].joins.A = { id: id, end: "B" }
            compare(ConeFile.fromDocument(d, -1).error, ConeFile.MESSAGES.damaged, id)
        }
    }

    function test_joinedEndsApartAreUnjoined() {
        const apart = joinedDoc()
        apart.design.elements[1].x += 1
        const t = ConeFile.fromDocument(apart, -1).track
        compare(t.elements[0].joins.B, null)
        compare(t.elements[1].joins.A, null)
        const close = joinedDoc()
        close.design.elements[1].x += 0.01
        compare(ConeFile.fromDocument(close, -1).track.elements[0].joins.B.id, "e2")
    }

    function test_aJoinToALineIsDropped() {
        const d = joinedDoc()
        d.design.elements[1].type = "line"
        d.design.elements[1].props = { length: 20, spacing: 3 }
        const t = ConeFile.fromDocument(d, -1).track
        compare(t.elements[0].joins.B, null)
        compare(t.elements[1].joins.A, null)
    }

    function test_aLineRoundTripsAndItsConesComeLast() {
        let t = Demo.demoTrack()
        t = Commands.run(new Commands.UndoStack(), t, "add",
                         { type: "line", x: 120, y: 68, rotation: 30, props: { length: 12, spacing: 2 } })
        const d = doc(t)
        compare(JSON.stringify(ConeFile.fromDocument(d, -1).track), JSON.stringify(t))
        compare(d.cones.filter(c => c.element === "e5").length, 7)
        compare(d.cones.slice(-7).map(c => c.element).join(","), "e5,e5,e5,e5,e5,e5,e5")
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_conefile.qml`
Expected: the self-join, reserved-id, apart and line-join tests FAIL (the file loads as it is). The round trip passes once Task 2 is in.

- [ ] **Step 3: Refuse and repair in `conefile.mjs`**

Add `import * as Elements from "./elements.mjs"` if it is not already imported (it is), and after `MESSAGES`:

```js
// Element ids the canvas uses for the ruler and the targets: an element may not take them.
const RESERVED_IDS = ["ruler", "origin", "direction"]
// Joined ends further apart than this in a hand-edited file are unjoined on open.
export const JOIN_SLACK = 0.05
```

In `readDesign`, the element loop:

```js
    for (const v of d.elements) {
        const el = readElement(v)
        if (!el || RESERVED_IDS.indexOf(el.id) >= 0 || elements.some(e => e.id === el.id))
            return null
        elements.push(el)
    }
```

In the join check loop, before looking up `other`:

```js
            if (j.id === el.id)
                return null                                  // an element joined to itself
```

After `if (elements.length > 0 && !(scale > 0)) return null`:

```js
    repairJoins(elements)
```

And above `readDesign`:

```js
// Joins a hand edit has made impossible: ends more than JOIN_SLACK apart, or a line (lines are never joined). Both
// sides are unjoined, quietly.
function repairJoins(elements) {
    for (const el of elements) {
        for (const end of ["A", "B"]) {
            const j = el.joins[end]
            if (!j)
                continue
            const other = elements.find(e => e.id === j.id)
            const a = Elements.endsWorld(el)[end]
            const b = Elements.endsWorld(other)[j.end]
            if (el.type === "line" || other.type === "line" || Math.hypot(a.x - b.x, a.y - b.y) > JOIN_SLACK) {
                el.joins[end] = null
                other.joins[j.end] = null
            }
        }
    }
}
```

- [ ] **Step 4: Say where line cones go in `docs/cone-format.md`**

In the `cones` row of the field table, after "Every cone in driving order.", add: "Cones of lines (straight rows for walls and boundaries) come after the course."

- [ ] **Step 5: Run everything**

Run: `powershell -NoProfile -File app\tests\run.ps1 -NoCpp`
Expected: all pass (the schema check included).

- [ ] **Step 6: Commit**

```bash
git add app/qml/logic/conefile.mjs app/tests/qml/tst_conefile.qml docs/cone-format.md
git commit -m "Opening a hand-edited file: reserved ids and self-joins are damaged; far-apart joins and joins to lines are dropped" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Lines, folds and arrows on the canvas (minor 4)

**Files:**
- Modify: `app/qml/ElementView.qml`
- Modify: `app/qml/TrackStore.qml` (`foldedIds`)
- Modify: `app/qml/CanvasView.qml` (`folded:` on each view; `hoverWarning` over both lists; `warningText`)
- Test: `app/tests/tst_qmlload.cpp` (the `Loaded` helper; `foldsAndLinesOnTheCanvas`; `draggingOnABigCourseKeepsUp`)

**Interfaces:**
- Consumes: `Elements.folds`, `Elements.foldAdvice` (Task 3), `line` (Task 2).
- Produces: `TrackStore.foldedIds` (ids); `ElementView` properties `folded: bool`, `hoverEnd: string` ("A", "B" or ""), read-only `chevrons` and `dots` (arrays of point lists); `CanvasView.warningText(id) -> string`; the `Loaded` test helper and the `isNull`, `plain` helpers used by Tasks 7 to 10.

- [ ] **Step 1: Add the `Loaded` helper to `tst_qmlload.cpp`**

After `textBox(...)`, before the test class:

```cpp
// Whether a QML `var` property holds null (or nothing).
static bool isNull(const QVariant &v)
{
    return !v.isValid() || v.isNull() || qvariant_cast<QJSValue>(v).isNull();
}

// A QML `var` value as plain Qt values (a JS array becomes a QVariantList, an object a QVariantMap).
static QVariant plain(const QVariant &v)
{
    return v.userType() == qMetaTypeId<QJSValue>() ? qvariant_cast<QJSValue>(v).toVariant() : v;
}

// One loaded Main with the helpers the part 3 window tests share.
struct Loaded
{
    QQmlApplicationEngine engine;
    QQuickWindow *window = nullptr;
    QQuickItem *canvas = nullptr;
    QObject *store = nullptr;

    // Loads and shows Main; `demo` loads the example track (setup done) and waits for it to be fitted.
    bool load(bool demo)
    {
        engine.loadFromModule("Conestructor", "Main");
        if (engine.rootObjects().isEmpty())
            return false;
        window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        if (!window || !QTest::qWaitForWindowExposed(window))
            return false;
        window->requestActivate();
        if (!QTest::qWaitForWindowActive(window))
            return false;
        canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        if (!canvas || !store)
            return false;
        if (demo)
            QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        return QTest::qWaitFor([this]() { return !canvas->property("fitPending").toBool(); });
    }

    QVariantMap element(const QString &id) const
    {
        QVariant v;
        QMetaObject::invokeMethod(store, "element", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, id));
        return qvariant_cast<QJSValue>(v).toVariant().toMap();
    }
    QVariantMap track() const { return plain(store->property("track")).toMap(); }
    double mpp() const { return store->property("mpp").toDouble(); }
    double zoom() const { return canvas->property("zoom").toDouble(); }
    // A point in canvas metres, on screen (canvas coordinates).
    QPointF screen(double mx, double my) const
    {
        QVariant v;
        QMetaObject::invokeMethod(canvas, "toScreen", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, mx / mpp()),
                                  Q_ARG(QVariant, my / mpp()));
        const QVariantMap p = qvariant_cast<QJSValue>(v).toVariant().toMap();
        return { p.value("x").toDouble(), p.value("y").toDouble() };
    }
    // A screen point (canvas coordinates) in photo pixels.
    QPointF world(QPointF s) const
    {
        QVariant v;
        QMetaObject::invokeMethod(canvas, "toWorld", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, s.x()), Q_ARG(QVariant, s.y()));
        const QVariantMap p = qvariant_cast<QJSValue>(v).toVariant().toMap();
        return { p.value("x").toDouble(), p.value("y").toDouble() };
    }
    QPoint scene(QPointF p) const { return canvas->mapToScene(p).toPoint(); }
    void click(QPointF p, Qt::MouseButton button = Qt::LeftButton) const { QTest::mouseClick(window, button, {}, scene(p)); }
    void drag(QPointF from, QPointF to, int steps = 8) const
    {
        const QPoint a = scene(from);
        const QPoint b = scene(to);
        QTest::mousePress(window, Qt::LeftButton, {}, a);
        for (int i = 1; i <= steps; ++i)
            QTest::mouseMove(window, a + (b - a) * i / steps);
        QTest::mouseRelease(window, Qt::LeftButton, {}, b);
    }
    void clickItem(QQuickItem *item) const
    {
        QTest::mouseClick(window, Qt::LeftButton, {}, item->mapToScene(QPointF(item->width() / 2, item->height() / 2)).toPoint());
    }
    void run(const QString &name, const QVariantMap &args) const
    {
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, name), Q_ARG(QVariant, args));
    }
    QString label() const { return store->property("undoLabel").toString(); }
    QQuickItem *named(const QString &objectName) const
    {
        for (QQuickItem *item : allItems(window->contentItem()))
            if (item->objectName() == objectName)
                return item;
        return nullptr;
    }
    // The palette or checklist tile for `kind`.
    QQuickItem *tile(const QString &kind) const
    {
        for (QQuickItem *item : allItems(window->contentItem()))
            if (QByteArray(item->metaObject()->className()).startsWith("PaletteTile") && item->property("kind").toString() == kind)
                return item;
        return nullptr;
    }
    // The ElementView drawing element `id`.
    QQuickItem *view(const QString &id) const
    {
        for (QQuickItem *item : allItems(window->contentItem())) {
            if (!QByteArray(item->metaObject()->className()).startsWith("ElementView"))
                continue;
            const QVariantMap e = qvariant_cast<QJSValue>(item->property("element")).toVariant().toMap();
            if (e.value("id").toString() == id)
                return item;
        }
        return nullptr;
    }
};
```

Add `#include <QElapsedTimer>` to the includes.

- [ ] **Step 2: Write the failing window tests**

In the test class:

```cpp
    // A folded turn shows the warning with the fix in display units; a line draws no arrows, a dot per cone, and its
    // cones come last.
    void foldsAndLinesOnTheCanvas()
    {
        Loaded w;
        QVERIFY(w.load(true));
        w.run(QStringLiteral("setProp"), { { "id", "e3" }, { "key", "radius" }, { "value", 1.0 } });
        QCOMPARE(plain(w.store->property("foldedIds")).toStringList(), QStringList{ QStringLiteral("e3") });
        QVERIFY(w.view(QStringLiteral("e3"))->property("folded").toBool());
        QVariant text;
        QMetaObject::invokeMethod(w.canvas, "warningText", Q_RETURN_ARG(QVariant, text), Q_ARG(QVariant, QStringLiteral("e3")));
        // Half the 4 m width, in whatever units an earlier test left saved.
        QVERIFY2(text.toString().startsWith(QStringLiteral("Folds in on itself: make the radius at least "))
                     && text.toString().endsWith(QStringLiteral(", or the track narrower.")), qPrintable(text.toString()));

        w.run(QStringLiteral("add"), { { "type", "line" }, { "x", 120.0 }, { "y", 68.0 } });
        QQuickItem *line = w.view(QStringLiteral("e5"));
        QVERIFY(line);
        QCOMPARE(plain(line->property("chevrons")).toList().size(), 0);
        QCOMPARE(plain(line->property("dots")).toList().size(), 8);
        QVERIFY(plain(w.view(QStringLiteral("e1"))->property("chevrons")).toList().size() >= 2);

        QMetaObject::invokeMethod(w.store, "placeCones");
        const QVariantList cones = plain(w.store->property("preview")).toMap().value("canvasCones").toList();
        QCOMPARE(cones.last().toMap().value("element").toString(), QStringLiteral("e5"));
    }

    // Part 2's minor: arrows were one item per chevron, rebuilt on every edit. Dragging one element of a 40-element
    // course must keep up: the average time to handle a mouse move stays under a budget measured on the owner's machine.
    void draggingOnABigCourseKeepsUp()
    {
        Loaded w;
        QVERIFY(w.load(true));
        for (int i = 5; i <= 40; ++i) {
            QVariantMap add{ { "type", i % 2 ? QStringLiteral("turn") : QStringLiteral("straight") }, { "x", 0.0 }, { "y", 0.0 },
                             { "snap", QVariantMap{ { "ownEnd", "A" }, { "id", QStringLiteral("e%1").arg(i - 1) }, { "end", "B" } } } };
            if (i % 2)
                add.insert("props", QVariantMap{ { "angle", 20.0 } });
            w.run(QStringLiteral("add"), add);
        }
        QCOMPARE(w.store->property("elementCount").toInt(), 40);
        const QVariantMap e1 = w.element(QStringLiteral("e1"));
        const QPointF from = w.screen(e1.value("x").toDouble(), e1.value("y").toDouble());
        const QPoint a = w.scene(from);
        QElapsedTimer timer;
        QTest::mousePress(w.window, Qt::LeftButton, {}, a);
        timer.start();
        const int moves = 20;
        for (int i = 1; i <= moves; ++i)
            QTest::mouseMove(w.window, a + QPoint(0, 4 * i));
        const double perMove = double(timer.elapsed()) / moves;
        QTest::mouseRelease(w.window, Qt::LeftButton, {}, a + QPoint(0, 4 * moves));
        qInfo("ms per move on a 40-element course: %.1f", perMove);
        const double budget = 1e9;      // Step 4 sets this from the measurement
        QVERIFY2(perMove < budget, qPrintable(QStringLiteral("%1 ms per move").arg(perMove)));
    }
```

- [ ] **Step 3: Run them: the first fails, the second prints the baseline**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1 -NoQml -R tst_qmlload`
Expected: `foldsAndLinesOnTheCanvas` FAILS (no `foldedIds`). `draggingOnABigCourseKeepsUp` passes and prints "ms per move … X": write X down as the **before** figure.

- [ ] **Step 4: Draw lines, folds and arrows**

In `TrackStore.qml` add `import "logic/elements.mjs" as Elements` and, after `backwardIds`:

```qml
    // Elements whose inside edge crosses over itself: they show a warning too (advice only).
    readonly property var foldedIds: track.elements.filter(e => Elements.folds(e)).map(e => e.id)
```

Replace `ElementView.qml`'s header comment, properties and drawing with:

```qml
// One track element drawn from data, in photo pixels: a translucent band in its colour as wide as the track, a
// dashed centreline, a ring at each open end (bigger under the mouse: it can be dragged), a green dot at each joined
// end, and white arrows along the centreline pointing the way it is driven. A line has no band and no arrows: a thin
// solid line with a dot where each cone goes. An element driven against its chain, or folding in on itself, shows a
// warning sign. Selected: a white outline and the rotate handle. Draws only; CanvasView handles every click and drag.
Item {
    id: view

    property var element: null
    property real zoom: 1
    property bool selected: false
    property bool single: true        // the only thing selected: it shows the rotate handle
    property bool dimmed: false
    property bool backwards: false
    property bool folded: false
    property string hoverEnd: ""      // the open end under the mouse ("A" or "B"), or ""

    readonly property real mpp: TrackStore.mpp
    readonly property bool drawable: element !== null && mpp > 0
    readonly property bool isLine: drawable && element.type === "line"
    readonly property color colour: element ? Elements.COLOURS[element.type] : "white"
    readonly property var points: drawable ? Elements.pathWorld(element).map(p => Qt.point(p.x / mpp, p.y / mpp)) : []
    readonly property var ends: drawable ? Elements.endsWorld(element) : null
    readonly property var band: {
        if (!drawable || isLine)
            return []
        const ring = Elements.bandPolygon(Elements.pathWorld(element), element.props.trackWidth / 2)
                     .map(p => Qt.point(p.x / mpp, p.y / mpp))
        return ring.length > 0 ? ring.concat([ring[0]]) : ring
    }
    readonly property var arrows: drawable && !isLine ? Elements.arrowMarks(element, 8) : []
    // Every arrow as one three-point stroke, a fixed size on screen, all in one shape: an edit no longer rebuilds an
    // item per arrow.
    readonly property var chevrons: arrows.map(m => {
        const r = m.heading * Math.PI / 180
        const c = Math.cos(r) / zoom
        const s = Math.sin(r) / zoom
        const at = (lx, ly) => Qt.point(m.x / mpp + lx * c - ly * s, m.y / mpp + lx * s + ly * c)
        return [at(-4, -6), at(4, 0), at(-4, 6)]
    })
    // A line's cones-to-be: each a round-capped stroke too short to see, drawn as a dot.
    readonly property var dots: isLine ? Elements.conesWorld(element).map(q => [Qt.point(q.x / mpp, q.y / mpp),
                                                                                Qt.point(q.x / mpp + 0.001, q.y / mpp)]) : []
    // The middle of the centreline (canvas metres), where the warning sits.
    readonly property var middle: drawable ? Elements.pointsAlong(element, [0.5])[0] : null
    readonly property var handle: drawable && selected && single ? Elements.rotateHandle(element, 24 / zoom * mpp) : null

    visible: drawable
    opacity: dimmed ? 0.3 : 1

    Shape {
        preferredRendererType: Shape.CurveRenderer

        // The band as a filled outline (a thick translucent stroke would darken where its segments overlap).
        ShapePath {
            strokeColor: view.selected && !view.isLine ? "#ffffff" : "transparent"
            strokeWidth: 2 / view.zoom
            fillColor: Qt.rgba(view.colour.r, view.colour.g, view.colour.b, 0.45)
            fillRule: ShapePath.WindingFill
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: view.band }
        }
        // The centreline: dashed for a track element; solid for a line (white when selected).
        ShapePath {
            strokeColor: view.isLine && view.selected ? "#ffffff" : view.colour
            strokeWidth: (view.isLine ? 2 : 1.5) / view.zoom
            strokeStyle: view.isLine ? ShapePath.SolidLine : ShapePath.DashLine
            dashPattern: [6, 4]
            fillColor: "transparent"
            PathPolyline { path: view.points }
        }
        ShapePath {
            strokeColor: view.handle ? "#ffffff" : "transparent"
            strokeWidth: 1.5 / view.zoom
            fillColor: "transparent"
            startX: view.drawable ? view.element.x / view.mpp : 0
            startY: view.drawable ? view.element.y / view.mpp : 0
            PathLine {
                x: view.handle ? view.handle.x / view.mpp : 0
                y: view.handle ? view.handle.y / view.mpp : 0
            }
        }
        ShapePath {
            strokeColor: "#ffffff"
            strokeWidth: 2 / view.zoom
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathMultiline { paths: view.chevrons }
        }
        ShapePath {
            strokeColor: view.colour
            strokeWidth: 5 / view.zoom
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathMultiline { paths: view.dots }
        }
    }

    Label {
        visible: (view.backwards || view.folded) && view.middle !== null
        text: "⚠"
        color: "#ffb300"
        font.pixelSize: 20
        style: Text.Outline
        styleColor: "#000000"
        scale: 1 / view.zoom
        x: view.middle ? view.middle.x / view.mpp - width / 2 : 0
        y: view.middle ? view.middle.y / view.mpp - height / 2 : 0
    }

    Repeater {
        model: view.drawable ? 2 : 0
        Rectangle {
            required property int index
            readonly property string end: index === 0 ? "A" : "B"
            readonly property bool joined: view.element.joins[end] !== null
            readonly property var at: view.ends[end]
            width: (joined ? 8 : view.hoverEnd === end ? 14 : 10) / view.zoom
            height: width
            radius: width / 2
            x: at.x / view.mpp - width / 2
            y: at.y / view.mpp - height / 2
            color: joined ? "#4caf50" : "transparent"
            border.color: joined ? "#4caf50" : "#ffffff"
            border.width: 1.5 / view.zoom
        }
    }
```

(The rotate handle `Rectangle` at the end stays as it is. The old arrows `Repeater` is gone.)

In `CanvasView.qml`, the `ElementView` delegate gains:

```qml
                folded: element !== null && TrackStore.foldedIds.indexOf(element.id) >= 0
```

`hoverWarning` loops over both lists:

```qml
        for (const id of TrackStore.backwardIds.concat(TrackStore.foldedIds)) {
```

Add after `hitAt`:

```js
    // What an element's warning says: driven backwards, folding in on itself, or both (one line each).
    function warningText(id) {
        const el = TrackStore.element(id)
        if (!el)
            return ""
        const lines = []
        if (TrackStore.backwardIds.indexOf(id) >= 0)
            lines.push(qsTr("Runs against the track: right-click › Reverse direction"))
        const fold = Elements.foldAdvice(el, m => Units.format(m, Settings.units))
        if (fold !== "")
            lines.push(fold)
        return lines.join("\n")
    }
```

and the `warningTip` label's text becomes `text: canvas.warningText(canvas.hoverWarning)`.

- [ ] **Step 5: Measure again and set the budget**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1 -NoQml -R tst_qmlload`
Expected: both tests pass; note the **after** figure Y. Set `const double budget = …;` to twice Y rounded up to the next 10 ms, run again, and see it pass.

- [ ] **Step 6: Run everything**

Run: `powershell -NoProfile -File app\tests\run.ps1`
Expected: all pass (the part 2 arrows test still sees the warning tip on a backwards element).

- [ ] **Step 7: Commit**

```bash
git add app/qml app/tests/tst_qmlload.cpp
git commit -m "Lines and fold warnings on the canvas; each element's arrows drawn as one shape (X ms -> Y ms per drag move on 40 elements)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Put the measured X and Y in the message.)

---

### Task 7: Gate nodes on the canvas

**Files:**
- Modify: `app/qml/CanvasView.qml`
- Test: `app/tests/tst_qmlload.cpp` (`gateNodesPivotAndStretch`)

**Interfaces:**
- Consumes: `Nodes.drag`, `Nodes.snapPoint` (Task 4); `stretch` command; `ElementView.hoverEnd` (Task 6).
- Produces: `CanvasView.hoverNode` (`{ id, end }` or null); `CanvasView.nodeAt(w) -> { kind: "node", id, end } | null`; gesture mode `"node"`.

- [ ] **Step 1: Write the failing window test**

```cpp
    // A joined straight's open end only stretches; a free straight's end swings it about its other end; each drag is
    // one step; a joined end is not a node.
    void gateNodesPivotAndStretch()
    {
        Loaded w;
        QVERIFY(w.load(true));
        const double perPixel = w.mpp() / w.zoom();          // metres per screen pixel
        const QVariantMap e1 = w.element(QStringLiteral("e1"));
        const double length = e1.value("props").toMap().value("length").toDouble();
        const double x1 = e1.value("x").toDouble();
        const double y1 = e1.value("y").toDouble();

        // e1 (the demo's first straight, rotation 0) is joined at B, so its open A end only stretches.
        const QPointF a = w.screen(x1 - length / 2, y1);
        QTest::mouseMove(w.window, w.scene(a));
        QTRY_COMPARE(w.view(QStringLiteral("e1"))->property("hoverEnd").toString(), QStringLiteral("A"));
        w.drag(a, a + QPointF(-40, 15));
        QCOMPARE(w.label(), QStringLiteral("Stretch Straight"));
        const QVariantMap stretched = w.element(QStringLiteral("e1"));
        QCOMPARE(stretched.value("rotation").toDouble(), 0.0);
        QVERIFY2(std::abs(stretched.value("props").toMap().value("length").toDouble() - (length + 40 * perPixel)) < 1.5 * perPixel,
                 qPrintable(QString::number(stretched.value("props").toMap().value("length").toDouble())));
        QVERIFY(!stretched.value("joins").toMap().value("B").isNull());
        QMetaObject::invokeMethod(w.store, "undo");
        QCOMPARE(w.element(QStringLiteral("e1")).value("props").toMap().value("length").toDouble(), length);

        // A free straight pivots about its other end.
        w.run(QStringLiteral("add"), { { "type", "straight" }, { "x", x1 }, { "y", y1 + 20 } });
        const QPointF freeA = w.screen(x1 - 10, y1 + 20);
        const QPointF freeB = w.screen(x1 + 10, y1 + 20);
        w.drag(freeB, freeA + QPointF(0, 60));
        QCOMPARE(w.label(), QStringLiteral("Stretch Straight"));
        const QVariantMap swung = w.element(QStringLiteral("e5"));
        QVERIFY2(std::abs(swung.value("rotation").toDouble() - 90) < 2, qPrintable(QString::number(swung.value("rotation").toDouble())));
        QVERIFY(std::abs(swung.value("props").toMap().value("length").toDouble() - 60 * perPixel) < 1.5 * perPixel);
        // Its A end has not moved.
        const double r = swung.value("rotation").toDouble() * M_PI / 180;
        const double half = swung.value("props").toMap().value("length").toDouble() / 2;
        QVERIFY(std::abs(swung.value("x").toDouble() - half * std::cos(r) - (x1 - 10)) < 1e-6);
        QVERIFY(std::abs(swung.value("y").toDouble() - half * std::sin(r) - (y1 + 20)) < 1e-6);

        // The joint between e1 and e2 is not a node: pressing there grabs the element, not a stretch.
        const QPointF joint = w.screen(x1 + length / 2, y1);
        w.drag(joint, joint + QPointF(0, 40));
        QVERIFY2(!w.label().startsWith(QStringLiteral("Stretch")), qPrintable(w.label()));
    }
```

- [ ] **Step 2: Run it to see it fail**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1 -NoQml -R tst_qmlload`
Expected: FAIL (`hoverEnd` stays "", and the drag is a "Move Straight").

- [ ] **Step 3: Nodes in `CanvasView.qml`**

Add `import "logic/nodes.mjs" as Nodes`. Properties:

```qml
    property var hoverNode: null      // the open end under the mouse ({ id, end }), or null
```

After `distance(a, b)`:

```js
    // The open end (a gate node) within 10 screen pixels of photo pixel w, topmost element first, or null.
    function nodeAt(w) {
        if (!(mpp > 0))
            return null
        const list = TrackStore.track.elements
        for (let i = list.length - 1; i >= 0; i--) {
            const el = list[i]
            const ends = Elements.endsWorld(el)
            for (const end of ["A", "B"])
                if (!el.joins[end] && distance({ x: ends[end].x / mpp, y: ends[end].y / mpp }, w) < 10 / zoom)
                    return { kind: "node", id: el.id, end: end }
        }
        return null
    }
```

In `hitAt`, after the targets loop and before the element hit test:

```js
        const node = nodeAt(w)
        if (node)
            return node
```

In `pressAt`, before `if (hit.kind === "element" || hit.kind === "rotate")`:

```js
        if (hit.kind === "node") {
            TrackStore.select(hit.id)
            press.el = JSON.parse(JSON.stringify(TrackStore.element(hit.id)))
            press.end = hit.end
            press.pivot = press.el.joins[hit.end === "A" ? "B" : "A"] === null
            mode = "node"
            return
        }
```

In `moveTo`, replace the first line with:

```js
        hover = toWorld(e.x, e.y)
        if (!mouse.pressed)
            hoverNode = placingKind === "" ? nodeAt(hover) : null
```

and add a branch before `} else if (mode === "box") {`:

```js
        } else if (mode === "node") {
            const ctrl = (e.modifiers & Qt.ControlModifier) !== 0
            const shift = (e.modifiers & Qt.ShiftModifier) !== 0
            const w = toWorld(e.x, e.y)
            let p = { x: w.x * mpp, y: w.y * mpp }
            if (press.pivot && !ctrl && !shift) {
                const s = Nodes.snapPoint(TrackStore.track.elements, press.el.id, p, snapMetres())
                if (s)
                    p = s
            }
            const r = Nodes.drag(press.el, press.end, p, { pivot: press.pivot, step: shift ? 15 : 0,
                                                           frameTheta: TrackStore.frame ? TrackStore.frame.theta : 0 })
            TrackStore.run("stretch", { id: press.el.id, x: r.x, y: r.y, rotation: r.rotation, key: r.key, value: r.value,
                                        mergeKey: gestureKey })
```

In the `MouseArea`: `onExited: { canvas.hover = null; canvas.hoverNode = null }`, and `cursorShape` checks the node first:

```qml
        cursorShape: canvas.mode === "node" || (canvas.mode === "" && canvas.hoverNode !== null) ? Qt.CrossCursor
                     : canvas.mode === "pan" ? Qt.ClosedHandCursor
                     : canvas.mode === "move" || canvas.mode === "moveGroup" || canvas.mode === "target" ? Qt.SizeAllCursor
                     : Qt.ArrowCursor
```

The `ElementView` delegate gains:

```qml
                hoverEnd: element !== null && canvas.hoverNode !== null && canvas.hoverNode.id === element.id
                          ? canvas.hoverNode.end : ""
```

(`releaseAt` already seals every gesture that is not a pan or box.)

- [ ] **Step 4: Run everything**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: all pass. If an older window test now presses on an open end where it meant to drag an element (a node within 10 px), move its press point to the element's middle and say so in the commit message.

- [ ] **Step 5: Commit**

```bash
git add app/qml/CanvasView.qml app/tests/tst_qmlload.cpp
git commit -m "Gate nodes: drag an open end to pivot and stretch (stretch only when the other end is joined)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Click-to-place, ghosts, the ruler by two clicks and its length box

**Files:**
- Modify: `app/qml/PaletteTile.qml`
- Modify: `app/qml/CanvasView.qml`
- Create: `app/qml/RulerLengthBox.qml`
- Modify: `app/CMakeLists.txt` (add `qml/RulerLengthBox.qml`)
- Test: `app/tests/tst_qmlload.cpp` (`tilesPlaceByClicking`, `draggingATileShowsAGhost`)

**Interfaces:**
- Consumes: the `Loaded` helper (Task 6).
- Produces on `CanvasView`: `placingBy` (`""`, `"drag"`, `"click"`), `placingPoint` (photo pixel or null), `rulerFirst` (photo pixel or null), `rulerGhost` (`{ a, b }` or null), `lengthBoxOpen` (bool); functions `pickUp(kind)`, `clickTile(kind)`, `cancelPlacing()`, `openLengthBox()`, `placingHint(kind) -> string`. `beginPlacing`, `updatePlacing`, `finishPlacing` keep their signatures. `RulerLengthBox` has `objectName: "rulerLengthBox"` and a `bad` property.

- [ ] **Step 1: Write the failing window tests**

```cpp
    // Every tile places by clicking it, then the canvas; the ruler takes two clicks and then asks for its length on
    // the spot. Review focus 1, 2 and 5: undo with the box open, typing in feet and inches or nonsense, switching tiles.
    void tilesPlaceByClicking()
    {
        Loaded w;
        QVERIFY(w.load(false));
        QMetaObject::invokeMethod(w.window, "useBlueprint");
        auto placing = [&]() { return w.canvas->property("placingBy").toString(); };
        auto kind = [&]() { return w.canvas->property("placingKind").toString(); };
        auto ruler = [&]() { return w.track().value("ruler").toMap(); };

        // The ruler: two clicks, a rubber band between them.
        w.clickItem(w.tile(QStringLiteral("ruler")));
        QCOMPARE(placing(), QStringLiteral("click"));
        QCOMPARE(kind(), QStringLiteral("ruler"));
        QTest::mouseMove(w.window, w.scene({ 300, 400 }));
        QVERIFY(!isNull(w.canvas->property("placingPoint")));
        w.click({ 300, 400 });
        QVERIFY(ruler().isEmpty());
        QVERIFY(!isNull(w.canvas->property("rulerFirst")));
        QTest::mouseMove(w.window, w.scene({ 500, 400 }));
        QVERIFY(!isNull(w.canvas->property("rulerGhost")));
        w.click({ 500, 400 });
        QCOMPARE(placing(), QString());
        const QPointF a = w.world({ 300, 400 });
        QVERIFY(std::abs(ruler().value("a").toMap().value("x").toDouble() - a.x()) < 1.0 / w.zoom() + 1e-9);
        QCOMPARE(ruler().value("realLength").toDouble(), 0.0);

        // The length box is open and focused: nonsense turns red and stays; 18' 6" sets 5.6388 m and closes it.
        QQuickItem *box = w.named(QStringLiteral("rulerLengthBox"));
        QVERIFY(box);
        QTRY_VERIFY(box->isVisible());
        QTest::keyClicks(w.window, QStringLiteral("abc"));
        QTest::keyClick(w.window, Qt::Key_Return);
        QVERIFY(box->isVisible());
        QVERIFY(box->property("bad").toBool());
        QCOMPARE(ruler().value("realLength").toDouble(), 0.0);
        QTest::keyClick(w.window, Qt::Key_A, Qt::ControlModifier);
        QTest::keyClicks(w.window, QStringLiteral("18' 6\""));
        QTest::keyClick(w.window, Qt::Key_Return);
        QTRY_VERIFY(!box->isVisible());
        QVERIFY(std::abs(ruler().value("realLength").toDouble() - 5.6388) < 1e-9);
        QCOMPARE(w.label(), QStringLiteral("Set ruler"));

        // Undo with the box open: undo the length, then undo the ruler itself while the box shows: it closes for good.
        QMetaObject::invokeMethod(w.store, "undo");          // length off: the box does not reopen by itself
        QVERIFY(!box->isVisible());
        QMetaObject::invokeMethod(w.canvas, "openLengthBox");
        QTRY_VERIFY(box->isVisible());
        QMetaObject::invokeMethod(w.store, "undo");          // the ruler goes
        QTRY_VERIFY(!box->isVisible());
        QVERIFY(!w.canvas->property("lengthBoxOpen").toBool());
        QMetaObject::invokeMethod(w.store, "redo");
        QVERIFY(!box->isVisible());
        QMetaObject::invokeMethod(w.store, "redo");          // the length back

        // Switching tiles: only one is picked up; the same tile again, Esc or a right-click drops it.
        w.clickItem(w.tile(QStringLiteral("origin")));
        QCOMPARE(kind(), QStringLiteral("origin"));
        QVERIFY(w.store->property("message").toString().contains(QStringLiteral("Esc to cancel")));
        w.clickItem(w.tile(QStringLiteral("direction")));
        QCOMPARE(kind(), QStringLiteral("direction"));
        w.clickItem(w.tile(QStringLiteral("direction")));
        QCOMPARE(placing(), QString());
        w.clickItem(w.tile(QStringLiteral("origin")));
        QTest::keyClick(w.window, Qt::Key_Escape);
        QCOMPARE(placing(), QString());
        w.clickItem(w.tile(QStringLiteral("origin")));
        w.click({ 400, 500 }, Qt::RightButton);
        QCOMPARE(placing(), QString());
        QVERIFY(w.track().value("targets").toMap().value("origin").isNull());

        // Origin and Direction by clicking.
        w.clickItem(w.tile(QStringLiteral("origin")));
        w.click({ 400, 500 });
        QCOMPARE(w.label(), QStringLiteral("Place Origin"));
        w.clickItem(w.tile(QStringLiteral("direction")));
        w.click({ 900, 500 });
        QCOMPARE(w.label(), QStringLiteral("Place Direction"));

        // A track piece by clicking, now setup is done: the ghost follows, a click adds it.
        w.clickItem(w.tile(QStringLiteral("straight")));
        QTest::mouseMove(w.window, w.scene({ 600, 650 }));
        QVERIFY(!isNull(w.canvas->property("ghost")));
        w.click({ 600, 650 });
        QCOMPARE(w.store->property("elementCount").toInt(), 1);
        QCOMPARE(w.label(), QStringLiteral("Add Straight"));
        QCOMPARE(placing(), QString());
    }

    // Dragging the ruler or a target from its tile shows where it will land, as track pieces already did.
    void draggingATileShowsAGhost()
    {
        Loaded w;
        QVERIFY(w.load(false));
        QMetaObject::invokeMethod(w.window, "useBlueprint");
        QQuickItem *origin = w.tile(QStringLiteral("origin"));
        const QPoint start = origin->mapToScene(QPointF(origin->width() / 2, origin->height() / 2)).toPoint();
        const QPoint end = w.scene({ 400, 500 });
        QTest::mousePress(w.window, Qt::LeftButton, {}, start);
        for (int i = 1; i <= 8; ++i)
            QTest::mouseMove(w.window, start + (end - start) * i / 8);
        QCOMPARE(w.canvas->property("placingBy").toString(), QStringLiteral("drag"));
        QVERIFY(!isNull(w.canvas->property("placingPoint")));
        QTest::mouseRelease(w.window, Qt::LeftButton, {}, end);
        QCOMPARE(w.label(), QStringLiteral("Place Origin"));
        QVERIFY(isNull(w.canvas->property("placingPoint")));
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1 -NoQml -R tst_qmlload`
Expected: FAIL (`placingBy` does not exist; a tile click places nothing).

- [ ] **Step 3: Tiles: click picks up, drag places (`PaletteTile.qml`)**

Replace the `MouseArea` and add a border showing the picked-up tile:

```qml
    border.color: tile.canvas.placingBy === "click" && tile.canvas.placingKind === tile.kind ? "#2f6fd6" : "transparent"
    border.width: 2
```

```qml
    // A press that moves less than a drag's distance before release is a click: it picks the tile up (the next canvas
    // click puts it down). Further is a drag onto the canvas, as before.
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        property point pressedAt
        property bool dragging: false
        onPressed: (mouse) => {
            if (!tile.usable) {
                mouse.accepted = false
                return
            }
            pressedAt = Qt.point(mouse.x, mouse.y)
            dragging = false
        }
        onPositionChanged: (mouse) => {
            if (!pressed)
                return
            if (!dragging) {
                if (Math.hypot(mouse.x - pressedAt.x, mouse.y - pressedAt.y) < Qt.styleHints.startDragDistance)
                    return
                dragging = true
                tile.canvas.beginPlacing(tile.kind)
            }
            const p = mapToItem(tile.canvas, mouse.x, mouse.y)
            tile.canvas.updatePlacing(p.x, p.y, (mouse.modifiers & Qt.ControlModifier) !== 0)
        }
        onReleased: (mouse) => {
            if (!dragging) {
                tile.canvas.clickTile(tile.kind)
                return
            }
            dragging = false
            const p = mapToItem(tile.canvas, mouse.x, mouse.y)
            tile.canvas.finishPlacing(p.x, p.y)
        }
    }
```

Update the tile's header comment: `// One tile in the side panel: click it to pick it up, or drag it onto the canvas. A track element, the ruler or a target.`

- [ ] **Step 4: One placing state in `CanvasView.qml`**

Add `import QtQuick.Shapes`. Properties (beside `placingKind`):

```qml
    property string placingBy: ""     // "drag": a tile is being dragged; "click": picked up, the next click puts it down
    property var placingPoint: null   // the photo pixel under the mouse while placing the ruler or a target
    property var rulerFirst: null     // the ruler's first end, once clicked
    property bool lengthBoxOpen: false
    // The ruler as it would land: between the first click and the mouse, or (dragged) 160 screen pixels centred there.
    readonly property var rulerGhost: {
        const p = placingPoint
        if (placingKind !== "ruler" || p === null)
            return null
        if (rulerFirst)
            return { a: rulerFirst, b: p }
        const half = placingBy === "drag" ? 80 / zoom : 0
        return { a: { x: p.x - half, y: p.y }, b: { x: p.x + half, y: p.y } }
    }
```

Replace `beginPlacing`, `updatePlacing` and `finishPlacing` with:

```js
    // A tile dragged onto the canvas.
    function beginPlacing(kind) {
        cancelPlacing()
        placingKind = kind
        placingBy = "drag"
    }

    // A tile clicked: it is picked up and follows the mouse until a canvas click puts it down.
    function pickUp(kind) {
        cancelPlacing()
        placingKind = kind
        placingBy = "click"
        canvas.forceActiveFocus()
        TrackStore.message = placingHint(kind)
    }

    // Clicking the tile that is picked up drops it; any other tile is picked up instead.
    function clickTile(kind) {
        if (placingBy === "click" && placingKind === kind)
            cancelPlacing()
        else
            pickUp(kind)
    }

    function cancelPlacing() {
        if (placingBy === "click")
            TrackStore.message = ""
        placingKind = ""
        placingBy = ""
        ghost = null
        placingPoint = null
        rulerFirst = null
    }

    function placingHint(kind) {
        if (kind === "ruler")
            return rulerFirst ? qsTr("Click the other end · Esc to cancel")
                              : qsTr("Click one end of something you know the length of · Esc to cancel")
        if (kind === "origin")
            return qsTr("Click where Origin goes · Esc to cancel")
        if (kind === "direction")
            return qsTr("Click where Direction goes · Esc to cancel")
        return qsTr("Click where the %1 goes · Esc to cancel").arg(Elements.NAMES[kind])
    }

    function openLengthBox() {
        lengthBoxOpen = true
    }

    function updatePlacing(sx, sy, ctrl) {
        if (!insideCanvas(sx, sy)) {
            ghost = null
            placingPoint = null
            return
        }
        if (Elements.TYPES.indexOf(placingKind) < 0) {
            placingPoint = toWorld(sx, sy)
            return
        }
        if (!(mpp > 0)) {
            ghost = null
            return
        }
        const w = toWorld(sx, sy)
        let g = { id: "ghost", type: placingKind, x: w.x * mpp, y: w.y * mpp, rotation: 0,
                  props: Elements.defaults(placingKind), joins: { A: null, B: null }, snap: null }
        const snap = ctrl ? null : Snapping.findSnap(TrackStore.track.elements, g, snapMetres())
        if (snap) {
            Object.assign(g, Snapping.placeToJoin(g, snap.ownEnd, TrackStore.element(snap.targetId), snap.targetEnd))
            g.snap = { ownEnd: snap.ownEnd, id: snap.targetId, end: snap.targetEnd }
        }
        ghost = g
    }

    // A dragged tile let go.
    function finishPlacing(sx, sy) {
        const kind = placingKind
        const g = ghost
        cancelPlacing()
        if (insideCanvas(sx, sy))
            putDown(kind, toWorld(sx, sy), g, null)
    }

    // A canvas click while a tile is picked up. The ruler's first click only sets its first end.
    function clickPlace(sx, sy, ctrl) {
        const kind = placingKind
        const w = toWorld(sx, sy)
        if (kind === "ruler" && !rulerFirst) {
            rulerFirst = w
            TrackStore.message = placingHint(kind)
            return
        }
        if (kind === "ruler" && distance(rulerFirst, w) * zoom < 3)
            return                          // the other end must be somewhere else
        updatePlacing(sx, sy, ctrl)
        const g = ghost
        const ends = kind === "ruler" ? { a: rulerFirst, b: w } : null
        cancelPlacing()
        putDown(kind, w, g, ends)
    }

    // Puts a tile down at photo pixel w. A dragged ruler lands centred there, 160 screen pixels long; a clicked one
    // between its two clicks. A ruler without a length opens the length box.
    function putDown(kind, w, g, rulerEnds) {
        if (kind === "ruler") {
            const half = 80 / zoom
            const ends = rulerEnds || { a: { x: w.x - half, y: w.y }, b: { x: w.x + half, y: w.y } }
            TrackStore.run("setRuler", { a: ends.a, b: ends.b, realLength: 0 })
            TrackStore.select("ruler")
            lengthBoxOpen = true
        } else if (kind === "origin" || kind === "direction") {
            TrackStore.run("setTarget", { which: kind, point: { x: w.x, y: w.y } })
            TrackStore.select(kind)
        } else if (g) {
            TrackStore.run("add", { type: kind, x: g.x, y: g.y, rotation: g.rotation, snap: g.snap })
            TrackStore.selectLast()
        }
        TrackStore.seal()
    }
```

In `pressAt`, right after `canvas.forceActiveFocus()`:

```js
        if (placingBy === "click" && (e.button === Qt.LeftButton || e.button === Qt.RightButton)) {
            if (e.button === Qt.LeftButton)
                clickPlace(e.x, e.y, (e.modifiers & Qt.ControlModifier) !== 0)
            else
                cancelPlacing()
            return
        }
```

In `moveTo`, after the `hover`/`hoverNode` lines from Task 7:

```js
        if (placingBy === "click")
            updatePlacing(e.x, e.y, (e.modifiers & Qt.ControlModifier) !== 0)
```

In `Keys.onPressed`:

```js
        if (e.key === Qt.Key_Escape && placingBy !== "") {
            cancelPlacing()
            e.accepted = true
        }
```

In the world `Item`, after `TargetsView { ... }`:

```qml
        // A ruler or target being placed, where it would land.
        Item {
            visible: canvas.placingPoint !== null
            opacity: 0.6
            Image {
                visible: canvas.placingKind === "origin" || canvas.placingKind === "direction"
                source: "qrc:/qt/qml/Conestructor/assets/images/crosshair.svg"
                width: 32 / canvas.zoom
                height: width
                x: canvas.placingPoint ? canvas.placingPoint.x - width / 2 : 0
                y: canvas.placingPoint ? canvas.placingPoint.y - height / 2 : 0
                sourceSize: Qt.size(64, 64)
            }
            Shape {
                visible: canvas.rulerGhost !== null
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "#f5cb42"
                    strokeWidth: 2 / canvas.zoom
                    fillColor: "transparent"
                    startX: canvas.rulerGhost ? canvas.rulerGhost.a.x : 0
                    startY: canvas.rulerGhost ? canvas.rulerGhost.a.y : 0
                    PathLine {
                        x: canvas.rulerGhost ? canvas.rulerGhost.b.x : 0
                        y: canvas.rulerGhost ? canvas.rulerGhost.b.y : 0
                    }
                }
            }
            Repeater {
                model: canvas.rulerGhost ? [canvas.rulerGhost.a, canvas.rulerGhost.b] : []
                Rectangle {
                    required property var modelData
                    width: 12 / canvas.zoom
                    height: width
                    radius: width / 2
                    x: modelData.x - width / 2
                    y: modelData.y - height / 2
                    color: "#f5cb42"
                }
            }
        }
```

At the very end of `CanvasView.qml`'s root item, after the `Menu`:

```qml
    // After the MouseArea, so clicks in the box reach it.
    RulerLengthBox { canvas: canvas }
```

- [ ] **Step 5: Create `app/qml/RulerLengthBox.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/units.mjs" as Units

// Beside a ruler just put down without a length: "Real length", ready for typing in the display units. Enter sets it
// (its own undo step); Esc closes the box and leaves the length unset. It closes for good if the ruler goes.
Rectangle {
    id: box
    objectName: "rulerLengthBox"
    required property CanvasView canvas

    readonly property var ruler: TrackStore.track.ruler
    readonly property var middle: ruler ? canvas.toScreen((ruler.a.x + ruler.b.x) / 2, (ruler.a.y + ruler.b.y) / 2) : null
    property bool bad: false

    visible: canvas.lengthBoxOpen && ruler !== null && !(ruler.realLength > 0)
    width: row.implicitWidth + 16
    height: row.implicitHeight + 12
    radius: 4
    color: "#333333"
    border.color: "#f5cb42"
    x: middle ? middle.x - width / 2 : 0
    y: middle ? middle.y + 16 : 0

    onRulerChanged: if (!ruler) canvas.lengthBoxOpen = false
    onVisibleChanged: {
        if (visible) {
            input.text = ""
            bad = false
            input.forceActiveFocus()
        }
    }

    function apply() {
        const metres = Units.parse(input.text, Settings.units)
        if (isNaN(metres) || !(metres > 0)) {
            bad = true
            return
        }
        const r = ruler
        TrackStore.run("setRuler", { a: r.a, b: r.b, realLength: Math.min(1000, Math.max(0.1, metres)) })
        TrackStore.seal()
        canvas.lengthBoxOpen = false
        canvas.forceActiveFocus()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Label {
            text: qsTr("Real length")
            color: "#f0f0f0"
        }
        TextField {
            id: input
            Layout.preferredWidth: 100
            color: box.bad ? "#ff6b6b" : "#f0f0f0"
            placeholderText: qsTr("Type it here")
            selectByMouse: true
            onTextEdited: box.bad = false
            onAccepted: box.apply()
            Keys.onEscapePressed: {
                box.canvas.lengthBoxOpen = false
                box.canvas.forceActiveFocus()
            }
        }
    }
}
```

Add `qml/RulerLengthBox.qml` to `QML_FILES` in `app/CMakeLists.txt`.

- [ ] **Step 6: Run everything**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: all pass. The part 1 test `draggingTargetsAndTheRulerUndoesAsOneStep` calls `beginPlacing`/`finishPlacing` directly and still works; its ruler now opens the length box, which it ignores.

- [ ] **Step 7: Commit**

```bash
git add app/CMakeLists.txt app/qml app/tests/tst_qmlload.cpp
git commit -m "Tiles place by clicking as well as dragging; the ruler by two clicks, then its length typed on the spot; ghosts for the ruler and targets" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: The coach card and the highlighted checklist

**Files:**
- Modify: `app/qml/logic/setup.mjs` (`current`, `CARDS`)
- Create: `app/qml/CoachCard.qml`
- Modify: `app/qml/SetupChecklist.qml`
- Modify: `app/qml/Main.qml` (the card; the banner below it)
- Modify: `app/CMakeLists.txt` (add `qml/CoachCard.qml`)
- Test: `app/tests/qml/tst_setup.qml`; `app/tests/tst_qmlload.cpp` (`theCoachCardWalksThroughSetup`)

**Interfaces:**
- Consumes: `CanvasView.pickUp`, `openLengthBox`, `RulerLengthBox` (Task 8).
- Produces: `Setup.current(track) -> "photo" | "ruler" | "rulerLength" | "origin" | "direction" | ""`; `Setup.CARDS[step] -> { number, title, text, button?, kind? }`; `CoachCard` (`objectName: "coachCard"`, property `step`); checklist rows `setupStep1`..`setupStep4` with a `current` property; title label `setupTitle`.

- [ ] **Step 1: Write the failing tests**

`app/tests/qml/tst_setup.qml`:

```qml
    function test_theCurrentStepIsTheFirstNotDone() {
        compare(Setup.current(Commands.emptyTrack()), "photo")
        const steps = [["setPhoto", { kind: "blueprint" }]]
        compare(Setup.current(after(steps)), "ruler")
        steps.push(["setTarget", { which: "origin", point: { x: 50, y: 50 } }])
        compare(Setup.current(after(steps)), "ruler", "placing Origin early does not skip the ruler")
        steps.push(["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 0 }])
        compare(Setup.current(after(steps)), "rulerLength")
        steps.push(["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 }])
        compare(Setup.current(after(steps)), "direction")
        steps.push(["setTarget", { which: "direction", point: { x: 55, y: 50 } }])
        compare(Setup.current(after(steps)), "direction", "too close to Origin")
        steps.push(["setTarget", { which: "direction", point: { x: 150, y: 50 } }])
        compare(Setup.current(after(steps)), "")
    }

    function test_everyStepHasACard() {
        for (const step of ["photo", "ruler", "rulerLength", "origin", "direction"]) {
            const card = Setup.CARDS[step]
            verify(card.title.startsWith("Step " + card.number + " of 4: "), step)
            verify(card.text.length > 20, step)
        }
        compare(Setup.CARDS.photo.button, undefined)
        compare(Setup.CARDS.ruler.button, "Place the ruler")
        compare(Setup.CARDS.ruler.kind, "ruler")
        compare(Setup.CARDS.rulerLength.kind, "rulerLength")
        compare(Setup.CARDS.origin.button, "Place Origin")
        compare(Setup.CARDS.direction.kind, "direction")
    }
```

`app/tests/tst_qmlload.cpp`:

```cpp
    // A new track shows the coach card for the step to do now; its buttons start each step; the matching checklist row
    // is highlighted; the card goes when setup is done and comes back when a step comes undone. The banner sits below
    // the card.
    void theCoachCardWalksThroughSetup()
    {
        Loaded w;
        QVERIFY(w.load(false));
        QQuickItem *card = w.named(QStringLiteral("coachCard"));
        QVERIFY(card && card->isVisible());
        auto step = [&]() { return card->property("step").toString(); };
        auto row = [&](int n) { return w.named(QStringLiteral("setupStep%1").arg(n)); };
        auto press = [&](const QString &text) {
            QQuickItem *button = findButton(w.window, text);
            QVERIFY2(button, qPrintable(text));
            w.clickItem(button);
        };
        QCOMPARE(step(), QStringLiteral("photo"));
        QVERIFY(row(1)->property("current").toBool());
        QCOMPARE(w.named(QStringLiteral("setupTitle"))->property("text").toString(), QStringLiteral("Setup: start here"));

        QMetaObject::invokeMethod(w.store, "report", Q_ARG(QVariant, QStringLiteral("A note")), Q_ARG(QVariant, QVariant()));
        QQuickItem *banner = findBanner(w.window);
        QVERIFY(banner->y() >= card->y() + card->height());

        press(QStringLiteral("Use the blueprint"));
        QCOMPARE(step(), QStringLiteral("ruler"));
        QVERIFY(row(2)->property("current").toBool());
        QVERIFY(row(3)->opacity() < 1);

        press(QStringLiteral("Place the ruler"));
        QCOMPARE(w.canvas->property("placingKind").toString(), QStringLiteral("ruler"));
        w.click({ 300, 500 });
        w.click({ 500, 500 });
        QCOMPARE(step(), QStringLiteral("rulerLength"));
        QTRY_VERIFY(w.named(QStringLiteral("rulerLengthBox"))->isVisible());
        QTest::keyClicks(w.window, QStringLiteral("20"));             // a bare number is feet in feet and inches
        QTest::keyClick(w.window, Qt::Key_Return);
        QCOMPARE(step(), QStringLiteral("origin"));

        press(QStringLiteral("Place Origin"));
        w.click({ 400, 600 });
        QCOMPARE(step(), QStringLiteral("direction"));
        press(QStringLiteral("Place Direction"));
        w.click({ 900, 600 });
        QCOMPARE(step(), QString());
        QVERIFY(!card->isVisible());
        QCOMPARE(w.named(QStringLiteral("setupTitle"))->property("text").toString(),
                 QStringLiteral("Setup \u2713 (photo, ruler, targets)"));

        QMetaObject::invokeMethod(w.store, "undo");                  // Direction goes again
        QVERIFY(card->isVisible());
        QCOMPARE(step(), QStringLiteral("direction"));
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: `tst_setup` fails (`Setup.current` is not a function); `theCoachCardWalksThroughSetup` fails (no `coachCard`).

- [ ] **Step 3: The current step and its card (`setup.mjs`)**

Append:

```js
// The step to do now, the first not done: "photo", "ruler" (not placed), "rulerLength" (placed, no scale yet),
// "origin", "direction", or "" once setup is done.
export function current(track) {
    const s = status(track)
    if (!s.photo)
        return "photo"
    if (!s.ruler)
        return track.ruler === null ? "ruler" : "rulerLength"
    if (!s.origin)
        return "origin"
    if (!s.direction)
        return "direction"
    return ""
}

// The coach card for each step: why it matters and what to do. `button` starts the step: `kind` is the tile it picks
// up, or "rulerLength" to open the ruler's length box. The photo step has its own two buttons.
export const CARDS = {
    photo: {
        number: 1, title: "Step 1 of 4: Lot photo",
        text: "Start with a birdseye photo of the lot, or use the blueprint to sketch without one."
    },
    ruler: {
        number: 2, title: "Step 2 of 4: Ruler",
        text: "The ruler sets the photo's scale. Click one end of something you know the length of, such as a "
              + "parking-space line, then the other end.",
        button: "Place the ruler", kind: "ruler"
    },
    rulerLength: {
        number: 2, title: "Step 2 of 4: Ruler",
        text: "Now type how long that really is, in the box beside the ruler.",
        button: "Type its length", kind: "rulerLength"
    },
    origin: {
        number: 3, title: "Step 3 of 4: Origin",
        text: "Every cone is measured from Origin. Put it on something you can find on the real lot, such as the base "
              + "of a light pole or a drain.",
        button: "Place Origin", kind: "origin"
    },
    direction: {
        number: 4, title: "Step 4 of 4: Direction",
        text: "x points from Origin toward Direction. Pick a second landmark well away from Origin: farther is more "
              + "accurate.",
        button: "Place Direction", kind: "direction"
    }
}
```

- [ ] **Step 4: Create `app/qml/CoachCard.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/setup.mjs" as Setup

// The setup step to do now, at the top of the canvas while setup is not done: what it is for, what to do, and a button
// that starts it. It goes once setup is done and comes back if a step comes undone.
Rectangle {
    id: card
    objectName: "coachCard"
    required property CanvasView canvas
    signal loadPhoto()
    signal useBlueprint()

    readonly property string step: Setup.current(TrackStore.track)
    readonly property var info: step !== "" ? Setup.CARDS[step] : null

    visible: info !== null
    width: Math.min(520, canvas.width - 40)
    height: column.implicitHeight + 24
    radius: 8
    color: "#2b2b2b"
    border.color: "#2f6fd6"
    border.width: 2

    // Clicks on the card stay on the card (the canvas under it would select or pan); the wheel still zooms.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: (w) => w.accepted = false
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 6

        Label {
            text: card.info ? card.info.title : ""
            font.bold: true
            font.pixelSize: 15
            color: "#ffffff"
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: card.info ? card.info.text : ""
            color: "#d8d8d8"
        }
        RowLayout {
            spacing: 8
            Button {
                visible: card.step === "photo"
                text: qsTr("Load lot photo…")
                focusPolicy: Qt.NoFocus
                onClicked: card.loadPhoto()
            }
            Button {
                visible: card.step === "photo"
                text: qsTr("Use the blueprint")
                focusPolicy: Qt.NoFocus
                onClicked: card.useBlueprint()
            }
            Button {
                visible: card.info !== null && card.info.button !== undefined
                text: card.info && card.info.button ? card.info.button : ""
                focusPolicy: Qt.NoFocus
                onClicked: {
                    if (card.info.kind === "rulerLength")
                        card.canvas.openLengthBox()
                    else
                        card.canvas.pickUp(card.info.kind)
                }
            }
        }
    }
}
```

Add `qml/CoachCard.qml` to `QML_FILES`.

- [ ] **Step 5: Highlight the checklist (`SetupChecklist.qml`)**

Add the current step number and a row wrapper, retitle, and reword the hints for clicking:

```qml
    // The step to do now (1 to 4), or 0 once setup is done: its row is highlighted and the rows after it dimmed.
    readonly property int currentNumber: {
        const step = Setup.current(TrackStore.track)
        return step === "" ? 0 : Setup.CARDS[step].number
    }

    // One step's row: highlighted when it is the step to do now, dimmed when it comes later.
    component StepRow: Rectangle {
        required property int number
        required property bool ticked
        readonly property bool current: number === checklist.currentNumber
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 8
        radius: 4
        color: current ? "#22324d" : "transparent"
        border.color: current ? "#2f6fd6" : "transparent"
        opacity: !ticked && checklist.currentNumber > 0 && number > checklist.currentNumber ? 0.45 : 1
        ColumnLayout {
            id: inner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            spacing: 2
        }
    }
```

The title label gets `objectName: "setupTitle"` and `text: checklist.done ? qsTr("Setup ✓ (photo, ruler, targets)") : qsTr("Setup: start here")`.

The photo `ColumnLayout` becomes a `StepRow { objectName: "setupStep1"; visible: checklist.open; number: 1; ticked: checklist.status.photo; ... }` holding the same two rows. Each `Step` is wrapped:

```qml
    StepRow {
        objectName: "setupStep2"
        visible: checklist.open
        number: 2
        ticked: checklist.status.ruler
        Step {
            canvas: checklist.canvas
            number: 2
            kind: "ruler"
            name: qsTr("Ruler")
            colour: "#f5cb42"
            ticked: checklist.status.ruler
            placed: TrackStore.track.ruler !== null
            hint: qsTr("Click it, then click both ends of something you know the length of, such as a parking space; then type its real length.")
        }
    }
```

with `setupStep3` (Origin, hint `qsTr("Click it, then click a spot you can find on the real lot. x and y are measured from here.")`) and `setupStep4` (Direction, hint `qsTr("Click it, then click a second landmark well away from Origin. x points from Origin toward here.")`) the same way.

- [ ] **Step 6: Put the card on the canvas (`Main.qml`)**

Inside `CanvasView { id: canvasView ... }`, before the `ErrorBanner`:

```qml
            CoachCard {
                id: coach
                canvas: canvasView
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                onLoadPhoto: photoDialog.open()
                onUseBlueprint: window.useBlueprint()
            }
```

and the banner's anchors become:

```qml
                anchors.top: coach.visible ? coach.bottom : parent.top
                anchors.topMargin: coach.visible ? 8 : 12
```

- [ ] **Step 7: Run everything**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: all pass. If an older window test on an empty track clicks where the card now sits (top centre of the canvas), move its point below the card and say so in the commit message.

- [ ] **Step 8: Look at it**

Run: `powershell -NoProfile -File app\tests\grab.ps1` with no demo track, and open the screenshot it saves: the card reads at the top, the checklist's first row is highlighted.

- [ ] **Step 9: Commit**

```bash
git add app/CMakeLists.txt app/qml app/tests
git commit -m "Coach card for the setup step to do now; the checklist highlights it and dims the steps after" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Part 2's minors 2, 3, 5, 6 and 7

**Files:**
- Modify: `app/services/TrackFile.h`, `app/services/TrackFile.cpp` (`absolutePath`, `folderUrl`, `fileUrl`)
- Modify: `app/qml/TrackStore.qml` (`backedUpText`, `deleteBackup()`; `saveTo` uses it)
- Modify: `app/qml/Main.qml` (`backUp`, the dialogs, `start`, `saveAsStart`, `saveAs`, the Restore handler)
- Test: `app/tests/tst_trackfile.cpp`; `app/tests/tst_qmlload.cpp`

**Interfaces:**
- Consumes: the `Loaded` helper.
- Produces: `TrackFile.absolutePath(path) -> string` (native separators; `""` stays `""`), `TrackFile.folderUrl(path) -> url`, `TrackFile.fileUrl(path) -> url`; `TrackStore.backedUpText`, `TrackStore.deleteBackup()`; `Main.saveAsStart() -> { folder, file } | null`.

- [ ] **Step 1: Write the failing tests**

`app/tests/tst_trackfile.cpp`, in the class:

```cpp
    // Minor 3 and 6: a path from the command line is made absolute; Save As starts beside the open track.
    void pathsForTheCommandLineAndSaveAs()
    {
        TrackFile files;
        const QString old = QDir::currentPath();
        QDir::setCurrent(dir.path());
        QCOMPARE(files.absolutePath(QStringLiteral("Relative.cone")),
                 QDir::toNativeSeparators(QDir(dir.path()).filePath(QStringLiteral("Relative.cone"))));
        QCOMPARE(files.absolutePath(QString()), QString());
        QDir::setCurrent(old);
        const QString path = QDir(dir.path()).filePath(QStringLiteral("Duck pond.cone"));
        QCOMPARE(files.folderUrl(path), QUrl::fromLocalFile(dir.path()));
        QCOMPARE(files.fileUrl(path), QUrl::fromLocalFile(path));
    }
```

(Use the test class's existing `QTemporaryDir` member; if it is named differently, use that name.)

`app/tests/tst_qmlload.cpp`:

```cpp
    // Minor 2: after Don't save and a refused Open, the still-unsaved track is backed up again.
    void aDiscardedTrackIsBackedUpAgain()
    {
        Loaded w;
        QVERIFY(w.load(true));
        QObject *files = w.engine.singletonInstance<QObject *>("Conestructor", "TrackFile");
        auto backup = [&]() {
            QVariantMap found;
            QMetaObject::invokeMethod(files, "findBackup", Q_RETURN_ARG(QVariantMap, found));
            return found;
        };
        w.run(QStringLiteral("place"), { { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } });
        QMetaObject::invokeMethod(w.window, "backUp");
        QVERIFY(!backup().isEmpty());
        QMetaObject::invokeMethod(w.window, "openRecent", Q_ARG(QVariant, dir.filePath(QStringLiteral("Gone.cone"))));
        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("unsavedDialog"));
        QTRY_VERIFY(dialog->property("opened").toBool());
        w.clickItem(findButton(w.window, QStringLiteral("Don't save")));
        QTRY_VERIFY(backup().isEmpty());
        QVERIFY(w.store->property("dirty").toBool());         // the open was refused: the track is still unsaved
        QMetaObject::invokeMethod(w.window, "backUp");
        QVERIFY(!backup().isEmpty());
        QMetaObject::invokeMethod(files, "deleteBackup");
    }

    // Minor 3: a relative path on the command line is opened and kept as an absolute one.
    void aRelativePathAtStartBecomesAbsolute()
    {
        const QString path = dir.filePath(QStringLiteral("Relative.cone"));
        {
            Loaded w;
            QVERIFY(w.load(true));
            QVariant ok;
            QMetaObject::invokeMethod(w.store, "saveTo", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, path));
            QVERIFY(ok.toBool());
        }
        Loaded w;
        QVERIFY(w.load(false));
        // No backup from an earlier test, so start() goes straight to the file.
        QMetaObject::invokeMethod(w.engine.singletonInstance<QObject *>("Conestructor", "TrackFile"), "deleteBackup");
        const QString old = QDir::currentPath();
        QDir::setCurrent(dir.path());
        QMetaObject::invokeMethod(w.window, "start", Q_ARG(QVariant, QStringLiteral("Relative.cone")));
        QDir::setCurrent(old);
        QCOMPARE(w.store->property("elementCount").toInt(), 4);
        QCOMPARE(w.store->property("filePath").toString(), QDir::toNativeSeparators(path));
    }

    // Minor 5: a long track name wraps in the unsaved-changes question.
    void aLongNameWrapsInTheQuestion()
    {
        Loaded w;
        QVERIFY(w.load(true));
        w.store->setProperty("filePath", dir.filePath(QString(120, QChar('x')) + QStringLiteral(".cone")));
        w.run(QStringLiteral("place"), { { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } });
        QMetaObject::invokeMethod(w.window, "newTrack");
        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("unsavedDialog"));
        QTRY_VERIFY(dialog->property("opened").toBool());
        QQuickItem *question = w.named(QStringLiteral("unsavedQuestion"));
        QVERIFY(question);
        QVERIFY(question->property("lineCount").toInt() > 1);
        QVERIFY(question->width() <= dialog->property("availableWidth").toDouble());
        w.clickItem(findButton(w.window, QStringLiteral("Cancel")));
    }

    // Minor 6: Save As starts in the open track's folder with its name; an Untitled track has no start of its own.
    void saveAsStartsBesideTheTrack()
    {
        Loaded w;
        QVERIFY(w.load(true));
        QVariant start;
        QMetaObject::invokeMethod(w.window, "saveAsStart", Q_RETURN_ARG(QVariant, start));
        QVERIFY(isNull(start));
        const QString path = dir.filePath(QStringLiteral("Duck pond.cone"));
        w.store->setProperty("filePath", path);
        QMetaObject::invokeMethod(w.window, "saveAsStart", Q_RETURN_ARG(QVariant, start));
        const QVariantMap s = plain(start).toMap();
        QCOMPARE(s.value("folder").toUrl(), QUrl::fromLocalFile(dir.path()));
        QCOMPARE(s.value("file").toUrl(), QUrl::fromLocalFile(path));
    }

    // Minor 7: a backup that cannot be read says so once and is removed, so it is not offered again.
    void anUnreadableBackupIsRemoved()
    {
        QString backupPath;
        {
            Loaded w;
            QVERIFY(w.load(true));
            w.run(QStringLiteral("place"), { { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } });
            QMetaObject::invokeMethod(w.window, "backUp");
            QObject *files = w.engine.singletonInstance<QObject *>("Conestructor", "TrackFile");
            QVariantMap found;
            QMetaObject::invokeMethod(files, "findBackup", Q_RETURN_ARG(QVariantMap, found));
            backupPath = found.value("path").toString();
            QVERIFY(!backupPath.isEmpty());
        }
        QFile broken(backupPath);
        QVERIFY(broken.open(QIODevice::WriteOnly | QIODevice::Truncate));
        broken.write("not a track");
        broken.close();

        Loaded w;
        QVERIFY(w.load(false));
        QMetaObject::invokeMethod(w.window, "start", Q_ARG(QVariant, QString()));
        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("restoreDialog"));
        QTRY_VERIFY(dialog->property("opened").toBool());
        w.clickItem(findButton(w.window, QStringLiteral("Restore")));
        QTRY_COMPARE(findBanner(w.window)->property("text").toString(),
                     QStringLiteral("The backup couldn't be read and has been removed."));
        QObject *files = w.engine.singletonInstance<QObject *>("Conestructor", "TrackFile");
        QVariantMap found;
        QMetaObject::invokeMethod(files, "findBackup", Q_RETURN_ARG(QVariantMap, found));
        QVERIFY(found.isEmpty());
        QCOMPARE(w.store->property("elementCount").toInt(), 0);
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\build.ps1`
Expected: the build fails (`TrackFile` has no `absolutePath`, `folderUrl`, `fileUrl`). Add the declarations of Step 3 with bodies returning `{}`, build again, and run `powershell -NoProfile -File app\tests\run.ps1 -NoQml`: the five new window tests and `pathsForTheCommandLineAndSaveAs` FAIL.

- [ ] **Step 3: TrackFile helpers**

`TrackFile.h`, after `exists`:

```cpp
    // A path from the command line made absolute (native separators); "" stays "".
    Q_INVOKABLE QString absolutePath(const QString &path) const;
    // Where Save As starts for the track at `path`: its folder, and the file itself.
    Q_INVOKABLE QUrl folderUrl(const QString &path) const;
    Q_INVOKABLE QUrl fileUrl(const QString &path) const;
```

`TrackFile.cpp`:

```cpp
QString TrackFile::absolutePath(const QString &path) const
{
    return path.isEmpty() ? QString() : QDir::toNativeSeparators(QFileInfo(path).absoluteFilePath());
}

QUrl TrackFile::folderUrl(const QString &path) const
{
    return QUrl::fromLocalFile(QFileInfo(path).absolutePath());
}

QUrl TrackFile::fileUrl(const QString &path) const
{
    return QUrl::fromLocalFile(QFileInfo(path).absoluteFilePath());
}
```

- [ ] **Step 4: Forget the last backup whenever the backup is deleted (`TrackStore.qml`)**

```qml
    // The track text last backed up (Main's two-minute timer), so an unchanged track is not written again. Deleting the
    // backup forgets it, so a track still unsaved afterwards is backed up again.
    property string backedUpText: ""

    function deleteBackup() {
        TrackFile.deleteBackup()
        backedUpText = ""
    }
```

In `saveTo`, replace `TrackFile.deleteBackup()` with `deleteBackup()`.

- [ ] **Step 5: Main.qml**

- Remove `property string backedUpText: ""`; `backUp()` uses `TrackStore.backedUpText` in both places.
- Every `TrackFile.deleteBackup()` in `onClosing`, `unsavedDialog.onDiscarded` and `restoreDialog.onDiscarded` becomes `TrackStore.deleteBackup()`.
- `start(file)` begins with `file = TrackFile.absolutePath(file)`.
- Save As:

```js
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
```

- The unsaved question wraps:

```qml
        Label {
            objectName: "unsavedQuestion"
            width: unsavedDialog.availableWidth
            wrapMode: Text.Wrap
            text: qsTr("Save changes to %1?").arg(TrackStore.name)
        }
```

- The Restore handler removes a backup it cannot read:

```js
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
```

- [ ] **Step 6: Run everything**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: all pass, part 2's backup tests included.

- [ ] **Step 7: Commit**

```bash
git add app/services app/qml app/tests
git commit -m "Part 2's minors: back up again after Don't save, absolute command-line paths, a long name wraps, Save As starts beside the track, an unreadable backup is removed" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Docs, comments and the clean-clone check

**Files:**
- Modify: `README.md`, `app/qml/PreferencesDialog.qml:7`, `app/qml/logic/conerows.mjs:1-3`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing new; the branch is ready for the final review.

- [ ] **Step 1: README**

Replace the status note with:

```markdown
> **v1 in progress.** Parts 1 to 3 of 6 are done: the core canvas (metres underneath, zoom and pan, undo, units, cone
> preview); setup and track files (a setup checklist, `.cone` files with the photo inside, direction arrows, Reverse
> direction, typed rotation, multi-select); and ease of use (a coach card through setup, click-to-place, gate nodes that
> pivot and stretch, a fold warning, turns up to 360°, a line tool for walls). A full guide comes with v1.0.0.
```

In the description, "(straights, slaloms, chicanes, turns)" becomes "(straights, slaloms, chicanes, turns, and lines for walls)". In Layout, `coneRoutes.py` "moves to `server/` in part 5".

- [ ] **Step 2: Comments**

`PreferencesDialog.qml`: `// Edit > Preferences. One section so far, Units; parts 4 and 5 add Cones, Car and Team.`
`conerows.mjs` header's last sentence: `Part 4 adds density notches; this spacing becomes its notch 3, "SAE standard".`

- [ ] **Step 3: Check nothing sensitive went in**

Run: `git diff main --stat` and `git grep -n -E "([0-9]{1,3}\.){3}[0-9]{1,3}" -- . ":!*.png" ":!*.ttf"`, then search the
branch for the team server's host name (known to the owner and the session, never typed into the repo).
Expected: no server address or home-network address; stop and ask if anything looks like one.

- [ ] **Step 4: Clean clone builds without the map images**

```powershell
$clone = Join-Path $env:TEMP "conestructor-clean"
Remove-Item -Recurse -Force $clone -ErrorAction SilentlyContinue
git clone --branch part3-ease-of-use . $clone
Test-Path "$clone\app\assets\images\duckPondBirdeye.png"    # False
powershell -NoProfile -File "$clone\app\tests\build.ps1"
powershell -NoProfile -File "$clone\app\tests\run.ps1"
```

Expected: `False`, then the build succeeds and `ctest: passed`, `qml: N passed, 0 failed`. (Run the clone's build in the background if it takes over two minutes.)

- [ ] **Step 5: Commit**

```bash
git add README.md app/qml/PreferencesDialog.qml app/qml/logic/conerows.mjs
git commit -m "README: part 3 status; comments follow the six-part roadmap" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Then the final whole-branch review, the owner's check (spec, "Owner check"), and merge to `main` and push after a look at what is being pushed.
