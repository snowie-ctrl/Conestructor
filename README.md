# Conestructor

> **v1 in progress.** Part 1 of 5 (the core canvas) is done: metres underneath, zoom and pan, undo, units, cone
> preview and a JSON export. A full guide comes with v1.0.0.

Conestructor is a desktop app for designing Formula SAE autocross tracks ahead of time. You lay track elements
(straights, slaloms, chicanes, turns) over a birdseye photo of the lot. A ruler sets the real-world scale and two
targets set the origin and the x-axis. Post-processing then works out where every cone goes, in order, in metres. A
companion mobile app (coming later) will turn those positions into GPS points and guide someone to each cone, so the
track on the lot matches the one on screen.

## Build

Qt 6.8 or newer (Quick, Quick Controls, Shapes, Svg), CMake 3.16+, a C++17 compiler. Open `app/CMakeLists.txt` in
Qt Creator and run, or on Windows with Qt 6.11 and MSVC 2022:

    powershell -File app\tests\build.ps1     # app and tests
    powershell -File app\tests\run.ps1       # C++ tests, then the logic tests

The scripts default to the maintainer's install paths; set `CONESTRUCTOR_QT`, `CONESTRUCTOR_QT_TOOLS` and
`CONESTRUCTOR_VCVARS` to point at yours.

## Layout

- `app/`: the desktop app. `qml/logic/` holds the geometry as plain JavaScript modules (elements, snapping, the
  export frame, post-processing, units, undo); `qml/` draws it; `services/` is a little C++ (settings, files).
- `app/tests/`: C++ tests (Qt Test) and logic tests (`tests/qml`, qmltestrunner), including a check that the cone
  placement matches the prototype's.
- `coneRoutes.py`: the server's Flask routes for uploaded tracks (moves to `server/` in part 4).
- `docs/superpowers/`: the v1 specs and plans.

## Licence

MIT (see `LICENSE`). The Ubuntu Mono font keeps its own licence (`app/assets/fonts/Ubuntu_Mono/UFL.txt`).
