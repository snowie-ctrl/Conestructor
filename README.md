# Conestructor

> **Prototype.** This is the working prototype. A polished v1.0.0, with a full guide, is on the way.

Conestructor is a desktop app for designing Formula SAE autocross tracks ahead of time. You lay track elements (straights, slaloms, chicanes, hairpins) over a birdseye photo of the lot. A ruler sets the real-world scale and two targets set the origin and the x-axis. Post-processing then works out where every cone goes, in order, in real-world units. A companion mobile app (coming later) will turn those positions into GPS points and guide someone to each cone, so the track on the lot matches the one on screen.

## Build

Qt 6.8 or newer (Quick, Svg), CMake 3.16+, a C++17 compiler. Open `Conestructor/CMakeLists.txt` in Qt Creator and run.

## Layout

- `Conestructor/`: the desktop app (QML UI, C++ export and upload)
- `coneRoutes.py`: the server's Flask routes for uploaded tracks
- `archived/`: earlier QML, kept for reference
