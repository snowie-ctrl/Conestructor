# Conestructor

> **v1 in progress.** Parts 1 to 3 of 6 are done: the core canvas (metres underneath, zoom and pan, undo, units, cone
> preview); setup and track files (a setup checklist, `.cone` files with the photo inside, direction arrows, Reverse
> direction, typed rotation, multi-select); and ease of use (a coach card through setup, click-to-place, gate nodes that
> pivot and stretch, a fold warning, turns up to 360°, a line tool for walls). A full guide comes with v1.0.0.

Conestructor is a desktop app for designing Formula SAE autocross tracks ahead of time. You lay track elements
(straights, slaloms, chicanes, turns, and lines for walls) over a birdseye photo of the lot. A ruler sets the
real-world scale and two targets set the origin and the x-axis. Post-processing then works out where every cone goes,
in order, in metres. A companion mobile app (coming later) will turn those positions into GPS points and guide someone
to each cone, so the track on the lot matches the one on screen.

## Track files

Each track is one `.cone` file: plain JSON holding every cone in metres, in driving order, the design for editing it
again, and the lot photo. Other apps can read the cones: the format is described in
[docs/cone-format.md](docs/cone-format.md), with a [JSON Schema](docs/cone-format.schema.json).

```python
import json

with open("Duck pond autocross.cone", encoding="utf-8") as f:
    track = json.load(f)

for cone in track["cones"]:
    print(cone["index"], cone["type"], cone["x"], cone["y"], cone["heading"])
```

## Build

Qt 6.8 or newer (Quick, Quick Controls, Shapes, Svg), CMake 3.16+, a C++17 compiler. Open `app/CMakeLists.txt` in
Qt Creator and run, or on Windows with Qt 6.11 and MSVC 2022:

    powershell -File app\tests\build.ps1     # app and tests
    powershell -File app\tests\run.ps1       # C++ tests, then the logic tests

The scripts default to the maintainer's install paths; set `CONESTRUCTOR_QT`, `CONESTRUCTOR_QT_TOOLS` and
`CONESTRUCTOR_VCVARS` to point at yours.

## Layout

- `app/`: the desktop app. `qml/logic/` holds the geometry and the file format as plain JavaScript modules (elements,
  snapping, the export frame, post-processing, units, undo, the `.cone` document); `qml/` draws it; `services/` is a
  little C++ (settings, photos, track files).
- `app/tests/`: C++ tests (Qt Test) and logic tests (`tests/qml`, qmltestrunner), including a check that the cone
  placement matches the prototype's.
- `docs/cone-format.md`, `docs/cone-format.schema.json`: the track file format for other apps.
- `coneRoutes.py`: the server's Flask routes for uploaded tracks (moves to `server/` in part 5).
- `docs/superpowers/`: the v1 specs and plans.

## Licence

MIT (see `LICENSE`). The Ubuntu Mono font keeps its own licence (`app/assets/fonts/Ubuntu_Mono/UFL.txt`).
