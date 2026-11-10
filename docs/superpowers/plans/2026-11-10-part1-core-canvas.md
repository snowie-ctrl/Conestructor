# Conestructor v1 part 1 (core canvas) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the prototype into a canvas that works in metres underneath: zoom and pan over a lot photo, track elements kept as plain data with real-unit defaults, plain-word settings, unit preferences, rotate/delete/duplicate/undo, cone preview and a JSON export in the new axes, with the prototype's cone geometry ported unchanged.

**Architecture:** The track is one plain JavaScript object held by a QML singleton (`TrackStore`). Every edit is a pure command (`logic/commands.mjs`) recorded on an undo stack; QML only draws `TrackStore.track` and forwards pointer input, which is handled in one place (`CanvasView`) so redraws never interrupt a drag. All geometry (elements, snapping, export frame, post-processing, units, zoom maths) lives in pure `.mjs` modules tested with qmltestrunner; C++ is three small QML singletons (`AppInfo`, `Settings`, `FileIO`).

**Tech Stack:** Qt 6.11.1 (MSVC 2022 64-bit), Qt Quick / Controls (Fusion style) / Shapes, CMake + Ninja, Qt Test (C++), qmltestrunner (QML/JS), PowerShell build and test scripts copied from the owner's Gluttony app.

**Spec:** `docs/superpowers/specs/2026-11-10-v1-roadmap-and-part1-core-canvas-design.md` (section "Part 1: core canvas"; the roadmap and decisions table are context).

## Global Constraints

- The repo is public. Never write the server's public subdomain or the home-network address into code, docs, tests or commit messages; examples use `<public host>`. (Task 1 deletes the prototype's upload code, which holds a LAN address.)
- The two satellite images (`duckPondBirdeye.png`, `riverwindBirdeye.png`) stay gitignored and are bundled only when present at build time. A clean copy of the repo must build without them.
- Files use metres. Export axes: x from the Origin target toward the Direction target; y 90° to the left of x seen from above; headings in degrees counter-clockwise from +x.
- Units on screen are a preference: feet and inches (default), decimal feet, or metres. Saved in `Conestructor.ini` in AppData.
- Licence: MIT. Third-party files (Ubuntu Mono font) keep their own licences.
- Version 0.2.0 from CMake; window title "Conestructor 0.2 — Untitled".
- C++ services are registered as QML singletons with `QML_ELEMENT`/`QML_SINGLETON`, not as context properties.
- Logic lives in pure JavaScript modules in `app/qml/logic/`, tested with qmltestrunner. QML only draws and forwards input.
- Build environment: Qt at `D:\allNewQT6\6.11.1\msvc2022_64`, CMake and Ninja under `D:\allNewQT6\Tools`, MSVC 2022 Community (`vcvars64.bat` before cmake). `app\tests\build.ps1` and `app\tests\run.ps1` wrap all of this.
- Work on branch `part1-core-canvas`; merge to `main` and push only after the owner's check and a look at what is being pushed.
- Every commit message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (passed as a second `-m`).

## Decisions this plan adds to the spec

- **Element frame.** Each element's own frame keeps the prototype's: origin at the middle of its centreline's bounding box, x along its entry direction, y down the screen, headings in degrees clockwise on screen (Qt's convention). This is what lets the cone code port line for line. Element `x, y, rotation` are that origin and rotation in canvas metres.
- **World coordinates on the canvas are photo pixels.** Elements are stored in metres and drawn at metres ÷ metresPerPixel. Ruler ends and targets stay in photo pixels, as the spec says.
- **Undo keeps snapshots.** Each step stores the track before and after (tracks are small plain data), so every inverse is exact by construction. Join and unjoin are folded into the `add` and `place` commands, because a person never joins without moving something. Commands: `newTrack`, `setPhoto`, `setRuler`, `removeRuler`, `setTarget`, `add`, `place` (move or rotate), `setProp`, `remove`, `duplicate`.
- **A ruler change re-glues chains.** Rescaling element positions about the photo origin keeps sizes in metres, which would pull joined ends apart, so after rescaling each joined chain is re-glued from its first element (that element stays on its photo spot).
- **Extra logic modules** beyond the spec's table: `conerows.mjs` (the prototype's cone-row helpers), `viewport.mjs` (zoom and pan maths) and `demo.mjs` (an example track for screenshots and the smoke test).
- **Exit radius default:** 10 m (the prototype's 0 makes a degenerate turn). The track's `nextId` field numbers elements `e1`, `e2`, ….
- **Deleting the ruler** is refused while track elements exist (their sizes depend on it), with a banner.
- **Dev affordances** (copied from Gluttony's pattern): `CONESTRUCTOR_SETTINGS_DIR`, `CONESTRUCTOR_DEMO` (`track` or `cones`) and `CONESTRUCTOR_GRAB` (+ `_DELAY`) let `tests\grab.ps1` save a screenshot without touching the owner's settings.

## Review Focus

1. **Changing the ruler with a joined chain on the canvas** (typing a new real length, or dragging a ruler end): every joined pair of ends must still meet afterwards, and undo must restore every position exactly. Pinned in Task 5 (`test_theRulerRescalesAndKeepsChainsGlued`).
2. **A closed loop** (the last element joined back to the first): post-processing must finish and list every cone once. Pinned in Task 6 (`test_aClosedLoopListsEveryConeOnce`).
3. **Edge settings** (turn angle 0°, a one-cone slalom, no lead-in or lead-out, no sideways shift, no weave): geometry stays finite and each path still starts and ends on its ends. Pinned in Task 3 (`test_pathsStartAndEndOnTheirEnds`).
4. **Deleting a joined element, then undo:** both neighbours' joins come back, not just the deleted element's. Pinned in Task 5 (`test_undoingADeleteRestoresTheNeighboursJoins`).
5. **An `.ini` with an unknown units value** (hand-edited, or from a later version): the app reads it as feet and inches and carries on. Pinned in Task 9 (`aBadValueInTheFileFallsBackToTheDefault`).

## File structure

```
LICENSE                              MIT (new)
README.md                            build and layout lines updated
.gitignore                           app/ paths; app/config/secrets.json
app/                                 (was Conestructor/)
  CMakeLists.txt                     rewritten: static QML module library + app + tests option
  main.cpp                           rewritten: Fusion style, static plugin, dev affordances
  services/AppInfo.h                 version and local backgrounds (QML singleton)
  services/Settings.h/.cpp           units preference in Conestructor.ini (QML singleton)
  services/FileIO.h/.cpp             URL to path; the part 1 JSON cone export (QML singleton)
  qml/Main.qml                       window, menus, layout, dialogs
  qml/TrackStore.qml                 singleton: the track, the undo stack, selection, preview
  qml/CanvasView.qml                 photo + world layer, zoom/pan, all pointer input, labels overlay
  qml/ElementView.qml                draws one element from data
  qml/RulerView.qml                  draws the ruler
  qml/TargetsView.qml                draws Origin, Direction and the arrow between them
  qml/ConePreview.qml                draws placed cones and the route line
  qml/ElementPalette.qml                    tiles dragged onto the canvas
  qml/PropertyPanel.qml              settings of whatever is selected
  qml/PropField.qml                  one unit-aware setting field or switch
  qml/PreferencesDialog.qml          Units
  qml/StatusBar.qml                  message, cursor position in the export frame, zoom
  qml/ErrorBanner.qml                error text with "Show me"
  qml/logic/units.mjs                format/parse lengths, angles and counts
  qml/logic/conerows.mjs             cone rows along a centreline (ported ConeUtils helpers)
  qml/logic/elements.mjs             per-type settings, geometry, ends, cones, hit testing
  qml/logic/snapping.mjs             find snaps, place to join, join/unjoin, keep chains glued
  qml/logic/commands.mjs             the track's shape, every command, the undo stack
  qml/logic/frame.mjs                canvas metres <-> export frame
  qml/logic/postprocess.mjs          checks, cones for the whole track, dedupe, order, stitch
  qml/logic/viewport.mjs             fit, zoom about a point, screen <-> world
  qml/logic/demo.mjs                 example track
  tests/CMakeLists.txt, build.ps1, run.ps1, grab.ps1
  tests/tst_settings.cpp, tst_fileio.cpp, tst_qmlload.cpp
  tests/qml/tst_units.qml, tst_elements.qml, tst_snapping.qml, tst_commands.qml,
            tst_frame.qml, tst_postprocess.qml, tst_portcheck.qml, tst_viewport.qml
  tests/qml/fixtures/prototype.mjs   the prototype's cone code, transcribed (port check reference)
  tests/qml/fixtures/sampletrack.mjs the port check's sample track in both forms
Deleted: archived/, Conestructor/test.cpp, Conestructor/assets/resources.qrc, Conestructor/exportmanager.*,
         every prototype QML file (AppState, CanvasArea, ElementPanel, ElementSpawner, PostProcessor,
         PropertyPanel, elements/*). Git history keeps them; the prototype is commit 2c79b60.
```

---

### Task 1: Housekeeping, build and test scaffolding

**Files:**
- Move: `Conestructor/` → `app/` (`git mv`), then move the two untracked map images by hand
- Delete: `archived/`, `app/test.cpp`, `app/assets/resources.qrc`, `app/exportmanager.h`, `app/exportmanager.cpp`, `app/qml/AppState.qml`, `app/qml/CanvasArea.qml`, `app/qml/ElementPanel.qml`, `app/qml/ElementSpawner.qml`, `app/qml/PostProcessor.qml`, `app/qml/PropertyPanel.qml`, `app/qml/elements/`
- Create: `LICENSE`, `app/services/AppInfo.h`, `app/tests/CMakeLists.txt`, `app/tests/build.ps1`, `app/tests/run.ps1`, `app/tests/grab.ps1`, `app/tests/tst_qmlload.cpp`, `app/tests/qml/.gitkeep`
- Rewrite: `app/CMakeLists.txt`, `app/main.cpp`, `app/qml/Main.qml`, `.gitignore`

**Interfaces:**
- Produces: CMake targets `conestructor_core` (static library owning QML module `Conestructor`, plugin target `conestructor_coreplugin`, plugin class `ConestructorPlugin`) and `appConestructor`; option `CONESTRUCTOR_BUILD_TESTS`; helper `conestructor_test(name SOURCES … LIBS …)`. QML singleton `AppInfo { version: "0.2.0"; shortVersion: "0.2"; localBackgrounds: ["duckPondBirdeye", …] }`. Scripts: `build.ps1`; `run.ps1 [-R regex] [-NoCpp] [-NoQml] [-Qml tst_x.qml]`; `grab.ps1 [-Demo track|cones|''] [-Out path] [-Delay ms]`. Resource URLs: `qrc:/qt/qml/Conestructor/assets/images/<name>`.

- [ ] **Step 1: Create the branch and move the app folder**

```bash
git switch -c part1-core-canvas
git mv Conestructor app
```

Then move the gitignored map images and look at what is left behind (only ignored build output should remain):

```powershell
New-Item -ItemType Directory -Force app\assets\images | Out-Null
foreach ($bg in 'duckPondBirdeye', 'riverwindBirdeye') {
    if (Test-Path "Conestructor\assets\images\$bg.png") { Move-Item "Conestructor\assets\images\$bg.png" "app\assets\images\$bg.png" }
}
Get-ChildItem -Recurse -Force Conestructor -ErrorAction SilentlyContinue | Select-Object -First 20 FullName
```

Expected: only `Conestructor\build\…` and `Conestructor\.qtcreator\…` remain. Leave them; mention them to the owner at the end (their old Qt Creator build folder, safe to delete).

- [ ] **Step 2: Delete what the spec retires**

```bash
git rm -r -q archived app/test.cpp app/assets/resources.qrc app/exportmanager.h app/exportmanager.cpp app/qml/AppState.qml app/qml/CanvasArea.qml app/qml/ElementPanel.qml app/qml/ElementSpawner.qml app/qml/PostProcessor.qml app/qml/PropertyPanel.qml app/qml/elements
```

(The prototype stays readable with `git show 2c79b60:Conestructor/qml/elements/Hairpin.qml` and so on; Task 7 transcribes what the port check needs.)

- [ ] **Step 3: Write `.gitignore` and `LICENSE`**

`.gitignore`:

```gitignore
# Build output
build/
**/build/

# Qt Creator per-user files (contain local paths)
*.user
*.user.*
.qtcreator/
.qtc_clangd/

# Satellite map screenshots of local practice lots (not ours to republish)
app/assets/images/duckPondBirdeye.png
app/assets/images/riverwindBirdeye.png

# The team server's address and keys (part 4)
app/config/secrets.json

# OS / editor noise
.DS_Store
Thumbs.db
.vscode/
.idea/
```

`LICENSE`:

```text
MIT License

Copyright (c) 2026 snowie-ctrl

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

The Ubuntu Mono font in app/assets/fonts/Ubuntu_Mono is under the Ubuntu Font
Licence (app/assets/fonts/Ubuntu_Mono/UFL.txt).
```

- [ ] **Step 4: Write `app/services/AppInfo.h`**

```cpp
#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// What this build is: its version (from CMake) and which local lot pictures were bundled with it. The pictures
// are satellite screenshots kept out of the public repo, so a build has them only when they were present.
class AppInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(QString shortVersion READ shortVersion CONSTANT)
    Q_PROPERTY(QStringList localBackgrounds READ localBackgrounds CONSTANT)

public:
    explicit AppInfo(QObject *parent = nullptr) : QObject(parent) {}

    QString version() const { return QStringLiteral(CONESTRUCTOR_VERSION); }
    // "0.2" for the window title.
    QString shortVersion() const { return version().section(QLatin1Char('.'), 0, 1); }
    // Base names, e.g. "duckPondBirdeye"; the file is qrc:/qt/qml/Conestructor/assets/images/<name>.png.
    QStringList localBackgrounds() const
    {
        return QString::fromLatin1(CONESTRUCTOR_BACKGROUNDS).split(QLatin1Char(','), Qt::SkipEmptyParts);
    }
};
```

- [ ] **Step 5: Rewrite `app/CMakeLists.txt`**

```cmake
cmake_minimum_required(VERSION 3.16)

project(Conestructor VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Svg)

qt_standard_project_setup(REQUIRES 6.8)

# Satellite pictures of local practice lots are kept out of the public repo (map imagery can't be republished);
# bundle them only when present.
set(CONESTRUCTOR_LOCAL_BACKGROUNDS)
set(CONESTRUCTOR_LOCAL_BACKGROUND_FILES)
foreach(bg duckPondBirdeye riverwindBirdeye)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/images/${bg}.png")
        list(APPEND CONESTRUCTOR_LOCAL_BACKGROUNDS ${bg})
        list(APPEND CONESTRUCTOR_LOCAL_BACKGROUND_FILES assets/images/${bg}.png)
    endif()
endforeach()
string(JOIN "," CONESTRUCTOR_BACKGROUND_LIST ${CONESTRUCTOR_LOCAL_BACKGROUNDS})

# The QML module and the small C++ services live in a static library, so the tests load the real thing.
qt_add_library(conestructor_core STATIC)
qt_add_qml_module(conestructor_core
    URI Conestructor
    VERSION 1.0
    QML_FILES
        qml/Main.qml
    SOURCES
        services/AppInfo.h
    RESOURCES
        assets/images/blueprintBackground.png
        assets/images/crosshair.svg
        assets/images/upright-cone.png
        assets/images/sideways-cone.png
        ${CONESTRUCTOR_LOCAL_BACKGROUND_FILES}
)
target_include_directories(conestructor_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_definitions(conestructor_core PUBLIC
    CONESTRUCTOR_VERSION="${PROJECT_VERSION}"
    CONESTRUCTOR_BACKGROUNDS="${CONESTRUCTOR_BACKGROUND_LIST}"
)
target_link_libraries(conestructor_core PUBLIC Qt6::Quick Qt6::QuickControls2)

qt_add_executable(appConestructor main.cpp)
target_link_libraries(appConestructor PRIVATE conestructor_coreplugin Qt6::Quick Qt6::QuickControls2 Qt6::Svg)
set_target_properties(appConestructor PROPERTIES WIN32_EXECUTABLE TRUE MACOSX_BUNDLE TRUE)

include(GNUInstallDirs)
install(TARGETS appConestructor
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

option(CONESTRUCTOR_BUILD_TESTS "Build the tests" OFF)
if(CONESTRUCTOR_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
```

- [ ] **Step 6: Rewrite `app/main.cpp`**

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSettings>
#include <QTimer>
#include <QtQml/QQmlExtensionPlugin>

// The QML module is a static library (conestructor_core), so its plugin is pulled in by hand.
Q_IMPORT_QML_PLUGIN(ConestructorPlugin)

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("Conestructor"));
    QCoreApplication::setApplicationName(QStringLiteral("Conestructor"));
    QCoreApplication::setApplicationVersion(QStringLiteral(CONESTRUCTOR_VERSION));
    QQuickStyle::setStyle(QStringLiteral("Fusion"));

    // Screenshot runs (tests/grab.ps1) keep their own settings, so trying something never changes the owner's.
    const QString settingsDir = qEnvironmentVariable("CONESTRUCTOR_SETTINGS_DIR");
    if (!settingsDir.isEmpty())
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, settingsDir);

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("Conestructor", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;
    QObject *root = engine.rootObjects().first();

    // Dev affordance for layout checks: save the window to a PNG after a delay, then quit. Does nothing unless set.
    const QString grabPath = qEnvironmentVariable("CONESTRUCTOR_GRAB");
    if (!grabPath.isEmpty()) {
        const int delay = qEnvironmentVariableIntValue("CONESTRUCTOR_GRAB_DELAY");
        QTimer::singleShot(delay > 0 ? delay : 3000, &app, [root, grabPath]() {
            if (auto *window = qobject_cast<QQuickWindow *>(root))
                window->grabWindow().save(grabPath);
            QCoreApplication::quit();
        });
    }

    return app.exec();
}
```

- [ ] **Step 7: Write a placeholder `app/qml/Main.qml`**

```qml
import QtQuick
import QtQuick.Controls
import Conestructor

ApplicationWindow {
    id: window
    width: 1600
    height: 960
    visible: true
    title: "Conestructor " + AppInfo.shortVersion + " — Untitled"
    color: "#1f1f1f"

    Label {
        anchors.centerIn: parent
        text: qsTr("The new canvas arrives in the next tasks.")
        color: "#d0d0d0"
    }
}
```

- [ ] **Step 8: Write the test scaffolding**

`app/tests/CMakeLists.txt`:

```cmake
find_package(Qt6 REQUIRED COMPONENTS Test Qml Quick QuickControls2)

# One test executable: its sources, the libraries beyond Qt Test, and a ctest entry. Console programs, so their
# output reaches ctest; offscreen, so no window reaches the owner's screen.
function(conestructor_test name)
    cmake_parse_arguments(T "" "" "SOURCES;LIBS" ${ARGN})
    qt_add_executable(${name} ${T_SOURCES})
    target_link_libraries(${name} PRIVATE Qt6::Test ${T_LIBS})
    set_target_properties(${name} PROPERTIES WIN32_EXECUTABLE FALSE MACOSX_BUNDLE FALSE)
    add_test(NAME ${name} COMMAND ${name})
    set_tests_properties(${name} PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
endfunction()

conestructor_test(tst_qmlload
    SOURCES tst_qmlload.cpp
    LIBS conestructor_coreplugin Qt6::Qml Qt6::Quick Qt6::QuickControls2)
```

`app/tests/tst_qmlload.cpp`:

```cpp
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QSettings>
#include <QTemporaryDir>
#include <QTest>
#include <QtQml/QQmlExtensionPlugin>

Q_IMPORT_QML_PLUGIN(ConestructorPlugin)

// Loads the real window offscreen. Any warning from QML (a broken binding, a missing property) fails the run.
class TestQmlLoad : public QObject
{
    Q_OBJECT

    QTemporaryDir dir;

private slots:
    void initTestCase()
    {
        // Before anything reads settings, so the owner's real ini is never read or written.
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, dir.path());
        QQuickStyle::setStyle(QStringLiteral("Fusion"));
        QTest::failOnWarning(QRegularExpression(QStringLiteral("\\.qml|\\.mjs|QML")));
    }

    void mainOpensWithTheTitle()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        QCOMPARE(engine.rootObjects().size(), 1);
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(window);
        QCOMPARE(window->title(), QStringLiteral("Conestructor 0.2 \u2014 Untitled"));
    }
};

QTEST_MAIN(TestQmlLoad)
#include "tst_qmlload.moc"
```

`app/tests/build.ps1`:

```powershell
# Copied from Gluttony app/tests/build.ps1; CONESTRUCTOR_ names and option.
# Configures and builds the app and its tests (Debug, tests on) from a plain shell.
# Paths default to the owner's machine; override with CONESTRUCTOR_QT / CONESTRUCTOR_QT_TOOLS / CONESTRUCTOR_VCVARS.
$ErrorActionPreference = 'Stop'
$qt     = if ($env:CONESTRUCTOR_QT)       { $env:CONESTRUCTOR_QT }       else { 'D:\allNewQT6\6.11.1\msvc2022_64' }
$tools  = if ($env:CONESTRUCTOR_QT_TOOLS) { $env:CONESTRUCTOR_QT_TOOLS } else { 'D:\allNewQT6\Tools' }
$vcvars = if ($env:CONESTRUCTOR_VCVARS)   { $env:CONESTRUCTOR_VCVARS }   else { 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat' }
$src    = Split-Path $PSScriptRoot -Parent
$build  = Join-Path $src 'build\tests'

$env:PATH = "$tools\CMake_64\bin;$tools\Ninja;$qt\bin;$env:PATH"
cmd /c "`"$vcvars`" >nul && cmake -S `"$src`" -B `"$build`" -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=$qt -DCONESTRUCTOR_BUILD_TESTS=ON && cmake --build `"$build`""
exit $LASTEXITCODE
```

`app/tests/run.ps1`:

```powershell
# Copied from Gluttony app/tests/run.ps1; CONESTRUCTOR_ names, the bundled Ubuntu Mono for offscreen runs,
# and -NoCpp / -Qml to run one stage or one QML file.
# Runs the C++ tests (ctest) and then the QML logic tests (qmltestrunner), then prints one summary line per
# stage. Exits 0 only when both stages pass.
#   run.ps1                    everything
#   run.ps1 -R tst_settings    only C++ tests whose name matches
#   run.ps1 -NoCpp -Qml tst_units.qml   one QML test file
param([string]$R = '', [switch]$NoCpp, [switch]$NoQml, [string]$Qml = '')
# Not 'Stop': ctest and qmltestrunner write to stderr, and when the caller redirects it (2>&1) PowerShell would
# turn the first such line into an error that ends the script before the QML stage runs.
$ErrorActionPreference = 'Continue'
$qt    = if ($env:CONESTRUCTOR_QT)       { $env:CONESTRUCTOR_QT }       else { 'D:\allNewQT6\6.11.1\msvc2022_64' }
$tools = if ($env:CONESTRUCTOR_QT_TOOLS) { $env:CONESTRUCTOR_QT_TOOLS } else { 'D:\allNewQT6\Tools' }
$src   = Split-Path $PSScriptRoot -Parent
$build = Join-Path $src 'build\tests'

$env:PATH = "$tools\CMake_64\bin;$qt\bin;$env:PATH"
# No window is needed to check logic; offscreen keeps runs quiet and works headless.
$env:QT_QPA_PLATFORM = 'offscreen'
# The offscreen platform looks for fonts in the Qt install, which ships none, and warns in every GUI test.
$env:QT_QPA_FONTDIR = Join-Path $src 'assets\fonts\Ubuntu_Mono'

# ---- C++ tests ----
$ctestPassed = $true
if ($NoCpp) {
    $ctestSummary = 'ctest: skipped (-NoCpp)'
} else {
    $ctestArgs = @('--test-dir', $build, '--output-on-failure')
    if ($R) { $ctestArgs += @('-R', $R) }
    & ctest @ctestArgs 2>&1 | ForEach-Object { "$_" } | Tee-Object -Variable ctestLines
    $ctestExit = $LASTEXITCODE
    $failedTests = @($ctestLines | ForEach-Object { if ($_ -match '^\s*\d+\s+-\s+(\S+)\s+\(') { $Matches[1] } })
    if ($ctestExit -eq 0) {
        $ctestSummary = 'ctest: passed'
    } else {
        $ctestPassed = $false
        $names = if ($failedTests.Count -gt 0) { $failedTests -join ', ' } else { "exit code $ctestExit" }
        $ctestSummary = "ctest: FAILED ($names)"
    }
    Write-Output $ctestSummary
}

# ---- QML tests ----
$qmlPassed = $true
$qmlDir = Join-Path $PSScriptRoot 'qml'
$qmlInput = if ($Qml) { Join-Path $qmlDir $Qml } else { $qmlDir }
if ($NoQml) {
    $qmlSummary = 'qml: skipped (-NoQml)'
} elseif (-not $Qml -and -not (Get-ChildItem $qmlDir -Filter 'tst_*.qml' -ErrorAction SilentlyContinue)) {
    $qmlSummary = 'qml: no tests'
} else {
    New-Item -ItemType Directory -Force $build | Out-Null
    $results = Join-Path $build 'qml-results.txt'
    Remove-Item -LiteralPath $results -Force -ErrorAction SilentlyContinue
    & qmltestrunner -input $qmlInput -o "$results,txt" 2>&1 | ForEach-Object { "$_" }
    $qmlExit = $LASTEXITCODE
    if (Test-Path -LiteralPath $results) {
        $qmlLines = Get-Content -LiteralPath $results
        $qmlLines
        $passedCount = 0
        $failedCount = 0
        foreach ($line in $qmlLines) {
            if ($line -match '^Totals:\s+(\d+) passed,\s+(\d+) failed') {
                $passedCount += [int]$Matches[1]
                $failedCount += [int]$Matches[2]
            }
        }
        $qmlPassed = $qmlExit -eq 0 -and $failedCount -eq 0
        $qmlSummary = "qml: $passedCount passed, $failedCount failed"
        if ($qmlExit -ne 0 -and $failedCount -eq 0) { $qmlSummary += " (qmltestrunner exit code $qmlExit)" }
    } else {
        $qmlPassed = $false
        $qmlSummary = "qml: FAILED (no results file; qmltestrunner exit code $qmlExit)"
    }
    Write-Output $qmlSummary
}

Write-Output ''
Write-Output $ctestSummary
Write-Output $qmlSummary
if ($ctestPassed -and $qmlPassed) { exit 0 } else { exit 1 }
```

`app/tests/grab.ps1`:

```powershell
# Opens the built app, saves a screenshot after a delay, then quits. For checking layouts by eye.
#   grab.ps1                               the example track with cones placed, to build\tests\grab.png
#   grab.ps1 -Demo track -Out C:\tmp\a.png the example track without cones
#   grab.ps1 -Demo ''                      the empty window
# Settings go to build\tests\grab-settings, never the owner's.
param([string]$Demo = 'cones', [string]$Out = '', [int]$Delay = 3000)
$ErrorActionPreference = 'Stop'
$qt    = if ($env:CONESTRUCTOR_QT) { $env:CONESTRUCTOR_QT } else { 'D:\allNewQT6\6.11.1\msvc2022_64' }
$src   = Split-Path $PSScriptRoot -Parent
$build = Join-Path $src 'build\tests'
if (-not $Out) { $Out = Join-Path $build 'grab.png' }

$env:PATH = "$qt\bin;$env:PATH"
$env:CONESTRUCTOR_SETTINGS_DIR = Join-Path $build 'grab-settings'
$env:CONESTRUCTOR_DEMO = $Demo
$env:CONESTRUCTOR_GRAB = $Out
$env:CONESTRUCTOR_GRAB_DELAY = "$Delay"
# Piping a window program to Out-Null makes PowerShell wait for it to quit.
& (Join-Path $build 'appConestructor.exe') | Out-Null
Write-Output $Out
```

Create an empty `app/tests/qml/.gitkeep` so the folder exists before the first QML test.

- [ ] **Step 9: Build and run**

```powershell
powershell -NoProfile -File app\tests\build.ps1
powershell -NoProfile -File app\tests\run.ps1
```

Expected: build succeeds; `ctest: passed` (tst_qmlload, 1 test); `qml: no tests`.

- [ ] **Step 10: Look at the window**

```powershell
powershell -NoProfile -File app\tests\grab.ps1 -Demo ''
```

Open `app\build\tests\grab.png` with the Read tool: a dark window with the placeholder sentence.

- [ ] **Step 11: Check nothing sensitive is left in the tree, then commit**

```bash
git grep -n -I -E "192\.168\.|10\.[0-9]+\.[0-9]+\.[0-9]+|scp|snowie@" -- . ':!docs'
```

Expected: no output.

```bash
git add -A
git commit -m "Housekeeping: app/ folder, MIT licence, version 0.2.0, static QML module, test scripts; prototype UI and upload code removed" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `units.mjs` — show and read lengths in the chosen unit

**Files:**
- Create: `app/qml/logic/units.mjs`
- Test: `app/tests/qml/tst_units.qml`

**Interfaces:**
- Produces: `FOOT = 0.3048`, `INCH = 0.0254`, `UNITS = ["ftin", "ft", "m"]`, `LABELS {ftin: "Feet and inches", ft: "Decimal feet", m: "Metres"}`; `format(metres, unit) -> string`; `parse(text, unit) -> metres | NaN`; `formatAngle(deg)`, `parseAngle(text)`, `parseCount(text)`; `formatValue(kind, value, unit)`, `parseValue(kind, text, unit)`, `stepFor(kind, unit)` for kinds `"length" | "angle" | "count"`.

- [ ] **Step 1: Write the failing test** — `app/tests/qml/tst_units.qml`

```qml
import QtQuick
import QtTest
import "../../qml/logic/units.mjs" as Units

TestCase {
    name: "Units"

    function test_format_data() {
        return [
            { tag: "feet and inches", metres: 3.81, unit: "ftin", text: "12' 6\"" },
            { tag: "rounds to the inch", metres: 3.83, unit: "ftin", text: "12' 7\"" },
            { tag: "inches carry into feet", metres: 0.3, unit: "ftin", text: "1' 0\"" },
            { tag: "zero", metres: 0, unit: "ftin", text: "0' 0\"" },
            { tag: "negative feet and inches", metres: -1.2192, unit: "ftin", text: "-4' 0\"" },
            { tag: "tiny negative is zero", metres: -0.001, unit: "ftin", text: "0' 0\"" },
            { tag: "decimal feet", metres: 3.81, unit: "ft", text: "12.5 ft" },
            { tag: "whole decimal feet", metres: 6.096, unit: "ft", text: "20 ft" },
            { tag: "metres", metres: 3.81, unit: "m", text: "3.81 m" },
            { tag: "whole metres", metres: 20, unit: "m", text: "20 m" },
            { tag: "negative metres", metres: -4, unit: "m", text: "-4 m" },
            { tag: "negative zero metres", metres: -0.001, unit: "m", text: "0 m" }
        ]
    }

    function test_format(row) {
        compare(Units.format(row.metres, row.unit), row.text)
    }

    function test_parse_data() {
        return [
            { tag: "feet and inches", text: "12' 6\"", unit: "ftin", metres: 3.81 },
            { tag: "no space", text: "12'6\"", unit: "ftin", metres: 3.81 },
            { tag: "words", text: "12 ft 6 in", unit: "m", metres: 3.81 },
            { tag: "no inch mark", text: "12' 6", unit: "ftin", metres: 3.81 },
            { tag: "inches only", text: "6\"", unit: "ftin", metres: 0.1524 },
            { tag: "decimal feet", text: "12.5 ft", unit: "m", metres: 3.81 },
            { tag: "decimal feet with a prime", text: "12.5'", unit: "m", metres: 3.81 },
            { tag: "metres", text: "3.81 m", unit: "ftin", metres: 3.81 },
            { tag: "centimetres", text: "381 cm", unit: "ftin", metres: 3.81 },
            { tag: "bare number in ft-in is feet", text: "12.5", unit: "ftin", metres: 3.81 },
            { tag: "bare number in decimal feet", text: "12.5", unit: "ft", metres: 3.81 },
            { tag: "bare number in metres", text: "12.5", unit: "m", metres: 12.5 },
            { tag: "trailing point", text: "12.", unit: "m", metres: 12 },
            { tag: "negative feet and inches", text: "-4' 0\"", unit: "ftin", metres: -1.2192 },
            { tag: "typographic minus", text: "\u22124 m", unit: "ftin", metres: -4 },
            { tag: "spaces and capitals", text: "  20 M ", unit: "ftin", metres: 20 },
            { tag: "curly quotes", text: "12\u2019 6\u201d", unit: "m", metres: 3.81 }
        ]
    }

    function test_parse(row) {
        fuzzyCompare(Units.parse(row.text, row.unit), row.metres, 1e-9)
    }

    function test_parseRejects_data() {
        return [
            { tag: "empty", text: "" },
            { tag: "words", text: "abc" },
            { tag: "trailing junk", text: "12' 6\" 3" },
            { tag: "two points", text: "1..2" },
            { tag: "unit alone", text: "ft" },
            { tag: "two numbers", text: "12 6" }
        ]
    }

    function test_parseRejects(row) {
        verify(isNaN(Units.parse(row.text, "ftin")), row.text)
    }

    function test_roundTrip_data() {
        const rows = []
        const precision = { ftin: Units.INCH / 2, ft: Units.FOOT * 0.005, m: 0.005 }
        for (const unit of Units.UNITS)
            for (const metres of [0, 0.5, 3.81, 20, 123.4, -7.25])
                rows.push({ tag: unit + " " + metres, unit: unit, metres: metres, tolerance: precision[unit] })
        return rows
    }

    function test_roundTrip(row) {
        fuzzyCompare(Units.parse(Units.format(row.metres, row.unit), row.unit), row.metres, row.tolerance)
    }

    function test_anglesAndCounts() {
        compare(Units.formatAngle(90), "90°")
        compare(Units.formatAngle(22.25), "22.3°")
        compare(Units.parseAngle("90°"), 90)
        compare(Units.parseAngle("45 deg"), 45)
        compare(Units.parseAngle(" 12.5 "), 12.5)
        verify(isNaN(Units.parseAngle("left")))
        compare(Units.parseCount("4"), 4)
        verify(isNaN(Units.parseCount("4.5")))
        verify(isNaN(Units.parseCount("")))
    }

    function test_byKind() {
        compare(Units.formatValue("length", 3.81, "ftin"), "12' 6\"")
        compare(Units.formatValue("angle", 180, "ftin"), "180°")
        compare(Units.formatValue("count", 4, "m"), "4")
        fuzzyCompare(Units.parseValue("length", "3.81 m", "ftin"), 3.81, 1e-9)
        compare(Units.parseValue("angle", "90", "m"), 90)
        compare(Units.parseValue("count", "3", "m"), 3)
        compare(Units.stepFor("length", "ftin"), Units.INCH)
        fuzzyCompare(Units.stepFor("length", "ft"), Units.FOOT / 10, 1e-12)
        compare(Units.stepFor("length", "m"), 0.1)
        compare(Units.stepFor("angle", "m"), 5)
        compare(Units.stepFor("count", "m"), 1)
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_units.qml
```

Expected: FAIL (the import `units.mjs` cannot be found).

- [ ] **Step 3: Write `app/qml/logic/units.mjs`**

```js
// Lengths on screen: format metres as feet and inches, decimal feet or metres, and read back what people type.
// Pure functions, table-tested in tests/qml/tst_units.qml. Files always hold metres; this is display only.

export const FOOT = 0.3048
export const INCH = 0.0254
export const UNITS = ["ftin", "ft", "m"]
export const LABELS = { ftin: "Feet and inches", ft: "Decimal feet", m: "Metres" }

const NUMBER = "(-?(?:\\d+(?:\\.\\d*)?|\\.\\d+))"
const FEET_WORD = "(?:'|ft|feet|foot)"
const INCH_WORD = "(?:\"|in|inch|inches)"
const METRE_WORD = "(?:m|metre|metres|meter|meters)"
const FEET_AND_INCHES = new RegExp("^" + NUMBER + "\\s*" + FEET_WORD + "\\s*" + NUMBER + "\\s*" + INCH_WORD + "?$")
const FEET = new RegExp("^" + NUMBER + "\\s*" + FEET_WORD + "$")
const INCHES = new RegExp("^" + NUMBER + "\\s*" + INCH_WORD + "$")
const METRES = new RegExp("^" + NUMBER + "\\s*" + METRE_WORD + "$")
const CENTIMETRES = new RegExp("^" + NUMBER + "\\s*cm$")
const BARE = new RegExp("^" + NUMBER + "$")
const ANGLE = new RegExp("^" + NUMBER + "\\s*(?:°|deg|degrees)?$")

// Up to `places` decimals without trailing zeros (12.5, 12, 3.81), and never "-0".
function trimmed(value, places) {
    const n = Number(value.toFixed(places))
    return String(n === 0 ? 0 : n)
}

// Typographic minus signs, primes and curly quotes become their plain forms.
function clean(text) {
    return String(text).trim().toLowerCase()
        .replace(/[\u2212\u2013]/g, "-")
        .replace(/[\u2032\u2019]/g, "'")
        .replace(/[\u2033\u201d]/g, "\"")
}

export function format(metres, unit) {
    if (unit === "m")
        return trimmed(metres, 2) + " m"
    if (unit === "ft")
        return trimmed(metres / FOOT, 2) + " ft"
    const totalInches = Math.round(Math.abs(metres) / INCH)
    const sign = metres < 0 && totalInches > 0 ? "-" : ""
    return sign + Math.floor(totalInches / 12) + "' " + (totalInches % 12) + "\""
}

// Metres, or NaN when the text is not a length. A bare number is in the current unit (feet for ft-in).
export function parse(text, unit) {
    const s = clean(text)
    let m = s.match(FEET_AND_INCHES)
    if (m) {
        const sign = m[1].startsWith("-") ? -1 : 1
        return sign * (Math.abs(Number(m[1])) * FOOT + Math.abs(Number(m[2])) * INCH)
    }
    if ((m = s.match(FEET)))
        return Number(m[1]) * FOOT
    if ((m = s.match(INCHES)))
        return Number(m[1]) * INCH
    if ((m = s.match(METRES)))
        return Number(m[1])
    if ((m = s.match(CENTIMETRES)))
        return Number(m[1]) / 100
    if ((m = s.match(BARE)))
        return Number(m[1]) * (unit === "m" ? 1 : FOOT)
    return NaN
}

export function formatAngle(degrees) {
    return trimmed(degrees, 1) + "°"
}

export function parseAngle(text) {
    const m = clean(text).match(ANGLE)
    return m ? Number(m[1]) : NaN
}

export function parseCount(text) {
    const m = clean(text).match(/^-?\d+$/)
    return m ? Number(m[0]) : NaN
}

// The three kinds of typed setting: "length" (metres), "angle" (degrees) and "count" (a whole number).
export function formatValue(kind, value, unit) {
    if (kind === "length")
        return format(value, unit)
    if (kind === "angle")
        return formatAngle(value)
    if (kind === "count")
        return String(Math.round(value))
    return String(value)
}

export function parseValue(kind, text, unit) {
    if (kind === "length")
        return parse(text, unit)
    if (kind === "angle")
        return parseAngle(text)
    if (kind === "count")
        return parseCount(text)
    return NaN
}

// What one press of an up or down arrow adds: an inch, a tenth of a foot or a tenth of a metre; 5°; 1.
export function stepFor(kind, unit) {
    if (kind === "length")
        return unit === "ftin" ? INCH : unit === "ft" ? FOOT / 10 : 0.1
    if (kind === "angle")
        return 5
    return 1
}
```

- [ ] **Step 4: Run it and watch it pass**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_units.qml
```

Expected: `qml: N passed, 0 failed`. Then remove `app/tests/qml/.gitkeep`.

- [ ] **Step 5: Commit**

```bash
git add app/qml/logic/units.mjs app/tests/qml
git commit -m "Units: format and read lengths as feet and inches, decimal feet or metres" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `conerows.mjs` and `elements.mjs` — elements as data

**Files:**
- Create: `app/qml/logic/conerows.mjs`, `app/qml/logic/elements.mjs`
- Test: `app/tests/qml/tst_elements.qml`

**Interfaces:**
- Consumes: `FOOT` from `units.mjs`.
- Produces (`conerows.mjs`): `straightRow(originX, originY, angleRad, length, halfWidth, unitsPerFoot, minSpacingFt, maxSpacingFt) -> [{x, y, heading, type: "standing"}]`; `arcLengths(points)`; `atArcLength(points, arcLen, target)`; `sampleInterior(points, minSpacingFt, maxSpacingFt, unitsPerFoot) -> [{x, y, heading, arcFraction}]`.
- Produces (`elements.mjs`): `TYPES`, `NAMES`, `COLOURS`, `TIPS`, `PROPS[type] -> [def]` where `def = {key, label, kind: "length"|"angle"|"count"|"choice", min?, max?, choices?, labels?, showWhen?: {key, value}}`; `defaults(type)`; `propList(type, props)`; `clamp(def, value) -> {value, clamped}`; `clampProp(type, key, value)`; `geometry(type, props) -> {path: [{x,y}], ends: {A: {x,y,heading}, B: …}, cones: [{x,y,heading,type}]}` (local metres; cached, never mutate); `normalizeAngle(deg)` (prototype's, range [-180, 180]); `toWorld(el, p)`; `endsWorld(el)`; `pathWorld(el)`; `conesWorld(el)`; `pointSegmentDistance(p, a, b)`; `distanceToPath(el, p)`; `hitTest(elements, p, tolerance) -> id | ""`; `rotateHandle(el, extraMetres) -> {x, y}`.
- Element object (used by every later task): `{ id: "e1", type, x, y, rotation, props: {...}, joins: { A: null | {id, end}, B: … } }`, `x, y` in canvas metres (x right, y down), `rotation` in degrees clockwise on screen.
- Settings keys: straight `length, trackWidth`; slalom `leadIn, leadOut, coneCount, coneSpacing, weaveOffset, firstTurn ("left"|"right"), trackWidth`; chicane `leadIn, leadOut, shiftLength, shift, direction ("left"|"right"), trackWidth`; turn `leadIn, leadOut, angle, radius, radiusType ("constant"|"changing"), exitRadius, direction, trackWidth`.

- [ ] **Step 1: Write the failing test** — `app/tests/qml/tst_elements.qml`

```qml
import QtQuick
import QtTest
import "../../qml/logic/elements.mjs" as Elements

TestCase {
    name: "Elements"

    function el(id, type, props, x, y, rotation) {
        return { id: id, type: type, x: x || 0, y: y || 0, rotation: rotation || 0,
                 props: Object.assign(Elements.defaults(type), props || {}), joins: { A: null, B: null } }
    }

    function near(actual, expected, tolerance, what) {
        verify(Math.abs(actual - expected) <= tolerance, what + ": " + actual + " should be " + expected)
    }

    function test_defaultsMatchTheSpec() {
        compare(JSON.stringify(Elements.defaults("straight")), JSON.stringify({ length: 20, trackWidth: 4 }))
        compare(JSON.stringify(Elements.defaults("slalom")), JSON.stringify(
            { leadIn: 6, leadOut: 6, coneCount: 4, coneSpacing: 10, weaveOffset: 1.5, firstTurn: "left", trackWidth: 4 }))
        compare(JSON.stringify(Elements.defaults("chicane")), JSON.stringify(
            { leadIn: 6, leadOut: 6, shiftLength: 12, shift: 6, direction: "left", trackWidth: 4 }))
        compare(JSON.stringify(Elements.defaults("turn")), JSON.stringify(
            { leadIn: 6, leadOut: 6, angle: 180, radius: 6, radiusType: "constant", exitRadius: 10, direction: "right", trackWidth: 4 }))
        compare(Elements.TIPS.turn, "Turn: anything from a sweeper to a hairpin.")
    }

    function test_defaultsAreFreshCopies() {
        const a = Elements.defaults("straight")
        a.length = 99
        compare(Elements.defaults("straight").length, 20)
    }

    function test_aTwentyMetreStraightEndsTenMetresEitherSide() {
        const g = Elements.geometry("straight", Elements.defaults("straight"))
        compare(JSON.stringify(g.ends), JSON.stringify({ A: { x: -10, y: 0, heading: 180 }, B: { x: 10, y: 0, heading: 0 } }))
    }

    function test_aHairpinExitsTwelveMetresToTheSideHeadingBack() {
        const g = Elements.geometry("turn", Elements.defaults("turn"))
        near(g.ends.B.x - g.ends.A.x, 0, 0.05, "level with the entry")
        near(g.ends.B.y - g.ends.A.y, 12, 0.05, "12 m to the right, down the screen")
        compare(g.ends.A.heading, 180)
        compare(g.ends.B.heading, 180)
    }

    function test_aLeftQuarterTurn() {
        const g = Elements.geometry("turn", Object.assign(Elements.defaults("turn"),
                                    { angle: 90, radius: 10, leadIn: 0, leadOut: 0, direction: "left" }))
        near(g.ends.B.x - g.ends.A.x, 10, 0.05, "forward")
        near(g.ends.B.y - g.ends.A.y, -10, 0.05, "left, up the screen")
        compare(g.ends.B.heading, -90)
    }

    function test_slalomAndChicaneEnds() {
        const s = Elements.geometry("slalom", Elements.defaults("slalom"))
        compare(JSON.stringify(s.ends), JSON.stringify({ A: { x: -31, y: 0, heading: 180 }, B: { x: 31, y: 0, heading: 0 } }))
        const c = Elements.geometry("chicane", Elements.defaults("chicane"))
        compare(JSON.stringify(c.ends), JSON.stringify({ A: { x: -12, y: 3, heading: 180 }, B: { x: 12, y: -3, heading: 0 } }))
        const r = Elements.geometry("chicane", Object.assign(Elements.defaults("chicane"), { direction: "right" }))
        compare(r.ends.A.y, -3)
        compare(r.ends.B.y, 3)
    }

    function test_pathsStartAndEndOnTheirEnds_data() {
        return [
            { tag: "straight", type: "straight", props: {} },
            { tag: "slalom", type: "slalom", props: {} },
            { tag: "slalom, one cone, no leads", type: "slalom", props: { coneCount: 1, leadIn: 0, leadOut: 0 } },
            { tag: "slalom, no weave, right first", type: "slalom", props: { weaveOffset: 0, firstTurn: "right" } },
            { tag: "chicane", type: "chicane", props: {} },
            { tag: "chicane, no shift, right", type: "chicane", props: { shift: 0, direction: "right" } },
            { tag: "chicane, no leads", type: "chicane", props: { leadIn: 0, leadOut: 0 } },
            { tag: "turn", type: "turn", props: {} },
            { tag: "turn of 0 degrees", type: "turn", props: { angle: 0 } },
            { tag: "turn, changing radius, left", type: "turn",
              props: { radiusType: "changing", exitRadius: 15, direction: "left", angle: 120 } },
            { tag: "turn, no leads", type: "turn", props: { leadIn: 0, leadOut: 0 } }
        ]
    }

    function test_pathsStartAndEndOnTheirEnds(row) {
        const g = Elements.geometry(row.type, Object.assign(Elements.defaults(row.type), row.props))
        const first = g.path[0]
        const last = g.path[g.path.length - 1]
        near(first.x, g.ends.A.x, 1e-9, "start x")
        near(first.y, g.ends.A.y, 1e-9, "start y")
        near(last.x, g.ends.B.x, 1e-9, "end x")
        near(last.y, g.ends.B.y, 1e-9, "end y")
        for (const p of g.path)
            verify(isFinite(p.x) && isFinite(p.y), "finite path point")
        verify(g.cones.length > 0, "has cones")
        for (const c of g.cones)
            verify(isFinite(c.x) && isFinite(c.y) && isFinite(c.heading), "finite cone")
    }

    function test_aTwentyMetreStraightHasThreePairs() {
        const cones = Elements.geometry("straight", Elements.defaults("straight")).cones
        const rounded = cones.map(c => [Math.round(c.x * 1000) / 1000, Math.round(c.y * 1000) / 1000, c.type])
        compare(JSON.stringify(rounded), JSON.stringify([[-10, 2, "standing"], [-10, -2, "standing"], [0, 2, "standing"],
                                                         [0, -2, "standing"], [10, 2, "standing"], [10, -2, "standing"]]))
    }

    function test_aSlalomHasSixteenCones() {
        const cones = Elements.geometry("slalom", Elements.defaults("slalom")).cones
        compare(cones.length, 16)
        compare(cones.filter(c => c.type === "leaning").length, 4)
    }

    function test_endsInTheWorld() {
        const e = Elements.endsWorld(el("a", "straight", {}, 5, 5, 90))
        near(e.A.x, 5, 1e-9, "A x")
        near(e.A.y, -5, 1e-9, "A y")
        compare(e.A.heading, 270)
        near(e.B.x, 5, 1e-9, "B x")
        near(e.B.y, 15, 1e-9, "B y")
        compare(e.B.heading, 90)
    }

    function test_conesInTheWorldTurnWithTheElement() {
        const cones = Elements.conesWorld(el("a", "straight", {}, 100, 50, 90))
        near(cones[0].x, 98, 1e-9, "first cone x")
        near(cones[0].y, 40, 1e-9, "first cone y")
        compare(cones[0].heading, 90)
    }

    function test_clamp_data() {
        return [
            { tag: "too wide", type: "straight", key: "trackWidth", value: 25, expected: 20, clamped: true },
            { tag: "too narrow", type: "straight", key: "trackWidth", value: 0.5, expected: 1, clamped: true },
            { tag: "fine", type: "straight", key: "trackWidth", value: 4, expected: 4, clamped: false },
            { tag: "counts are whole", type: "slalom", key: "coneCount", value: 4.6, expected: 5, clamped: false },
            { tag: "unknown choice", type: "slalom", key: "firstTurn", value: "up", expected: "left", clamped: true },
            { tag: "angle over 180", type: "turn", key: "angle", value: 270, expected: 180, clamped: true },
            { tag: "not a number", type: "turn", key: "radius", value: NaN, expected: 1, clamped: true }
        ]
    }

    function test_clamp(row) {
        const c = Elements.clampProp(row.type, row.key, row.value)
        compare(c.value, row.expected)
        compare(c.clamped, row.clamped)
    }

    function test_exitRadiusShowsOnlyWhenTheRadiusChanges() {
        const keys = props => Elements.propList("turn", props).map(p => p.key)
        verify(keys(Elements.defaults("turn")).indexOf("exitRadius") < 0)
        verify(keys(Object.assign(Elements.defaults("turn"), { radiusType: "changing" })).indexOf("exitRadius") >= 0)
    }

    function test_hitTestFindsTheTopmostElement() {
        const a = el("a", "straight", {}, 0, 0, 0)
        const b = el("b", "straight", {}, 0, 0, 90)
        compare(Elements.hitTest([a, b], { x: 0, y: 0 }, 0.1), "b")
        compare(Elements.hitTest([a, b], { x: 8, y: 1.9 }, 0.1), "a")
        compare(Elements.hitTest([a, b], { x: 8, y: 2.5 }, 0.1), "")
    }

    function test_theRotateHandleSitsAboveTheBand() {
        const h = Elements.rotateHandle(el("a", "straight", {}, 0, 0, 0), 1)
        near(h.x, 0, 1e-9, "x")
        near(h.y, -3, 1e-9, "y")
        const turned = Elements.rotateHandle(el("a", "straight", {}, 0, 0, 90), 1)
        near(turned.x, 3, 1e-9, "turned x")
        near(turned.y, 0, 1e-9, "turned y")
    }

    function test_normalizeAngle() {
        compare(Elements.normalizeAngle(190), -170)
        compare(Elements.normalizeAngle(-190), 170)
        compare(Elements.normalizeAngle(180), 180)
        compare(Elements.normalizeAngle(-180), -180)
        compare(Elements.normalizeAngle(720), 0)
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_elements.qml
```

Expected: FAIL (`elements.mjs` missing).

- [ ] **Step 3: Write `app/qml/logic/conerows.mjs`**

```js
// Cone rows along a centreline, ported from the prototype's qml/elements/ConeUtils.js at 2c79b60. Lengths are in
// any unit; `unitsPerFoot` says how many of that unit make a foot (0.3048 for metres), because the prototype's
// spacing rules are written in feet. Part 3 replaces these spacing rules with density notches.

// Standing cone pairs along a straight run, both ends included. A run of length 0 still gets one pair.
export function straightRow(originX, originY, angleRad, length, halfWidth, unitsPerFoot, minSpacingFt, maxSpacingFt) {
    const maxSpacing = maxSpacingFt * unitsPerFoot
    const n = length > 0 ? Math.max(1, Math.ceil(length / maxSpacing)) : 0
    const spacing = n > 0 ? length / n : 0
    const dirX = Math.cos(angleRad)
    const dirY = Math.sin(angleRad)
    const nx = -Math.sin(angleRad)
    const ny = Math.cos(angleRad)
    const cones = []
    for (let i = 0; i <= n; i++) {
        const d = spacing * i
        const px = originX + dirX * d
        const py = originY + dirY * d
        cones.push({ x: px + nx * halfWidth, y: py + ny * halfWidth, heading: 0, type: "standing" })
        cones.push({ x: px - nx * halfWidth, y: py - ny * halfWidth, heading: 0, type: "standing" })
    }
    return cones
}

export function arcLengths(points) {
    const arcLen = [0]
    for (let i = 1; i < points.length; i++) {
        const dx = points[i].x - points[i - 1].x
        const dy = points[i].y - points[i - 1].y
        arcLen.push(arcLen[i - 1] + Math.sqrt(dx * dx + dy * dy))
    }
    return arcLen
}

export function atArcLength(points, arcLen, target) {
    for (let i = 1; i < arcLen.length; i++) {
        if (arcLen[i] >= target) {
            const segStart = arcLen[i - 1]
            const segEnd = arcLen[i]
            const t = segEnd > segStart ? (target - segStart) / (segEnd - segStart) : 0
            const p0 = points[i - 1]
            const p1 = points[i]
            return { x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t,
                     heading: p0.heading + (p1.heading - p0.heading) * t }
        }
    }
    return Object.assign({}, points[points.length - 1])
}

// Interior points only (both ends excluded), evenly spaced by arc length, as few as keep the spacing at or under
// maxSpacingFt. Each carries arcFraction (0 to 1), which an S-curve uses to flip sides halfway.
export function sampleInterior(points, minSpacingFt, maxSpacingFt, unitsPerFoot) {
    const arcLen = arcLengths(points)
    const total = arcLen[arcLen.length - 1]
    const maxSpacing = maxSpacingFt * unitsPerFoot
    const n = Math.max(1, Math.ceil(total / maxSpacing))
    const result = []
    for (let i = 1; i < n; i++) {
        const target = total * i / n
        const pt = atArcLength(points, arcLen, target)
        pt.arcFraction = total > 0 ? target / total : 0
        result.push(pt)
    }
    return result
}
```

- [ ] **Step 4: Write `app/qml/logic/elements.mjs`**

```js
// Track elements as data. Per type: the settings (defaults and physical limits), the centreline, the two ends and
// the cones, all in metres in the element's own frame: origin in the middle of its centreline's bounding box, x
// along its entry, y down the screen, headings in degrees clockwise on screen (Qt's convention). Ported from the
// prototype's qml/elements/*.qml at 2c79b60 with pixels replaced by metres; the frame is the prototype's, so the
// cone code is unchanged. Element objects: { id, type, x, y, rotation, props, joins: { A, B } } (see commands.mjs).
import * as Rows from "./conerows.mjs"
import { FOOT } from "./units.mjs"

export const TYPES = ["straight", "slalom", "chicane", "turn"]
export const NAMES = { straight: "Straight", slalom: "Slalom", chicane: "Chicane", turn: "Turn" }
export const COLOURS = { straight: "#b603fc", slalom: "#c9691a", chicane: "#1a46c9", turn: "#34eb7a" }
export const TIPS = {
    straight: "Straight: a run between two rows of cones.",
    slalom: "Slalom: a line of cones to weave through.",
    chicane: "Chicane: a sideways step in the track.",
    turn: "Turn: anything from a sweeper to a hairpin."
}

const WIDTH = { key: "trackWidth", label: "Track width", kind: "length", min: 1, max: 20 }
const LEAD_IN = { key: "leadIn", label: "Lead-in", kind: "length", min: 0, max: 100 }
const LEAD_OUT = { key: "leadOut", label: "Lead-out", kind: "length", min: 0, max: 100 }
const SIDES = { kind: "choice", choices: ["left", "right"], labels: ["Left", "Right"] }

// Physical limits only; the rulebook's limits are part 3's warnings and never block.
export const PROPS = {
    straight: [
        { key: "length", label: "Length", kind: "length", min: 1, max: 200 },
        WIDTH
    ],
    slalom: [
        LEAD_IN, LEAD_OUT,
        { key: "coneCount", label: "Cones", kind: "count", min: 1, max: 20 },
        { key: "coneSpacing", label: "Cone spacing", kind: "length", min: 2, max: 40 },
        { key: "weaveOffset", label: "Weave offset", kind: "length", min: 0, max: 10 },
        Object.assign({ key: "firstTurn", label: "First turn" }, SIDES),
        WIDTH
    ],
    chicane: [
        LEAD_IN, LEAD_OUT,
        { key: "shiftLength", label: "Shift length", kind: "length", min: 1, max: 100 },
        { key: "shift", label: "Sideways shift", kind: "length", min: 0, max: 40 },
        Object.assign({ key: "direction", label: "Direction" }, SIDES),
        WIDTH
    ],
    turn: [
        LEAD_IN, LEAD_OUT,
        { key: "angle", label: "Turn angle", kind: "angle", min: 0, max: 180 },
        { key: "radius", label: "Radius", kind: "length", min: 1, max: 100 },
        { key: "radiusType", label: "Radius type", kind: "choice", choices: ["constant", "changing"],
          labels: ["Constant", "Changing"] },
        { key: "exitRadius", label: "Exit radius", kind: "length", min: 1, max: 100,
          showWhen: { key: "radiusType", value: "changing" } },
        Object.assign({ key: "direction", label: "Direction" }, SIDES),
        WIDTH
    ]
}

const DEFAULTS = {
    straight: { length: 20, trackWidth: 4 },
    slalom: { leadIn: 6, leadOut: 6, coneCount: 4, coneSpacing: 10, weaveOffset: 1.5, firstTurn: "left", trackWidth: 4 },
    chicane: { leadIn: 6, leadOut: 6, shiftLength: 12, shift: 6, direction: "left", trackWidth: 4 },
    turn: { leadIn: 6, leadOut: 6, angle: 180, radius: 6, radiusType: "constant", exitRadius: 10, direction: "right",
            trackWidth: 4 }
}

export function defaults(type) {
    return Object.assign({}, DEFAULTS[type])
}

// The settings shown for these values (Exit radius only when the radius changes).
export function propList(type, props) {
    return PROPS[type].filter(p => !p.showWhen || props[p.showWhen.key] === p.showWhen.value)
}

// A value kept within a setting's limits: { value, clamped }. Counts are whole numbers.
export function clamp(def, value) {
    if (def.kind === "choice")
        return def.choices.indexOf(value) >= 0 ? { value: value, clamped: false } : { value: def.choices[0], clamped: true }
    let v = Number(value)
    if (!isFinite(v))
        return { value: def.min, clamped: true }
    if (def.kind === "count")
        v = Math.round(v)
    if (v < def.min)
        return { value: def.min, clamped: true }
    if (v > def.max)
        return { value: def.max, clamped: true }
    return { value: v, clamped: false }
}

export function clampProp(type, key, value) {
    const def = PROPS[type].find(p => p.key === key)
    if (!def)
        throw new Error("No setting " + key + " on " + type)
    return clamp(def, value)
}

// The prototype's Element.normalizeAngle: into [-180, 180].
export function normalizeAngle(angle) {
    while (angle > 180) angle -= 360
    while (angle < -180) angle += 360
    return angle
}

// ---- Geometry per type, in the element's own frame ----

const LEAD_MIN_FT = 8 * 3.28084       // the prototype's lead spacing (8 m to 10 m), written in feet
const LEAD_MAX_FT = 10 * 3.28084
const LEAN_OFFSET_FT = (10.5 / 2 + 18 / 2) / 12   // half a standing cone's base plus half a leaning cone
const SLALOM_SAMPLES = 16
const CURVE_SAMPLES = 60
const TURN_SAMPLES_PER_DEGREE = 3

function straight(p) {
    const half = p.length / 2
    return {
        path: [{ x: -half, y: 0 }, { x: half, y: 0 }],
        ends: { A: { x: -half, y: 0, heading: 180 }, B: { x: half, y: 0, heading: 0 } },
        cones: Rows.straightRow(-half, 0, 0, p.length, p.trackWidth / 2, FOOT, LEAD_MIN_FT, LEAD_MAX_FT)
    }
}

function slalom(p) {
    const total = p.leadIn + (p.coneCount + 1) * p.coneSpacing + p.leadOut
    const half = total / 2
    const weaveEnd = -half + p.leadIn + (p.coneCount + 1) * p.coneSpacing

    // The centreline swings out past each cone (weave offset plus half the track width), eased in and out.
    const keypoints = [{ x: -half, y: 0 }, { x: -half + p.leadIn, y: 0 }]
    let sign = p.firstTurn === "left" ? -1 : 1
    for (let i = 0; i < p.coneCount; i++) {
        keypoints.push({ x: -half + p.leadIn + (i + 1) * p.coneSpacing, y: sign * (p.weaveOffset + p.trackWidth / 2) })
        sign = -sign
    }
    keypoints.push({ x: weaveEnd, y: 0 }, { x: half, y: 0 })
    const path = []
    for (let k = 1; k < keypoints.length; k++) {
        const a = keypoints[k - 1]
        const b = keypoints[k]
        for (let s = k === 1 ? 0 : 1; s <= SLALOM_SAMPLES; s++) {
            const t = s / SLALOM_SAMPLES
            const ease = (1 - Math.cos(Math.PI * t)) / 2
            path.push({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * ease })
        }
    }

    // Cones: lead-in pairs, a standing cone at each apex with a leaning cone just outside it, lead-out pairs.
    const halfWidth = p.trackWidth / 2
    const lean = LEAN_OFFSET_FT * FOOT
    let cones = Rows.straightRow(-half, 0, 0, p.leadIn, halfWidth, FOOT, LEAD_MIN_FT, LEAD_MAX_FT)
    sign = p.firstTurn === "left" ? -1 : 1
    for (let i = 0; i < p.coneCount; i++) {
        const apexX = p.leadIn + (i + 1) * p.coneSpacing - half
        const apexY = sign * p.weaveOffset
        cones.push({ x: apexX, y: apexY, heading: 0, type: "standing" })
        cones.push({ x: apexX, y: apexY + sign * lean, heading: Math.atan2(-sign, 0) * 180 / Math.PI, type: "leaning" })
        sign = -sign
    }
    cones = cones.concat(Rows.straightRow(weaveEnd, 0, 0, p.leadOut, halfWidth, FOOT, LEAD_MIN_FT, LEAD_MAX_FT))

    return { path: path, ends: { A: { x: -half, y: 0, heading: 180 }, B: { x: half, y: 0, heading: 0 } }, cones: cones }
}

function chicane(p) {
    const total = p.leadIn + p.shiftLength + p.leadOut
    const half = total / 2
    const bendRight = p.direction !== "left"
    const entryY = bendRight ? -p.shift / 2 : p.shift / 2
    const exitY = -entryY
    const p0 = { x: -half + p.leadIn, y: entryY }
    const c1 = { x: -half + p.leadIn + p.shiftLength / 2, y: entryY }
    const c2 = { x: -half + p.leadIn + p.shiftLength / 2, y: exitY }
    const p3 = { x: -half + p.leadIn + p.shiftLength, y: exitY }

    function point(t) {
        const mt = 1 - t
        return {
            x: mt * mt * mt * p0.x + 3 * mt * mt * t * c1.x + 3 * mt * t * t * c2.x + t * t * t * p3.x,
            y: mt * mt * mt * p0.y + 3 * mt * mt * t * c1.y + 3 * mt * t * t * c2.y + t * t * t * p3.y
        }
    }
    function tangentDeg(t) {
        const mt = 1 - t
        const dx = 3 * mt * mt * (c1.x - p0.x) + 6 * mt * t * (c2.x - c1.x) + 3 * t * t * (p3.x - c2.x)
        const dy = 3 * mt * mt * (c1.y - p0.y) + 6 * mt * t * (c2.y - c1.y) + 3 * t * t * (p3.y - c2.y)
        return Math.atan2(dy, dx) * 180 / Math.PI
    }

    const curve = []
    for (let i = 0; i <= CURVE_SAMPLES; i++) {
        const t = i / CURVE_SAMPLES
        const q = point(t)
        curve.push({ x: q.x, y: q.y, heading: tangentDeg(t) })
    }
    const path = [{ x: -half, y: entryY }].concat(curve.map(q => ({ x: q.x, y: q.y })), [{ x: half, y: exitY }])

    // Cones: entry pairs, leaning cones on the outside of each half of the S, exit pairs.
    const halfWidth = p.trackWidth / 2
    let cones = Rows.straightRow(-half, entryY, 0, p.leadIn, halfWidth, FOOT, LEAD_MIN_FT, LEAD_MAX_FT)
    const bendSign = bendRight ? -1 : 1
    for (const q of Rows.sampleInterior(curve, 3, 6, FOOT)) {
        const side = q.arcFraction < 0.5 ? bendSign : -bendSign
        const outside = q.heading * Math.PI / 180 + (90 * side) * Math.PI / 180
        cones.push({ x: q.x + Math.cos(outside) * halfWidth, y: q.y + Math.sin(outside) * halfWidth,
                     heading: q.heading, type: "leaning" })
    }
    cones = cones.concat(Rows.straightRow(p3.x, exitY, 0, p.leadOut, halfWidth, FOOT, LEAD_MIN_FT, LEAD_MAX_FT))

    return { path: path, ends: { A: { x: -half, y: entryY, heading: 180 }, B: { x: half, y: exitY, heading: 0 } },
             cones: cones }
}

function radiusAt(p, thetaDeg) {
    if (p.radiusType === "constant" || p.angle === 0)
        return p.radius
    return p.radius + (p.exitRadius - p.radius) * (thetaDeg / p.angle)
}

function turn(p) {
    const turnSign = p.direction === "right" ? 1 : -1
    const steps = Math.max(6, Math.round(Math.abs(p.angle) * TURN_SAMPLES_PER_DEGREE))
    const dTheta = p.angle / steps

    // The arc from the end of the lead-in, in the entry frame (start at 0, 0 heading +x), stepped as the prototype did.
    const arc = [{ x: p.leadIn, y: 0, heading: 0 }]
    let x = p.leadIn
    let y = 0
    let heading = 0
    for (let i = 0; i < steps; i++) {
        const ds = radiusAt(p, (i + 0.5) * dTheta) * (dTheta * Math.PI / 180)
        const h = heading * Math.PI / 180
        x += ds * Math.cos(h)
        y += ds * Math.sin(h)
        heading += turnSign * dTheta
        arc.push({ x: x, y: y, heading: heading })
    }
    const exitRad = heading * Math.PI / 180
    const raw = [{ x: 0, y: 0 }].concat(arc.map(q => ({ x: q.x, y: q.y })),
                                        [{ x: x + p.leadOut * Math.cos(exitRad), y: y + p.leadOut * Math.sin(exitRad) }])

    // Centre on the bounding box of the centreline (the prototype's padded box has the same centre).
    let minX = raw[0].x, maxX = raw[0].x, minY = raw[0].y, maxY = raw[0].y
    for (const q of raw) {
        minX = Math.min(minX, q.x); maxX = Math.max(maxX, q.x)
        minY = Math.min(minY, q.y); maxY = Math.max(maxY, q.y)
    }
    const cx = (minX + maxX) / 2
    const cy = (minY + maxY) / 2
    const path = raw.map(q => ({ x: q.x - cx, y: q.y - cy }))
    const rel = arc.map(q => ({ x: q.x - cx, y: q.y - cy, heading: q.heading }))

    // Cones: entry pairs, leaning cones on the inside of the arc, exit pairs.
    const halfWidth = p.trackWidth / 2
    let cones = Rows.straightRow(path[0].x, path[0].y, 0, p.leadIn, halfWidth, FOOT, LEAD_MIN_FT, LEAD_MAX_FT)
    for (const q of Rows.sampleInterior(rel, 5, 8, FOOT)) {
        const inside = q.heading * Math.PI / 180 - (-90 * turnSign) * Math.PI / 180
        cones.push({ x: q.x + Math.cos(inside) * halfWidth, y: q.y + Math.sin(inside) * halfWidth,
                     heading: q.heading, type: "leaning" })
    }
    const last = rel[rel.length - 1]
    cones = cones.concat(Rows.straightRow(last.x, last.y, exitRad, p.leadOut, halfWidth, FOOT, LEAD_MIN_FT, LEAD_MAX_FT))

    return {
        path: path,
        ends: { A: { x: path[0].x, y: path[0].y, heading: 180 },
                B: { x: path[path.length - 1].x, y: path[path.length - 1].y, heading: normalizeAngle(turnSign * p.angle) } },
        cones: cones
    }
}

const BUILD = { straight: straight, slalom: slalom, chicane: chicane, turn: turn }
const cache = new Map()

// The element's centreline, ends and cones in its own frame. Cached by settings; callers must not change the result.
export function geometry(type, props) {
    const key = type + JSON.stringify(props)
    let g = cache.get(key)
    if (!g) {
        g = BUILD[type](props)
        if (cache.size > 500)
            cache.clear()
        cache.set(key, g)
    }
    return g
}

// ---- In the world (canvas metres) ----

export function toWorld(el, p) {
    const r = el.rotation * Math.PI / 180
    const c = Math.cos(r)
    const s = Math.sin(r)
    return { x: el.x + (p.x * c - p.y * s), y: el.y + (p.x * s + p.y * c) }
}

export function endsWorld(el) {
    const ends = geometry(el.type, el.props).ends
    const out = {}
    for (const end of ["A", "B"]) {
        const w = toWorld(el, ends[end])
        out[end] = { x: w.x, y: w.y, heading: el.rotation + ends[end].heading }
    }
    return out
}

export function pathWorld(el) {
    return geometry(el.type, el.props).path.map(p => toWorld(el, p))
}

export function conesWorld(el) {
    return geometry(el.type, el.props).cones.map(c => {
        const w = toWorld(el, c)
        return { x: w.x, y: w.y, heading: el.rotation + c.heading, type: c.type }
    })
}

export function pointSegmentDistance(p, a, b) {
    const dx = b.x - a.x
    const dy = b.y - a.y
    const lengthSquared = dx * dx + dy * dy
    const t = lengthSquared > 0 ? Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared)) : 0
    return Math.hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
}

export function distanceToPath(el, p) {
    const path = pathWorld(el)
    let best = Infinity
    for (let i = 1; i < path.length; i++)
        best = Math.min(best, pointSegmentDistance(p, path[i - 1], path[i]))
    return best
}

// The id of the topmost element (last drawn) whose band covers p, within `tolerance` metres; "" when none.
export function hitTest(elements, p, tolerance) {
    for (let i = elements.length - 1; i >= 0; i--) {
        const el = elements[i]
        if (distanceToPath(el, p) <= el.props.trackWidth / 2 + tolerance)
            return el.id
    }
    return ""
}

// Where the rotate handle sits: above the band (up the element's own y), `extraMetres` clear of it.
export function rotateHandle(el, extraMetres) {
    const g = geometry(el.type, el.props)
    let reach = 0
    for (const p of g.path)
        reach = Math.max(reach, Math.abs(p.y))
    return toWorld(el, { x: 0, y: -(reach + el.props.trackWidth / 2 + extraMetres) })
}
```

- [ ] **Step 5: Run it and watch it pass**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_elements.qml
```

Expected: all pass. If `test_aHairpinExitsTwelveMetresToTheSideHeadingBack` is off by more than 0.05 m, re-check the arc step against `git show 2c79b60:Conestructor/qml/elements/Hairpin.qml` (it must step with the heading at the start of each step, as the prototype does); do not change the tolerance.

- [ ] **Step 6: Commit**

```bash
git add app/qml/logic/conerows.mjs app/qml/logic/elements.mjs app/tests/qml/tst_elements.qml
git commit -m "Elements as data: settings with defaults and limits, centrelines, ends and cones in metres (ported from the prototype)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `snapping.mjs` — joining ends and keeping chains glued

**Files:**
- Create: `app/qml/logic/snapping.mjs`
- Test: `app/tests/qml/tst_snapping.qml`

**Interfaces:**
- Consumes: `Elements.geometry`, `Elements.endsWorld`, `Elements.normalizeAngle`.
- Produces: `otherEnd(end)`; `findSnap(elements, moving, maxDistance) -> {targetId, targetEnd, ownEnd, distance} | null`; `placeToJoin(moving, ownEnd, target, targetEnd) -> {x, y, rotation}`; `join(elements, aId, aEnd, bId, bEnd)`; `unjoin(elements, id, end)`; `unjoinAll(elements, id)`; `settle(elements, id)`; `glueAll(elements)`. Everything except `findSnap`/`placeToJoin`/`otherEnd` changes the element objects in the array it is given (callers pass a copy).

- [ ] **Step 1: Write the failing test** — `app/tests/qml/tst_snapping.qml`

```qml
import QtQuick
import QtTest
import "../../qml/logic/elements.mjs" as Elements
import "../../qml/logic/snapping.mjs" as Snapping

TestCase {
    name: "Snapping"

    function el(id, type, props, x, y, rotation) {
        return { id: id, type: type, x: x || 0, y: y || 0, rotation: rotation || 0,
                 props: Object.assign(Elements.defaults(type), props || {}), joins: { A: null, B: null } }
    }

    // Ends meet, facing opposite ways.
    function joinedWell(a, aEnd, b, bEnd) {
        const pa = Elements.endsWorld(a)[aEnd]
        const pb = Elements.endsWorld(b)[bEnd]
        const turn = (((pa.heading - pb.heading) % 360) + 360) % 360
        return Math.hypot(pa.x - pb.x, pa.y - pb.y) < 1e-9 && Math.abs(turn - 180) < 1e-9
    }

    // Elements joined B to A in order, each placed against the one before.
    function chain(specs) {
        const list = []
        for (const s of specs) {
            const e = el(s[0], s[1], s[2], 0, 0, 0)
            if (list.length > 0) {
                const prev = list[list.length - 1]
                Object.assign(e, Snapping.placeToJoin(e, "A", prev, "B"))
                list.push(e)
                Snapping.join(list, prev.id, "B", e.id, "A")
            } else {
                list.push(e)
            }
        }
        return list
    }

    function test_aStraightAfterAStraightLandsTwentyMetresOn() {
        const a = el("a", "straight", {}, 0, 0, 0)
        const b = el("b", "straight", {}, 50, 50, 33)
        const placed = Snapping.placeToJoin(b, "A", a, "B")
        fuzzyCompare(placed.x, 20, 1e-9)
        fuzzyCompare(placed.y, 0, 1e-9)
        compare(placed.rotation, 0)
    }

    function test_placeToJoinMeetsEndToEnd_data() {
        return [
            { tag: "straight onto a rotated straight", target: ["straight", {}, 0, 0, 90], targetEnd: "B",
              moving: ["straight", {}, 50, 50, 33], ownEnd: "A" },
            { tag: "slalom after a hairpin", target: ["turn", {}, 10, 10, 20], targetEnd: "B",
              moving: ["slalom", {}, 0, 0, 0], ownEnd: "A" },
            { tag: "chicane entered at its exit", target: ["straight", {}, 0, 0, 0], targetEnd: "B",
              moving: ["chicane", {}, 0, 0, 0], ownEnd: "B" },
            { tag: "onto the entry of a left turn", target: ["turn", { direction: "left", angle: 75 }, 0, 0, -40],
              targetEnd: "A", moving: ["straight", {}, 0, 0, 0], ownEnd: "A" }
        ]
    }

    function test_placeToJoinMeetsEndToEnd(row) {
        const target = el("t", row.target[0], row.target[1], row.target[2], row.target[3], row.target[4])
        const moving = el("m", row.moving[0], row.moving[1], row.moving[2], row.moving[3], row.moving[4])
        const placed = Object.assign({}, moving, Snapping.placeToJoin(moving, row.ownEnd, target, row.targetEnd))
        verify(joinedWell(placed, row.ownEnd, target, row.targetEnd))
    }

    function test_findSnapFindsTheNearestOpenEnd() {
        const a = el("a", "straight", {}, 0, 0, 0)          // B at (10, 0)
        const b = el("b", "straight", {}, 20.5, 0.5, 0)     // A at (10.5, 0.5)
        const snap = Snapping.findSnap([a, b], b, 1)
        compare(snap.targetId, "a")
        compare(snap.targetEnd, "B")
        compare(snap.ownEnd, "A")
        compare(Snapping.findSnap([a, b], b, 0.5), null)
    }

    function test_findSnapSkipsEndsJoinedToSomethingElse() {
        const a = el("a", "straight", {}, 0, 0, 0)
        const b = el("b", "straight", {}, 20.5, 0.5, 0)
        a.joins.B = { id: "c", end: "A" }
        compare(Snapping.findSnap([a, b], b, 1), null)
        a.joins.B = { id: "b", end: "A" }
        compare(Snapping.findSnap([a, b], b, 1).targetId, "a")
    }

    function test_findSnapIgnoresTheMovingElement() {
        const b = el("b", "straight", {}, 0, 0, 0)
        compare(Snapping.findSnap([b], b, 100), null)
    }

    function test_joinAndUnjoin() {
        const list = [el("a", "straight"), el("b", "straight")]
        Snapping.join(list, "a", "B", "b", "A")
        compare(JSON.stringify(list[0].joins.B), JSON.stringify({ id: "b", end: "A" }))
        compare(JSON.stringify(list[1].joins.A), JSON.stringify({ id: "a", end: "B" }))
        Snapping.unjoinAll(list, "b")
        compare(list[0].joins.B, null)
        compare(list[1].joins.A, null)
    }

    function test_joiningAnEndThatWasJoinedFreesItsOldPartner() {
        const list = [el("a", "straight"), el("b", "straight"), el("c", "straight")]
        Snapping.join(list, "a", "B", "b", "A")
        Snapping.join(list, "c", "A", "a", "B")
        compare(list[1].joins.A, null)
        compare(list[0].joins.B.id, "c")
    }

    function test_settleKeepsAChainGluedAfterAnEdit() {
        const list = chain([["a", "straight", {}], ["b", "straight", {}], ["c", "turn", {}]])
        const aBefore = JSON.stringify(list[0])
        list[1].props.length = 30
        Snapping.settle(list, "b")
        verify(joinedWell(list[0], "B", list[1], "A"), "a-b")
        verify(joinedWell(list[1], "B", list[2], "A"), "b-c")
        compare(JSON.stringify(list[0]), aBefore)
    }

    function test_settleMovesTheShorterSide() {
        // b sits between a (one element) and c-d (two): the longer side stays put.
        const list = chain([["a", "straight", {}], ["b", "straight", {}], ["c", "straight", {}], ["d", "straight", {}]])
        const cBefore = JSON.stringify(list[2])
        list[1].props.length = 5
        Snapping.settle(list, "b")
        compare(JSON.stringify(list[2]), cBefore)
        verify(joinedWell(list[0], "B", list[1], "A"), "a-b")
        verify(joinedWell(list[1], "B", list[2], "A"), "b-c")
    }

    function test_settleWithOneNeighbourMovesOnlyItself() {
        const list = chain([["a", "straight", {}], ["b", "slalom", {}]])
        const aBefore = JSON.stringify(list[0])
        list[1].props.leadIn = 15
        Snapping.settle(list, "b")
        compare(JSON.stringify(list[0]), aBefore)
        verify(joinedWell(list[0], "B", list[1], "A"))
    }

    function test_glueAllRejoinsChainsAfterScaling() {
        const list = chain([["a", "straight", {}], ["b", "turn", {}], ["c", "chicane", {}]])
        list.push(el("lonely", "straight", {}, 70, 70, 10))
        for (const e of list) { e.x *= 0.5; e.y *= 0.5 }
        const lonely = JSON.stringify(list[3])
        const a = JSON.stringify(list[0])
        Snapping.glueAll(list)
        verify(joinedWell(list[0], "B", list[1], "A"), "a-b")
        verify(joinedWell(list[1], "B", list[2], "A"), "b-c")
        compare(JSON.stringify(list[0]), a)
        compare(JSON.stringify(list[3]), lonely)
    }

    function test_aClosedLoopSettles() {
        const turn = { angle: 90, radius: 6, leadIn: 0, leadOut: 0 }
        const list = chain([["a", "turn", turn], ["b", "turn", turn], ["c", "turn", turn], ["d", "turn", turn]])
        Snapping.join(list, "d", "B", "a", "A")
        list[1].props.radius = 8
        Snapping.settle(list, "b")       // must return, not walk the ring for ever
        Snapping.glueAll(list)
        // A ring with one bigger turn cannot close, so one joint (b's entry) stays open; the walk from a glues the rest.
        verify(joinedWell(list[3], "B", list[0], "A"), "d-a")
        verify(joinedWell(list[2], "B", list[3], "A"), "c-d")
        verify(joinedWell(list[1], "B", list[2], "A"), "b-c")
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_snapping.qml
```

Expected: FAIL (`snapping.mjs` missing).

- [ ] **Step 3: Write `app/qml/logic/snapping.mjs`**

```js
// Joining track elements end to end, and keeping joined chains together after an edit. Ported from the prototype's
// qml/elements/Element.qml (snapToGate, propagateFromSelf, cascadeGate, chainLength, createMate, breakMate) and
// CanvasArea.findNearestGate at 2c79b60. Elements are plain data (see commands.mjs). Every function here except
// findSnap, placeToJoin and otherEnd changes the element objects in the array it is given, so callers pass a copy.
import * as Elements from "./elements.mjs"

export function otherEnd(end) {
    return end === "A" ? "B" : "A"
}

function byId(elements, id) {
    return elements.find(e => e.id === id)
}

// The nearest open end of another element within maxDistance (metres) of either end of `moving`, as
// { targetId, targetEnd, ownEnd, distance }, or null. An end joined to `moving` itself counts as open, so an
// element being dragged can stay where it snapped.
export function findSnap(elements, moving, maxDistance) {
    const own = Elements.endsWorld(moving)
    let best = null
    let bestDistance = maxDistance
    for (const el of elements) {
        if (el.id === moving.id)
            continue
        const ends = Elements.endsWorld(el)
        for (const targetEnd of ["A", "B"]) {
            const mate = el.joins[targetEnd]
            if (mate && mate.id !== moving.id)
                continue
            for (const ownEnd of ["A", "B"]) {
                const d = Math.hypot(own[ownEnd].x - ends[targetEnd].x, own[ownEnd].y - ends[targetEnd].y)
                if (d < bestDistance) {
                    bestDistance = d
                    best = { targetId: el.id, targetEnd: targetEnd, ownEnd: ownEnd, distance: d }
                }
            }
        }
    }
    return best
}

// Where `moving` must sit so that its `ownEnd` meets `target`'s `targetEnd`, facing the opposite way.
export function placeToJoin(moving, ownEnd, target, targetEnd) {
    const goal = Elements.endsWorld(target)[targetEnd]
    const ownLocalHeading = Elements.geometry(moving.type, moving.props).ends[ownEnd].heading
    const rotation = Elements.normalizeAngle(goal.heading + 180 - ownLocalHeading)
    const own = Elements.endsWorld(Object.assign({}, moving, { rotation: rotation }))[ownEnd]
    return { x: moving.x + goal.x - own.x, y: moving.y + goal.y - own.y, rotation: rotation }
}

export function unjoin(elements, id, end) {
    const el = byId(elements, id)
    const mate = el.joins[end]
    if (!mate)
        return
    const other = byId(elements, mate.id)
    if (other)
        other.joins[mate.end] = null
    el.joins[end] = null
}

export function unjoinAll(elements, id) {
    unjoin(elements, id, "A")
    unjoin(elements, id, "B")
}

export function join(elements, aId, aEnd, bId, bEnd) {
    unjoin(elements, aId, aEnd)
    unjoin(elements, bId, bEnd)
    byId(elements, aId).joins[aEnd] = { id: bId, end: bEnd }
    byId(elements, bId).joins[bEnd] = { id: aId, end: aEnd }
}

// How many elements hang off `end` of `el`, not counting any already in `visited`.
function chainLength(elements, el, end, visited) {
    const mate = el.joins[end]
    if (!mate || visited.indexOf(mate.id) >= 0)
        return 0
    visited.push(mate.id)
    return 1 + chainLength(elements, byId(elements, mate.id), otherEnd(mate.end), visited)
}

function moveToMate(elements, el, end) {
    const mate = el.joins[end]
    Object.assign(el, placeToJoin(el, end, byId(elements, mate.id), mate.end))
}

// Moves everything joined beyond `end` of `el` so each element meets the one before it.
function cascade(elements, el, end, visited) {
    const mate = el.joins[end]
    if (!mate || visited.indexOf(mate.id) >= 0)
        return
    const other = byId(elements, mate.id)
    Object.assign(other, placeToJoin(other, mate.end, el, end))
    visited.push(other.id)
    cascade(elements, other, otherEnd(mate.end), visited)
}

// After element `id` changed shape: it moves to meet its neighbour on the longer side of the chain, and the
// shorter side follows it.
export function settle(elements, id) {
    const self = byId(elements, id)
    const hasA = self.joins.A !== null
    const hasB = self.joins.B !== null
    if (!hasA && !hasB)
        return
    if (hasA && hasB) {
        const anchor = chainLength(elements, self, "A", [id]) >= chainLength(elements, self, "B", [id]) ? "A" : "B"
        moveToMate(elements, self, anchor)
        cascade(elements, self, otherEnd(anchor), [id])
    } else {
        moveToMate(elements, self, hasA ? "A" : "B")
    }
}

// Re-glues every joined chain from its first element in the list (which stays where it is).
export function glueAll(elements) {
    const done = []
    for (const el of elements) {
        if (done.indexOf(el.id) >= 0 || (!el.joins.A && !el.joins.B))
            continue
        const visited = [el.id]
        cascade(elements, el, "A", visited)
        cascade(elements, el, "B", visited)
        for (const id of visited)
            done.push(id)
    }
}
```

- [ ] **Step 4: Run it and watch it pass**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_snapping.qml
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add app/qml/logic/snapping.mjs app/tests/qml/tst_snapping.qml
git commit -m "Snapping: find the nearest open end, join end to end, keep chains glued after an edit (ported from the prototype)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `commands.mjs` — every edit, and the undo stack

**Files:**
- Create: `app/qml/logic/commands.mjs`
- Test: `app/tests/qml/tst_commands.qml`

**Interfaces:**
- Consumes: `Elements.defaults/NAMES/PROPS/clampProp`; `Snapping.placeToJoin/join/unjoinAll/settle/glueAll`.
- Produces: `emptyTrack() -> { photo: { path: "", metresPerPixel: 0 }, ruler: null | { a: {x,y}, b: {x,y}, realLength }, targets: { origin: null | {x,y}, direction: null | {x,y} }, elements: [], nextId: 1 }` (ruler ends and targets in photo pixels, realLength in metres); `clone(track)`; `rulerMetresPerPixel(ruler)`; `label(track, name, args)`; `run(stack, track, name, args) -> newTrack` (returns the same `track` object when nothing changed, and then records nothing); `class UndoStack { push(label, before, after, mergeKey); seal(); clear(); canUndo(); canRedo(); undoLabel(); redoLabel(); undo() -> track | null; redo() -> track | null }`.
- Command names and arguments:
  - `newTrack {}`; `setPhoto { path }`
  - `setRuler { a, b, realLength, mergeKey? }` — rescales element positions when metresPerPixel changes, then re-glues chains; refused (no change) if it would leave elements without a scale
  - `removeRuler {}` — refused while elements exist
  - `setTarget { which: "origin"|"direction", point: {x,y} | null, mergeKey? }`
  - `add { type, x, y, rotation?, props?, snap?: { ownEnd, id, end } }` — new id `"e" + nextId`; with `snap`, placed and joined
  - `place { id, x, y, rotation, snap?, verb?: "Move"|"Rotate", mergeKey? }` — unjoins both ends, sets the placement, joins `snap` if given
  - `setProp { id, key, value, mergeKey? }` — clamps, then `settle`; merges consecutive changes to one field by default
  - `remove { id }`; `duplicate { id }` — copy unjoined, 2 m right and 2 m down
- Step labels (shown as "Undo …"): "New track", "Load photo", "Set ruler", "Delete ruler", "Place Origin" / "Move Origin" / "Delete Origin" (and Direction), "Add Straight", "Move Slalom", "Rotate Turn", "Change Track width", "Delete Chicane", "Duplicate Straight".

- [ ] **Step 1: Write the failing test** — `app/tests/qml/tst_commands.qml`

```qml
import QtQuick
import QtTest
import "../../qml/logic/commands.mjs" as Commands
import "../../qml/logic/elements.mjs" as Elements

TestCase {
    name: "Commands"

    // A ruler at 0.1 m per pixel, Origin, and three joined elements e1 (straight) - e2 (turn) - e3 (straight).
    function base() {
        const s = new Commands.UndoStack()
        let t = Commands.emptyTrack()
        t = Commands.run(s, t, "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 })
        t = Commands.run(s, t, "setTarget", { which: "origin", point: { x: 10, y: 10 } })
        t = Commands.run(s, t, "add", { type: "straight", x: 5, y: 5 })
        t = Commands.run(s, t, "add", { type: "turn", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } })
        t = Commands.run(s, t, "add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "A", id: "e2", end: "B" } })
        return t
    }

    function byId(track, id) {
        return track.elements.find(e => e.id === id)
    }

    function endsMeet(track, aId, aEnd, bId, bEnd) {
        const pa = Elements.endsWorld(byId(track, aId))[aEnd]
        const pb = Elements.endsWorld(byId(track, bId))[bEnd]
        return Math.hypot(pa.x - pb.x, pa.y - pb.y) < 1e-9
    }

    function test_everyCommandUndoesAndRedoesExactly_data() {
        return [
            { tag: "new track", name: "newTrack", args: {} },
            { tag: "load photo", name: "setPhoto", args: { path: "file:///C:/lots/lot.png" } },
            { tag: "drag a ruler end", name: "setRuler", args: { a: { x: 0, y: 0 }, b: { x: 200, y: 0 }, realLength: 10 } },
            { tag: "type a ruler length", name: "setRuler", args: { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 12 } },
            { tag: "place Direction", name: "setTarget", args: { which: "direction", point: { x: 500, y: 10 } } },
            { tag: "move Origin", name: "setTarget", args: { which: "origin", point: { x: 20, y: 30 } } },
            { tag: "delete Origin", name: "setTarget", args: { which: "origin", point: null } },
            { tag: "add a free slalom", name: "add", args: { type: "slalom", x: 40, y: 40, rotation: 15 } },
            { tag: "add a joined chicane", name: "add",
              args: { type: "chicane", x: 0, y: 0, snap: { ownEnd: "A", id: "e3", end: "B" } } },
            { tag: "move the middle element", name: "place", args: { id: "e2", x: 60, y: 60, rotation: 0 } },
            { tag: "rotate the last element", name: "place", args: { id: "e3", x: 1, y: 2, rotation: 45, verb: "Rotate" } },
            { tag: "change a turn's radius", name: "setProp", args: { id: "e2", key: "radius", value: 9 } },
            { tag: "change a straight's length", name: "setProp", args: { id: "e1", key: "length", value: 30 } },
            { tag: "delete the middle element", name: "remove", args: { id: "e2" } },
            { tag: "duplicate", name: "duplicate", args: { id: "e1" } }
        ]
    }

    function test_everyCommandUndoesAndRedoesExactly(row) {
        const stack = new Commands.UndoStack()
        const before = base()
        const beforeText = JSON.stringify(before)
        const after = Commands.run(stack, before, row.name, row.args)
        const afterText = JSON.stringify(after)
        verify(afterText !== beforeText, "the command changed something")
        compare(JSON.stringify(before), beforeText, "the old track was not touched")
        compare(JSON.stringify(stack.undo()), beforeText)
        compare(JSON.stringify(stack.redo()), afterText)
    }

    function test_labels() {
        const stack = new Commands.UndoStack()
        let t = base()
        const steps = [
            ["place", { id: "e1", x: 3, y: 3, rotation: 0 }, "Move Straight"],
            ["place", { id: "e2", x: 3, y: 3, rotation: 30, verb: "Rotate" }, "Rotate Turn"],
            ["setProp", { id: "e2", key: "trackWidth", value: 5 }, "Change Track width"],
            ["setTarget", { which: "direction", point: { x: 1, y: 1 } }, "Place Direction"],
            ["setTarget", { which: "direction", point: { x: 2, y: 1 } }, "Move Direction"],
            ["setTarget", { which: "direction", point: null }, "Delete Direction"],
            ["add", { type: "slalom", x: 0, y: 0 }, "Add Slalom"],
            ["duplicate", { id: "e1" }, "Duplicate Straight"],
            ["remove", { id: "e3" }, "Delete Straight"],
            ["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 11 }, "Set ruler"],
            ["setPhoto", { path: "file:///x.png" }, "Load photo"],
            ["newTrack", {}, "New track"]
        ]
        for (const [name, args, label] of steps) {
            t = Commands.run(stack, t, name, args)
            stack.seal()
            compare(stack.undoLabel(), label, name)
        }
    }

    function test_nothingChangedRecordsNothing() {
        const stack = new Commands.UndoStack()
        const t = base()
        const same = Commands.run(stack, t, "setPhoto", { path: "" })
        verify(same === t)
        verify(!stack.canUndo())
    }

    function test_typingIntoOneFieldIsOneStep() {
        const stack = new Commands.UndoStack()
        const t0 = base()
        let t = Commands.run(stack, t0, "setProp", { id: "e1", key: "length", value: 2 })
        t = Commands.run(stack, t, "setProp", { id: "e1", key: "length", value: 25 })
        compare(byId(t, "e1").props.length, 25)
        compare(JSON.stringify(stack.undo()), JSON.stringify(t0))
        verify(!stack.canUndo())
    }

    function test_sealingStartsANewStep() {
        const stack = new Commands.UndoStack()
        let t = Commands.run(stack, base(), "setProp", { id: "e1", key: "length", value: 2 })
        stack.seal()
        t = Commands.run(stack, t, "setProp", { id: "e1", key: "length", value: 25 })
        stack.undo()
        verify(stack.canUndo())
    }

    function test_aDragIsOneStep() {
        const stack = new Commands.UndoStack()
        const t0 = base()
        let t = t0
        for (let i = 1; i <= 5; i++)
            t = Commands.run(stack, t, "place", { id: "e1", x: 5 + i, y: 5, rotation: 0, mergeKey: "drag1" })
        stack.seal()
        compare(JSON.stringify(stack.undo()), JSON.stringify(t0))
        verify(!stack.canUndo())
    }

    function test_aNewStepClearsRedo() {
        const stack = new Commands.UndoStack()
        let t = Commands.run(stack, base(), "add", { type: "slalom", x: 0, y: 0 })
        t = stack.undo()
        verify(stack.canRedo())
        Commands.run(stack, t, "add", { type: "turn", x: 0, y: 0 })
        verify(!stack.canRedo())
    }

    function test_theStackKeepsAtMostItsLimit() {
        const stack = new Commands.UndoStack(3)
        let t = base()
        for (let i = 0; i < 5; i++)
            t = Commands.run(stack, t, "add", { type: "straight", x: i, y: 0 })
        let undone = 0
        while (stack.undo()) undone += 1
        compare(undone, 3)
    }

    function test_addWithASnapJoinsBothWays() {
        const t = base()
        compare(JSON.stringify(byId(t, "e1").joins.B), JSON.stringify({ id: "e2", end: "A" }))
        compare(JSON.stringify(byId(t, "e2").joins.A), JSON.stringify({ id: "e1", end: "B" }))
        verify(endsMeet(t, "e1", "B", "e2", "A"))
        verify(endsMeet(t, "e2", "B", "e3", "A"))
        compare(t.nextId, 4)
    }

    function test_placeUnjoinsAndCanJoinAgain() {
        const s = new Commands.UndoStack()
        let t = Commands.run(s, base(), "place", { id: "e3", x: 90, y: 90, rotation: 0 })
        compare(byId(t, "e3").joins.A, null)
        compare(byId(t, "e2").joins.B, null)
        t = Commands.run(s, t, "place", { id: "e3", x: 0, y: 0, rotation: 0, snap: { ownEnd: "A", id: "e2", end: "B" } })
        verify(endsMeet(t, "e2", "B", "e3", "A"))
        compare(byId(t, "e2").joins.B.id, "e3")
    }

    function test_setPropClampsAndKeepsTheChainGlued() {
        const t = Commands.run(new Commands.UndoStack(), base(), "setProp", { id: "e2", key: "trackWidth", value: 50 })
        compare(byId(t, "e2").props.trackWidth, 20)
        const u = Commands.run(new Commands.UndoStack(), base(), "setProp", { id: "e2", key: "radius", value: 15 })
        verify(endsMeet(u, "e1", "B", "e2", "A"))
        verify(endsMeet(u, "e2", "B", "e3", "A"))
    }

    function test_undoingADeleteRestoresTheNeighboursJoins() {
        const stack = new Commands.UndoStack()
        const t0 = base()
        const t1 = Commands.run(stack, t0, "remove", { id: "e2" })
        compare(byId(t1, "e1").joins.B, null)
        compare(byId(t1, "e3").joins.A, null)
        const back = stack.undo()
        compare(byId(back, "e1").joins.B.id, "e2")
        compare(byId(back, "e3").joins.A.id, "e2")
        compare(JSON.stringify(back), JSON.stringify(t0))
    }

    function test_duplicateIsUnjoinedAndOffset() {
        const t = Commands.run(new Commands.UndoStack(), base(), "duplicate", { id: "e2" })
        const copy = t.elements[t.elements.length - 1]
        const original = byId(t, "e2")
        compare(copy.id, "e4")
        compare(copy.joins.A, null)
        compare(copy.joins.B, null)
        compare(copy.x, original.x + 2)
        compare(copy.y, original.y + 2)
        compare(JSON.stringify(copy.props), JSON.stringify(original.props))
        compare(original.joins.A.id, "e1")
    }

    function test_theRulerRescalesAndKeepsChainsGlued() {
        const stack = new Commands.UndoStack()
        const t0 = base()
        const e1Pixels = { x: byId(t0, "e1").x / 0.1, y: byId(t0, "e1").y / 0.1 }
        const t1 = Commands.run(stack, t0, "setRuler", { a: { x: 0, y: 0 }, b: { x: 200, y: 0 }, realLength: 10 })
        compare(t1.photo.metresPerPixel, 0.05)
        fuzzyCompare(byId(t1, "e1").x / 0.05, e1Pixels.x, 1e-9)
        fuzzyCompare(byId(t1, "e1").y / 0.05, e1Pixels.y, 1e-9)
        compare(JSON.stringify(byId(t1, "e1").props), JSON.stringify(byId(t0, "e1").props))
        verify(endsMeet(t1, "e1", "B", "e2", "A"), "e1-e2")
        verify(endsMeet(t1, "e2", "B", "e3", "A"), "e2-e3")
        compare(JSON.stringify(stack.undo()), JSON.stringify(t0))
    }

    function test_theRulerCannotLoseItsScaleUnderElements() {
        const t0 = base()
        const stack = new Commands.UndoStack()
        verify(Commands.run(stack, t0, "setRuler", { a: { x: 5, y: 5 }, b: { x: 5, y: 5 }, realLength: 10 }) === t0)
        verify(Commands.run(stack, t0, "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 0 }) === t0)
        verify(Commands.run(stack, t0, "removeRuler", {}) === t0)
        verify(!stack.canUndo())
    }

    function test_aRulerWithoutElementsCanBeRemoved() {
        const s = new Commands.UndoStack()
        let t = Commands.run(s, Commands.emptyTrack(), "setRuler", { a: { x: 0, y: 0 }, b: { x: 50, y: 0 }, realLength: 0 })
        compare(t.photo.metresPerPixel, 0)
        t = Commands.run(s, t, "removeRuler", {})
        compare(t.ruler, null)
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_commands.qml
```

Expected: FAIL (`commands.mjs` missing).

- [ ] **Step 3: Write `app/qml/logic/commands.mjs`**

```js
// The track, and every edit to it. A track is plain data:
//   { photo: { path, metresPerPixel },             path "" means the blueprint; metresPerPixel comes from the ruler
//     ruler: null | { a: {x, y}, b: {x, y}, realLength },   ends in photo pixels, realLength in metres (0 = not set)
//     targets: { origin: null | {x, y}, direction: null | {x, y} },  photo pixels
//     elements: [ { id, type, x, y, rotation, props, joins: { A: null | {id, end}, B: ... } } ],  canvas metres
//     nextId }
// Every command is a pure function from the old track to a new one; `run` records each on an UndoStack, which keeps
// the track before and after each step, so undo is exact. Tests: tests/qml/tst_commands.qml.
import * as Elements from "./elements.mjs"
import * as Snapping from "./snapping.mjs"

export function emptyTrack() {
    return { photo: { path: "", metresPerPixel: 0 }, ruler: null, targets: { origin: null, direction: null },
             elements: [], nextId: 1 }
}

export function clone(track) {
    return JSON.parse(JSON.stringify(track))
}

export function rulerMetresPerPixel(ruler) {
    if (!ruler || !(ruler.realLength > 0))
        return 0
    const pixels = Math.hypot(ruler.b.x - ruler.a.x, ruler.b.y - ruler.a.y)
    return pixels > 0 ? ruler.realLength / pixels : 0
}

function find(track, id) {
    const el = track.elements.find(e => e.id === id)
    if (!el)
        throw new Error("No element " + id)
    return el
}

function attach(track, el, snap) {
    if (!snap)
        return
    Object.assign(el, Snapping.placeToJoin(el, snap.ownEnd, find(track, snap.id), snap.end))
    Snapping.join(track.elements, el.id, snap.ownEnd, snap.id, snap.end)
}

function point(p) {
    return p ? { x: p.x, y: p.y } : null
}

// Each takes a copy of the track (theirs to change) and the arguments, and returns the new track.
const COMMANDS = {
    newTrack() {
        return emptyTrack()
    },
    setPhoto(t, a) {
        t.photo.path = a.path || ""
        return t
    },
    setRuler(t, a) {
        const oldScale = t.photo.metresPerPixel
        t.ruler = { a: point(a.a), b: point(a.b), realLength: a.realLength || 0 }
        const newScale = rulerMetresPerPixel(t.ruler)
        if (t.elements.length > 0 && !(newScale > 0))
            return null                                    // refused: the elements' sizes need a scale
        if (oldScale > 0 && newScale > 0 && newScale !== oldScale) {
            // Elements stay on the same spots of the photo; their sizes in metres do not change.
            const k = newScale / oldScale
            for (const el of t.elements) {
                el.x *= k
                el.y *= k
            }
            Snapping.glueAll(t.elements)
        }
        t.photo.metresPerPixel = newScale
        return t
    },
    removeRuler(t) {
        if (t.elements.length > 0)
            return null
        t.ruler = null
        t.photo.metresPerPixel = 0
        return t
    },
    setTarget(t, a) {
        t.targets[a.which] = point(a.point)
        return t
    },
    add(t, a) {
        const el = { id: "e" + t.nextId, type: a.type, x: a.x, y: a.y, rotation: a.rotation || 0,
                     props: Object.assign(Elements.defaults(a.type), a.props || {}), joins: { A: null, B: null } }
        t.nextId += 1
        t.elements.push(el)
        attach(t, el, a.snap)
        return t
    },
    place(t, a) {
        const el = find(t, a.id)
        Snapping.unjoinAll(t.elements, el.id)
        el.x = a.x
        el.y = a.y
        el.rotation = a.rotation
        attach(t, el, a.snap)
        return t
    },
    setProp(t, a) {
        const el = find(t, a.id)
        el.props[a.key] = Elements.clampProp(el.type, a.key, a.value).value
        Snapping.settle(t.elements, el.id)
        return t
    },
    remove(t, a) {
        find(t, a.id)
        Snapping.unjoinAll(t.elements, a.id)
        t.elements = t.elements.filter(e => e.id !== a.id)
        return t
    },
    duplicate(t, a) {
        const source = find(t, a.id)
        t.elements.push({ id: "e" + t.nextId, type: source.type, x: source.x + 2, y: source.y + 2,
                          rotation: source.rotation, props: Object.assign({}, source.props), joins: { A: null, B: null } })
        t.nextId += 1
        return t
    }
}

function capitalised(text) {
    return text.charAt(0).toUpperCase() + text.slice(1)
}

// The step's name in the Edit menu ("Undo Move Straight"), worked out from the track before the step.
export function label(track, name, a) {
    const named = id => {
        const el = track.elements.find(e => e.id === id)
        return el ? Elements.NAMES[el.type] : ""
    }
    switch (name) {
    case "newTrack": return "New track"
    case "setPhoto": return "Load photo"
    case "setRuler": return "Set ruler"
    case "removeRuler": return "Delete ruler"
    case "setTarget":
        return (a.point ? (track.targets[a.which] ? "Move " : "Place ") : "Delete ") + capitalised(a.which)
    case "add": return "Add " + Elements.NAMES[a.type]
    case "place": return (a.verb || "Move") + " " + named(a.id)
    case "setProp": {
        const el = track.elements.find(e => e.id === a.id)
        const def = el ? Elements.PROPS[el.type].find(p => p.key === a.key) : null
        return "Change " + (def ? def.label : a.key)
    }
    case "remove": return "Delete " + named(a.id)
    case "duplicate": return "Duplicate " + named(a.id)
    }
    return name
}

function mergeKeyFor(name, a) {
    if (a.mergeKey)
        return a.mergeKey
    return name === "setProp" ? "prop:" + a.id + ":" + a.key : ""
}

// Runs one command and records it. Returns the new track, or `track` itself when nothing changed (or the command
// was refused), in which case nothing is recorded.
export function run(stack, track, name, args) {
    const command = COMMANDS[name]
    if (!command)
        throw new Error("Unknown command " + name)
    const a = args || {}
    const after = command(clone(track), a)
    if (after === null || JSON.stringify(after) === JSON.stringify(track))
        return track
    stack.push(label(track, name, a), track, after, mergeKeyFor(name, a))
    return after
}

// Steps of { label, before, after, mergeKey }. A step whose mergeKey matches the last one, with no seal in between,
// replaces that step's `after`: typing into one field, or one drag, is one step. seal() ends the merging.
export class UndoStack {
    constructor(limit) {
        this.limit = limit || 200
        this.clear()
    }
    clear() {
        this.done = []
        this.undone = []
        this.sealed = true
    }
    push(label, before, after, mergeKey) {
        const top = this.done[this.done.length - 1]
        if (!this.sealed && top && mergeKey && top.mergeKey === mergeKey) {
            top.after = after
        } else {
            this.done.push({ label: label, before: before, after: after, mergeKey: mergeKey })
            if (this.done.length > this.limit)
                this.done.shift()
        }
        this.undone = []
        this.sealed = !mergeKey
    }
    seal() { this.sealed = true }
    canUndo() { return this.done.length > 0 }
    canRedo() { return this.undone.length > 0 }
    undoLabel() { return this.done.length > 0 ? this.done[this.done.length - 1].label : "" }
    redoLabel() { return this.undone.length > 0 ? this.undone[this.undone.length - 1].label : "" }
    undo() {
        const step = this.done.pop()
        if (!step)
            return null
        this.undone.push(step)
        this.sealed = true
        return step.before
    }
    redo() {
        const step = this.undone.pop()
        if (!step)
            return null
        this.done.push(step)
        this.sealed = true
        return step.after
    }
}
```

- [ ] **Step 4: Run it and watch it pass**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_commands.qml
```

Expected: all pass. (In `test_labels` the slalom becomes `e4` and the duplicate `e5`; deleting `e3` names it "Straight".)

- [ ] **Step 5: Commit**

```bash
git add app/qml/logic/commands.mjs app/tests/qml/tst_commands.qml
git commit -m "Commands: every edit as a pure step on plain track data, with an undo stack that merges drags and typing" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `frame.mjs` and `postprocess.mjs` — cones for the whole track, in the export frame

**Files:**
- Create: `app/qml/logic/frame.mjs`, `app/qml/logic/postprocess.mjs`
- Test: `app/tests/qml/tst_frame.qml`, `app/tests/qml/tst_postprocess.qml`

**Interfaces:**
- Consumes: `Elements.conesWorld`; `FOOT`; (tests) `Commands`, `Snapping.join`.
- Produces (`frame.mjs`): `normalize(deg)` into (-180, 180]; `makeFrame(originPx, directionPx, metresPerPixel) -> { ox, oy, ux, uy, theta, distance } | null` (origin in canvas metres, unit axis, axis angle in canvas degrees, distance in metres); `toFrame(frame, p) -> {x, y}`; `fromFrame(frame, q) -> {x, y}`; `headingToFrame(frame, h)`.
- Produces (`postprocess.mjs`): `MESSAGES { noRuler, noLength, noOrigin, noDirection, tooClose, noTrack }`; `DEDUPE_METRES`; `MIN_TARGET_DISTANCE = 1`; `check(track) -> null | { message, target: null | { kind: "ruler"|"origin"|"direction"|"element", id? } }`; `coneGroups(elements)`; `dedupe(groups, epsilon)`; `buildChains(elements, groups)`; `stitch(chains)`; `run(track) -> { error } | { cones: [{index, type, x, y, heading}] (export frame), canvasCones: [{index, type, x, y, heading}] (canvas metres), targetDistance }`.

- [ ] **Step 1: Write the failing tests**

`app/tests/qml/tst_frame.qml`:

```qml
import QtQuick
import QtTest
import "../../qml/logic/frame.mjs" as Frame

TestCase {
    name: "Frame"

    // Origin at (10 m, 10 m); Direction straight up the screen, 10 m away.
    function upFrame() {
        return Frame.makeFrame({ x: 100, y: 100 }, { x: 100, y: 0 }, 0.1)
    }

    function near(p, x, y) {
        verify(Math.abs(p.x - x) < 1e-9 && Math.abs(p.y - y) < 1e-9, "(" + p.x + ", " + p.y + ") should be (" + x + ", " + y + ")")
    }

    function test_originIsZero() {
        near(Frame.toFrame(upFrame(), { x: 10, y: 10 }), 0, 0)
    }

    function test_directionLiesOnPlusX() {
        const f = upFrame()
        near(Frame.toFrame(f, { x: 10, y: 0 }), 10, 0)
        fuzzyCompare(f.distance, 10, 1e-9)
    }

    function test_leftOfTheAxisIsPlusY() {
        near(Frame.toFrame(upFrame(), { x: 9, y: 10 }), 0, 1)
        near(Frame.toFrame(upFrame(), { x: 11, y: 5 }), 5, -1)
        // An axis along the screen: left of it is up the screen.
        const along = Frame.makeFrame({ x: 0, y: 50 }, { x: 400, y: 50 }, 0.1)
        near(Frame.toFrame(along, { x: 3, y: 2 }), 3, 3)
    }

    function test_headingsAreCounterClockwise() {
        const f = upFrame()
        compare(Frame.headingToFrame(f, -90), 0)
        compare(Frame.headingToFrame(f, 180), 90)
        compare(Frame.headingToFrame(f, 0), -90)
    }

    function test_fromFrameUndoesToFrame() {
        const f = Frame.makeFrame({ x: 37, y: 120 }, { x: 410, y: -55 }, 0.073)
        for (const p of [{ x: 0, y: 0 }, { x: 12.5, y: -3 }, { x: -40, y: 81 }]) {
            const back = Frame.fromFrame(f, Frame.toFrame(f, p))
            near(back, p.x, p.y)
        }
    }

    function test_noFrameWithoutBothTargetsAndAScale() {
        compare(Frame.makeFrame(null, { x: 1, y: 1 }, 0.1), null)
        compare(Frame.makeFrame({ x: 1, y: 1 }, null, 0.1), null)
        compare(Frame.makeFrame({ x: 1, y: 1 }, { x: 5, y: 1 }, 0), null)
        compare(Frame.makeFrame({ x: 1, y: 1 }, { x: 1, y: 1 }, 0.1), null)
    }

    function test_normalize() {
        compare(Frame.normalize(190), -170)
        compare(Frame.normalize(-190), 170)
        compare(Frame.normalize(-180), 180)
        compare(Frame.normalize(540), 180)
        compare(Frame.normalize(0), 0)
    }
}
```

`app/tests/qml/tst_postprocess.qml`:

```qml
import QtQuick
import QtTest
import "../../qml/logic/commands.mjs" as Commands
import "../../qml/logic/postprocess.mjs" as Post
import "../../qml/logic/snapping.mjs" as Snapping

TestCase {
    name: "PostProcess"

    function build(steps) {
        const s = new Commands.UndoStack()
        let t = Commands.emptyTrack()
        for (const step of steps)
            t = Commands.run(s, t, step[0], step[1])
        return t
    }
    // 0.1 m per pixel.
    function scale() { return [["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 }]] }
    // Origin at (0 m, 5 m), x along the screen.
    function targets() {
        return [["setTarget", { which: "origin", point: { x: 0, y: 50 } }],
                ["setTarget", { which: "direction", point: { x: 400, y: 50 } }]]
    }
    function xs(result) { return result.cones.map(c => Math.round(c.x * 1000) / 1000) }

    function test_check_data() {
        return [
            { tag: "no ruler", steps: [], message: Post.MESSAGES.noRuler, kind: "" },
            { tag: "no real length", steps: [["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 0 }]],
              message: Post.MESSAGES.noLength, kind: "ruler" },
            { tag: "no Origin", steps: scale(), message: Post.MESSAGES.noOrigin, kind: "" },
            { tag: "no Direction", steps: scale().concat([["setTarget", { which: "origin", point: { x: 0, y: 0 } }]]),
              message: Post.MESSAGES.noDirection, kind: "" },
            { tag: "targets too close", steps: scale().concat([["setTarget", { which: "origin", point: { x: 0, y: 0 } }],
                                                              ["setTarget", { which: "direction", point: { x: 9, y: 0 } }]]),
              message: Post.MESSAGES.tooClose, kind: "direction" },
            { tag: "no track", steps: scale().concat(targets()), message: Post.MESSAGES.noTrack, kind: "" }
        ]
    }

    function test_check(row) {
        const error = Post.check(build(row.steps))
        compare(error.message, row.message)
        compare(error.target ? error.target.kind : "", row.kind)
        const result = Post.run(build(row.steps))
        compare(result.error.message, row.message)
    }

    function test_aReadyTrackPasses() {
        compare(Post.check(build(scale().concat(targets(), [["add", { type: "straight", x: 10, y: 5 }]]))), null)
    }

    function test_conesFollowTheDrivingOrderAlongAChain() {
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } }]
        ]))
        const result = Post.run(t)
        compare(JSON.stringify(xs(result)), JSON.stringify([0, 0, 10, 10, 20, 20, 30, 30, 40, 40]))
        fuzzyCompare(result.targetDistance, 40, 1e-9)
    }

    function test_aReversedElementIsWalkedTheRightWay() {
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "B", id: "e1", end: "B" } }]
        ]))
        compare(t.elements[1].rotation, 180)
        compare(JSON.stringify(xs(Post.run(t))), JSON.stringify([0, 0, 10, 10, 20, 20, 30, 30, 40, 40]))
    }

    function test_conesAtAJoinAreNotDoubled() {
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } }]
        ]))
        const groups = Post.coneGroups(t.elements)
        compare(groups[0].cones.length + groups[1].cones.length, 12)
        compare(Post.run(t).cones.length, 10)
    }

    function test_separateChainsAreStitchedByNearestEnd() {
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 60, y: 5, rotation: 180 }]
        ]))
        compare(JSON.stringify(xs(Post.run(t))), JSON.stringify([0, 0, 10, 10, 20, 20, 50, 50, 60, 60, 70, 70]))
    }

    function test_yIsToTheLeftOfTheAxis() {
        const t = build(scale().concat(targets(), [["add", { type: "straight", x: 10, y: 0 }]]))   // 5 m up the screen
        for (const c of Post.run(t).cones)
            verify(Math.abs(c.y - 5) < 2 + 1e-9 && c.y > 0, "y " + c.y)
    }

    function test_aClosedLoopListsEveryConeOnce() {
        const turn = { angle: 90, radius: 6, leadIn: 0, leadOut: 0 }
        let t = build(scale().concat(targets(), [
            ["add", { type: "turn", x: 20, y: 20, props: turn }],
            ["add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: "e1", end: "B" } }],
            ["add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: "e2", end: "B" } }],
            ["add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: "e3", end: "B" } }]
        ]))
        t = Commands.clone(t)
        Snapping.join(t.elements, "e4", "B", "e1", "A")
        const groups = Post.coneGroups(t.elements)
        Post.dedupe(groups, Post.DEDUPE_METRES)
        const expected = groups.reduce((n, g) => n + g.cones.length, 0)
        const result = Post.run(t)
        compare(result.cones.length, expected)
        for (let i = 0; i < result.cones.length; i++)
            compare(result.cones[i].index, i)
    }

    function test_canvasConesMatchTheExportCones() {
        const t = build(scale().concat(targets(), [["add", { type: "slalom", x: 40, y: 20, rotation: 30 }]]))
        const r = Post.run(t)
        compare(r.canvasCones.length, r.cones.length)
        compare(r.canvasCones[3].type, r.cones[3].type)
    }
}
```

- [ ] **Step 2: Run them and watch them fail**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_frame.qml
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_postprocess.qml
```

Expected: FAIL (modules missing).

- [ ] **Step 3: Write `app/qml/logic/frame.mjs`**

```js
// The export frame: x from the Origin target toward the Direction target, y 90° to the left of x seen from above,
// headings in degrees counter-clockwise from +x, all in metres. The canvas has x right and y down the screen with
// headings clockwise on screen, so "left" there is the axis turned a quarter anticlockwise on screen.
// Tests: tests/qml/tst_frame.qml.

export function normalize(degrees) {
    let d = degrees % 360
    if (d > 180) d -= 360
    if (d <= -180) d += 360
    return d
}

// From the two targets (photo pixels) and the ruler's scale; null until both targets exist apart and a scale is set.
export function makeFrame(originPx, directionPx, metresPerPixel) {
    if (!originPx || !directionPx || !(metresPerPixel > 0))
        return null
    const ox = originPx.x * metresPerPixel
    const oy = originPx.y * metresPerPixel
    const dx = directionPx.x * metresPerPixel - ox
    const dy = directionPx.y * metresPerPixel - oy
    const distance = Math.hypot(dx, dy)
    if (!(distance > 0))
        return null
    return { ox: ox, oy: oy, ux: dx / distance, uy: dy / distance, theta: Math.atan2(dy, dx) * 180 / Math.PI,
             distance: distance }
}

// Canvas metres to the export frame.
export function toFrame(frame, p) {
    const dx = p.x - frame.ox
    const dy = p.y - frame.oy
    return { x: dx * frame.ux + dy * frame.uy, y: dx * frame.uy - dy * frame.ux }
}

// The export frame to canvas metres.
export function fromFrame(frame, q) {
    return { x: frame.ox + q.x * frame.ux + q.y * frame.uy, y: frame.oy + q.x * frame.uy - q.y * frame.ux }
}

// A canvas heading (clockwise on screen) as an export heading (counter-clockwise from +x).
export function headingToFrame(frame, heading) {
    return normalize(frame.theta - heading)
}
```

- [ ] **Step 4: Write `app/qml/logic/postprocess.mjs`**

```js
// Post-processing: every cone of the track, in driving order, in the export frame. Ported from the prototype's
// qml/PostProcessor.qml and qml/elements/ConeUtils.js at 2c79b60: cones per element, duplicates at joins removed,
// joined chains walked from an open end, separate chains stitched nearest end first. Tests:
// tests/qml/tst_postprocess.qml and the port check (tests/qml/tst_portcheck.qml).
import * as Elements from "./elements.mjs"
import * as Frame from "./frame.mjs"
import { FOOT } from "./units.mjs"

export const DEDUPE_METRES = 0.4 * FOOT
export const MIN_TARGET_DISTANCE = 1
export const MESSAGES = {
    noRuler: "Place the ruler on something of known length, then set its real length",
    noLength: "Set the ruler's real length",
    noOrigin: "Place the Origin target",
    noDirection: "Place the Direction target",
    tooClose: "Origin and Direction are closer than 1 m: move Direction further away",
    noTrack: "Nothing to process yet: add some track"
}

// What stops post-processing, or null when the track is ready.
export function check(track) {
    const scale = track.photo.metresPerPixel
    if (!track.ruler)
        return { message: MESSAGES.noRuler, target: null }
    if (!(scale > 0))
        return { message: MESSAGES.noLength, target: { kind: "ruler" } }
    if (!track.targets.origin)
        return { message: MESSAGES.noOrigin, target: null }
    if (!track.targets.direction)
        return { message: MESSAGES.noDirection, target: null }
    const frame = Frame.makeFrame(track.targets.origin, track.targets.direction, scale)
    if (!frame || frame.distance < MIN_TARGET_DISTANCE)
        return { message: MESSAGES.tooClose, target: { kind: "direction" } }
    if (track.elements.length === 0)
        return { message: MESSAGES.noTrack, target: null }
    return null
}

// Each element's cones in canvas metres, in the element's own order (entry A to exit B).
export function coneGroups(elements) {
    return elements.map(el => ({ id: el.id, cones: Elements.conesWorld(el) }))
}

// Removes the later of any two cones closer than epsilon (they meet at joins). Changes `groups`.
export function dedupe(groups, epsilon) {
    const flat = []
    groups.forEach((g, gi) => g.cones.forEach(c => flat.push({ group: gi, cone: c })))
    const removed = new Array(flat.length).fill(false)
    for (let i = 0; i < flat.length; i++) {
        if (removed[i])
            continue
        for (let j = i + 1; j < flat.length; j++) {
            if (removed[j])
                continue
            const dx = flat[i].cone.x - flat[j].cone.x
            const dy = flat[i].cone.y - flat[j].cone.y
            if (Math.sqrt(dx * dx + dy * dy) < epsilon)
                removed[j] = true
        }
    }
    groups.forEach((g, gi) => {
        g.cones = flat.filter((f, k) => f.group === gi && !removed[k]).map(f => f.cone)
    })
}

function walk(elements, groups, start, startEnd, visited) {
    const out = []
    let current = start
    let enter = startEnd
    while (current && visited.indexOf(current.id) < 0) {
        visited.push(current.id)
        const cones = groups.find(g => g.id === current.id).cones
        if (enter === "B")
            for (let i = cones.length - 1; i >= 0; i--) out.push(cones[i])
        else
            for (const c of cones) out.push(c)
        const exit = enter === "A" ? "B" : "A"
        const mate = current.joins[exit]
        if (mate && visited.indexOf(mate.id) < 0) {
            current = elements.find(e => e.id === mate.id)
            enter = mate.end
        } else {
            current = null
        }
    }
    return out
}

// Cone lists, one per joined chain: chains with an open end are walked from it; closed loops from their first element.
export function buildChains(elements, groups) {
    const visited = []
    const chains = []
    for (const el of elements) {
        if (visited.indexOf(el.id) >= 0)
            continue
        const hasA = el.joins.A !== null
        const hasB = el.joins.B !== null
        if (hasA && hasB)
            continue
        const cones = walk(elements, groups, el, hasA ? "B" : "A", visited)
        if (cones.length > 0)
            chains.push(cones)
    }
    for (const el of elements) {
        if (visited.indexOf(el.id) >= 0)
            continue
        const cones = walk(elements, groups, el, "A", visited)
        if (cones.length > 0)
            chains.push(cones)
    }
    return chains
}

function distance(a, b) {
    return Math.hypot(a.x - b.x, a.y - b.y)
}

// Chains joined into one list: from the first, each next chain is whichever start or end is nearest, reversed if
// its end was nearer.
export function stitch(chains) {
    if (chains.length === 0)
        return []
    const remaining = chains.slice()
    let ordered = remaining.shift().slice()
    while (remaining.length > 0) {
        const end = ordered[ordered.length - 1]
        let best = -1
        let reversed = false
        let bestDistance = Infinity
        remaining.forEach((chain, i) => {
            const dStart = distance(end, chain[0])
            const dEnd = distance(end, chain[chain.length - 1])
            if (dStart < bestDistance) { bestDistance = dStart; best = i; reversed = false }
            if (dEnd < bestDistance) { bestDistance = dEnd; best = i; reversed = true }
        })
        const chosen = remaining.splice(best, 1)[0]
        ordered = ordered.concat(reversed ? chosen.slice().reverse() : chosen)
    }
    return ordered
}

export function run(track) {
    const error = check(track)
    if (error)
        return { error: error }
    const frame = Frame.makeFrame(track.targets.origin, track.targets.direction, track.photo.metresPerPixel)
    const groups = coneGroups(track.elements)
    dedupe(groups, DEDUPE_METRES)
    const ordered = stitch(buildChains(track.elements, groups))
    const cones = []
    const canvasCones = []
    ordered.forEach((c, index) => {
        const q = Frame.toFrame(frame, c)
        cones.push({ index: index, type: c.type, x: q.x, y: q.y, heading: Frame.headingToFrame(frame, c.heading) })
        canvasCones.push({ index: index, type: c.type, x: c.x, y: c.y, heading: c.heading })
    })
    return { cones: cones, canvasCones: canvasCones, targetDistance: frame.distance }
}
```

- [ ] **Step 5: Run them and watch them pass**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_frame.qml
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_postprocess.qml
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add app/qml/logic/frame.mjs app/qml/logic/postprocess.mjs app/tests/qml/tst_frame.qml app/tests/qml/tst_postprocess.qml
git commit -m "Post-processing: cones for the whole track in driving order, in metres with y to the left (ported from the prototype)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Port check — the new cones match the prototype's

**Files:**
- Create: `app/tests/qml/fixtures/prototype.mjs`, `app/tests/qml/fixtures/sampletrack.mjs`
- Test: `app/tests/qml/tst_portcheck.qml`

**Interfaces:**
- Consumes: `Commands.run/emptyTrack/UndoStack`, `Post.run`, `Units.FOOT`.
- Produces (fixtures, test-only): `Prototype.run(trackElements, pixelsPerFoot, targetA, targetB) -> [{index, coneType, x, y, heading}]` (feet, y to the right, headings clockwise); `Sample.track()`, `Sample.prototypeElements(track)`, `Sample.pixelsPerFoot(track)`, `Sample.prototypeTarget(point)`.

The prototype's cone code is transcribed as a fixture from commit 2c79b60 (`git show 2c79b60:Conestructor/qml/elements/ConeUtils.js` and the element files). Read those files beside the fixture while writing it: the transcription must change only QML property reads (now `el.<name>`) and `Qt.point` (now `{x, y}`).

- [ ] **Step 1: Write the prototype fixture** — `app/tests/qml/fixtures/prototype.mjs`

```js
// The prototype's cone code at commit 2c79b60, kept as the port check's reference. Transcribed from
// Conestructor/qml/elements/ConeUtils.js, Straight.qml, Slalom.qml, Chicane.qml, Hairpin.qml and PostProcessor.qml:
// QML property reads became reads from a plain element object `el` (prototype property names), Qt.point became
// {x, y}, the duplicated ConeUtils functions appear once, and nothing else changed. Pixels and feet, y down the
// screen, headings clockwise. Do not fix anything here: this is what the new code is compared against.

// ---- ConeUtils.js ----

function straightConeSegment(originX, originY, angleRad, lengthPx, halfWidthPx, pixelsPerFoot, minSpacingFt, maxSpacingFt) {
    var maxSpacingPx = maxSpacingFt * pixelsPerFoot
    var n = lengthPx > 0 ? Math.max(1, Math.ceil(lengthPx / maxSpacingPx)) : 0
    var spacingPx = n > 0 ? lengthPx / n : 0

    var dirX = Math.cos(angleRad)
    var dirY = Math.sin(angleRad)
    var nx = -Math.sin(angleRad)
    var ny = Math.cos(angleRad)

    var cones = []
    for (var i = 0; i <= n; i++) {
        var d = spacingPx * i
        var px = originX + dirX * d
        var py = originY + dirY * d
        cones.push({ x: px + nx * halfWidthPx, y: py + ny * halfWidthPx, heading: 0, coneType: "standing" })
        cones.push({ x: px - nx * halfWidthPx, y: py - ny * halfWidthPx, heading: 0, coneType: "standing" })
    }
    return cones
}

function computeArcLengths(points) {
    var arcLen = [0]
    for (var i = 1; i < points.length; i++) {
        var dx = points[i].x - points[i - 1].x
        var dy = points[i].y - points[i - 1].y
        arcLen.push(arcLen[i - 1] + Math.sqrt(dx * dx + dy * dy))
    }
    return arcLen
}

function interpolateAtArcLength(points, arcLen, targetLen) {
    for (var i = 1; i < arcLen.length; i++) {
        if (arcLen[i] >= targetLen) {
            var segStart = arcLen[i - 1]
            var segEnd = arcLen[i]
            var t = (segEnd > segStart) ? (targetLen - segStart) / (segEnd - segStart) : 0
            var p0 = points[i - 1]
            var p1 = points[i]
            return {
                x: p0.x + (p1.x - p0.x) * t,
                y: p0.y + (p1.y - p0.y) * t,
                heading: p0.heading + (p1.heading - p0.heading) * t
            }
        }
    }
    return points[points.length - 1]
}

function sampleInteriorByArcLength(points, minSpacingFt, maxSpacingFt, pixelsPerFoot) {
    var arcLen = computeArcLengths(points)
    var totalLen = arcLen[arcLen.length - 1]
    var maxSpacingPx = maxSpacingFt * pixelsPerFoot

    var n = Math.max(1, Math.ceil(totalLen / maxSpacingPx))
    var result = []
    for (var i = 1; i < n; i++) {
        var targetLen = totalLen * i / n
        var pt = interpolateAtArcLength(points, arcLen, targetLen)
        pt.arcFraction = totalLen > 0 ? targetLen / totalLen : 0
        result.push(pt)
    }
    return result
}

function dedupeElementCones(elementConeGroups, epsilonPx) {
    var flat = []
    for (var g = 0; g < elementConeGroups.length; g++) {
        var cones = elementConeGroups[g].cones
        for (var c = 0; c < cones.length; c++) {
            flat.push({ groupIndex: g, coneIndex: c, cone: cones[c] })
        }
    }

    var removed = new Array(flat.length).fill(false)

    for (var i = 0; i < flat.length; i++) {
        if (removed[i]) continue
        for (var j = i + 1; j < flat.length; j++) {
            if (removed[j]) continue
            var dx = flat[i].cone.x - flat[j].cone.x
            var dy = flat[i].cone.y - flat[j].cone.y
            if (Math.sqrt(dx * dx + dy * dy) < epsilonPx) {
                removed[j] = true
            }
        }
    }

    for (var g2 = 0; g2 < elementConeGroups.length; g2++) {
        var keep = []
        for (var c2 = 0; c2 < flat.length; c2++) {
            if (flat[c2].groupIndex === g2 && !removed[c2]) {
                keep.push(flat[c2].cone)
            }
        }
        elementConeGroups[g2].cones = keep
    }
}

function distance(a, b) {
    var dx = a.x - b.x, dy = a.y - b.y
    return Math.sqrt(dx * dx + dy * dy)
}

function findGroupCones(element, elementConeGroups) {
    for (var i = 0; i < elementConeGroups.length; i++) {
        if (elementConeGroups[i].element === element) return elementConeGroups[i].cones
    }
    return []
}

function appendElementCones(element, enterGate, elementConeGroups, outList) {
    var cones = findGroupCones(element, elementConeGroups)
    if (enterGate === "B") {
        for (var i = cones.length - 1; i >= 0; i--) outList.push(cones[i])
    } else {
        for (var j = 0; j < cones.length; j++) outList.push(cones[j])
    }
}

function walkChain(startElement, startGate, visited, elementConeGroups) {
    var outList = []
    var current = startElement
    var enterGate = startGate

    while (current && visited.indexOf(current) === -1) {
        visited.push(current)
        appendElementCones(current, enterGate, elementConeGroups, outList)

        var exitGate = enterGate === "A" ? "B" : "A"
        var mate = exitGate === "A" ? current.gateAMate : current.gateBMate

        if (mate && visited.indexOf(mate.element) === -1) {
            current = mate.element
            enterGate = mate.gate
        } else {
            current = null
        }
    }
    return outList
}

function buildChains(trackElements, elementConeGroups) {
    var visited = []
    var chains = []

    for (var i = 0; i < trackElements.length; i++) {
        var element = trackElements[i]
        if (visited.indexOf(element) !== -1) continue

        var hasA = element.gateAMate !== null
        var hasB = element.gateBMate !== null
        if (hasA && hasB) continue

        var startGate = hasA ? "B" : "A"
        var chainCones = walkChain(element, startGate, visited, elementConeGroups)
        if (chainCones.length > 0) chains.push(chainCones)
    }

    for (var k = 0; k < trackElements.length; k++) {
        var el2 = trackElements[k]
        if (visited.indexOf(el2) !== -1) continue
        var loopCones = walkChain(el2, "A", visited, elementConeGroups)
        if (loopCones.length > 0) chains.push(loopCones)
    }

    return chains
}

function stitchChains(chains) {
    if (chains.length === 0) return []

    var remaining = chains.slice()
    var first = remaining.shift()
    var ordered = first.slice()
    var currentEnd = ordered[ordered.length - 1]

    while (remaining.length > 0) {
        var bestIdx = -1
        var bestReversed = false
        var bestDist = Infinity

        for (var i = 0; i < remaining.length; i++) {
            var chain = remaining[i]
            var dStart = distance(currentEnd, chain[0])
            var dEnd = distance(currentEnd, chain[chain.length - 1])

            if (dStart < bestDist) { bestDist = dStart; bestIdx = i; bestReversed = false }
            if (dEnd < bestDist) { bestDist = dEnd; bestIdx = i; bestReversed = true }
        }

        var chosen = remaining[bestIdx]
        remaining.splice(bestIdx, 1)
        var toAppend = bestReversed ? chosen.slice().reverse() : chosen

        ordered = ordered.concat(toAppend)
        currentEnd = ordered[ordered.length - 1]
    }

    return ordered
}

// ---- Straight.qml getConePlacements ----

function straightCones(el, pixelsPerFoot) {
    var minSpacingFt = 8 * 3.28084
    var maxSpacingFt = 10 * 3.28084

    return straightConeSegment(
        -el.length / 2, 0, 0, el.length,
        el.trackWidth / 2, pixelsPerFoot, minSpacingFt, maxSpacingFt
    )
}

// ---- Slalom.qml getConePlacements (width is Slalom.qml's totalLength) ----

function slalomCones(el, pixelsPerFoot) {
    var width = el.leadInLength + (el.numSlaloms + 1) * el.slalomOffset + el.leadOutLength
    var leadMinSpacingFt = 8 * 3.28084
    var leadMaxSpacingFt = 10 * 3.28084

    var leaningOffsetFt = (10.5 / 2 + 18 / 2) / 12
    var leaningOffsetPx = leaningOffsetFt * pixelsPerFoot
    var halfWidth = el.trackWidth / 2

    var cones = []

    cones = cones.concat(straightConeSegment(
        -width / 2, 0, 0, el.leadInLength,
        halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
    ))

    var sign = (el.initialDirection === "left") ? -1 : 1
    for (var i = 0; i < el.numSlaloms; i++) {
        var apexX = el.leadInLength + (i + 1) * el.slalomOffset - width / 2
        var apexY = sign * el.apexOffset
        var leanY = apexY + sign * leaningOffsetPx

        cones.push({ x: apexX, y: apexY, heading: 0, coneType: "standing" })

        var headingDeg = Math.atan2(-sign, 0) * 180 / Math.PI
        cones.push({ x: apexX, y: leanY, heading: headingDeg, coneType: "leaning" })

        sign = -sign
    }

    var slalomEndLocalX = el.leadInLength + (el.numSlaloms + 1) * el.slalomOffset - width / 2
    cones = cones.concat(straightConeSegment(
        slalomEndLocalX, 0, 0, el.leadOutLength,
        halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
    ))

    return cones
}

// ---- Chicane.qml getConePlacements (width, height, bendRight, drawEntry, drawExit are Chicane.qml's bindings) ----

function chicaneCones(el, pixelsPerFoot) {
    var width = el.leadInLength + el.leadWidthOffset + el.leadOutLength
    var height = el.leadHeightOffset + el.trackWidth
    var bendRight = el.turnDirection !== "left"
    var drawEntry = { x: 0, y: bendRight ? el.trackWidth / 2 : (el.leadHeightOffset + el.trackWidth / 2) }
    var drawExit = { x: width, y: bendRight ? (el.leadHeightOffset + el.trackWidth / 2) : el.trackWidth / 2 }

    var leadMinSpacingFt = 8 * 3.28084
    var leadMaxSpacingFt = 10 * 3.28084
    var leaningMinSpacingFt = 3
    var leaningMaxSpacingFt = 6
    var halfWidth = el.trackWidth / 2

    var cones = []

    cones = cones.concat(straightConeSegment(
        0 - width / 2, drawEntry.y - height / 2, 0, el.leadInLength,
        halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
    ))

    var p0 = { x: el.leadInLength, y: drawEntry.y }
    var c1 = { x: el.leadInLength + el.leadWidthOffset / 2, y: drawEntry.y }
    var c2 = { x: el.leadInLength + el.leadWidthOffset / 2, y: drawExit.y }
    var p3 = { x: el.leadInLength + el.leadWidthOffset, y: drawExit.y }

    function bezierPoint(t) {
        var mt = 1 - t
        return {
            x: mt*mt*mt*p0.x + 3*mt*mt*t*c1.x + 3*mt*t*t*c2.x + t*t*t*p3.x,
            y: mt*mt*mt*p0.y + 3*mt*mt*t*c1.y + 3*mt*t*t*c2.y + t*t*t*p3.y
        }
    }

    function bezierTangentDeg(t) {
        var mt = 1 - t
        var dx = 3*mt*mt*(c1.x-p0.x) + 6*mt*t*(c2.x-c1.x) + 3*t*t*(p3.x-c2.x)
        var dy = 3*mt*mt*(c1.y-p0.y) + 6*mt*t*(c2.y-c1.y) + 3*t*t*(p3.y-c2.y)
        return Math.atan2(dy, dx) * 180 / Math.PI
    }

    var sampleCount = 60
    var curvePoints = []
    for (var i = 0; i <= sampleCount; i++) {
        var t = i / sampleCount
        var pt = bezierPoint(t)
        curvePoints.push({
            x: pt.x - width / 2,
            y: pt.y - height / 2,
            heading: bezierTangentDeg(t)
        })
    }

    var interior = sampleInteriorByArcLength(curvePoints, leaningMinSpacingFt, leaningMaxSpacingFt, pixelsPerFoot)
    var bendSign = bendRight ? -1 : 1

    for (var j = 0; j < interior.length; j++) {
        var p = interior[j]
        var side = (p.arcFraction < 0.5) ? bendSign : -bendSign

        var headingRad = p.heading * Math.PI / 180
        var outsideAngleRad = headingRad + (90 * side) * Math.PI / 180

        var coneX = p.x + Math.cos(outsideAngleRad) * halfWidth
        var coneY = p.y + Math.sin(outsideAngleRad) * halfWidth
        var coneHeadingDeg = p.heading

        cones.push({ x: coneX, y: coneY, heading: coneHeadingDeg, coneType: "leaning" })
    }

    cones = cones.concat(straightConeSegment(
        el.leadInLength + el.leadWidthOffset - width / 2, drawExit.y - height / 2, 0, el.leadOutLength,
        halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
    ))

    return cones
}

// ---- Hairpin.qml rebuildPath (the parts getConePlacements reads), radiusAtTheta and getConePlacements ----

function radiusAtTheta(el, thetaDeg) {
    if (el.radiusType === "constant" || el.degreesOfTurn === 0) return el.primaryRadius
    var t = thetaDeg / el.degreesOfTurn
    return el.primaryRadius + (el.secondaryRadius - el.primaryRadius) * t
}

function hairpinShape(el) {
    var samplesPerDegree = 3
    var pts = []
    var x = 0
    var y = 0
    var heading = 0

    pts.push({ x: x, y: y })

    x += el.leadInLength
    pts.push({ x: x, y: y })

    var turnSign = el.turnDirection === "right" ? 1 : -1
    var steps = Math.max(6, Math.round(Math.abs(el.degreesOfTurn) * samplesPerDegree))
    var dThetaDeg = el.degreesOfTurn / steps

    for (var i = 0; i < steps; i++) {
        var thetaMid = (i + 0.5) * dThetaDeg
        var r = radiusAtTheta(el, thetaMid)
        var dThetaRad = dThetaDeg * Math.PI / 180
        var ds = r * dThetaRad
        var headingRad = heading * Math.PI / 180

        x += ds * Math.cos(headingRad)
        y += ds * Math.sin(headingRad)
        heading += turnSign * dThetaDeg

        pts.push({ x: x, y: y })
    }

    var headingRad2 = heading * Math.PI / 180
    x += el.leadOutLength * Math.cos(headingRad2)
    y += el.leadOutLength * Math.sin(headingRad2)
    pts.push({ x: x, y: y })

    var minX = pts[0].x, maxX = pts[0].x
    var minY = pts[0].y, maxY = pts[0].y

    for (var p = 0; p < pts.length; p++) {
        minX = Math.min(minX, pts[p].x)
        maxX = Math.max(maxX, pts[p].x)
        minY = Math.min(minY, pts[p].y)
        maxY = Math.max(maxY, pts[p].y)
    }

    var pad = el.trackWidth / 2
    minX -= pad; maxX += pad
    minY -= pad; maxY += pad

    var width = maxX - minX
    var height = maxY - minY

    var normalized = []
    for (var q = 0; q < pts.length; q++) {
        normalized.push({ x: pts[q].x - minX, y: pts[q].y - minY })
    }

    var entryPoint = normalized[0]
    var exitPoint = normalized[normalized.length - 1]

    return {
        width: width,
        height: height,
        pathStartPoint: normalized[0],
        gateA: { x: entryPoint.x - width / 2, y: entryPoint.y - height / 2 },
        gateB: { x: exitPoint.x - width / 2, y: exitPoint.y - height / 2 }
    }
}

function hairpinCones(el, pixelsPerFoot) {
    if (el.degreesOfTurn > 180) return []
    var shape = hairpinShape(el)
    var samplesPerDegree = 3

    var leadMinSpacingFt = 8 * 3.28084
    var leadMaxSpacingFt = 10 * 3.28084
    var turnMinSpacingFt = 5
    var turnMaxSpacingFt = 8
    var halfWidth = el.trackWidth / 2

    var cones = []

    cones = cones.concat(straightConeSegment(
        shape.gateA.x, shape.gateA.y, 0, el.leadInLength,
        halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
    ))

    var turnPoints = []
    var x = el.leadInLength
    var y = 0
    var heading = 0
    turnPoints.push({ x: x, y: y, heading: heading })

    var turnSign = el.turnDirection === "right" ? 1 : -1
    var steps = Math.max(6, Math.round(Math.abs(el.degreesOfTurn) * samplesPerDegree))
    var dThetaDeg = el.degreesOfTurn / steps

    for (var i = 0; i < steps; i++) {
        var thetaMid = (i + 0.5) * dThetaDeg
        var r = radiusAtTheta(el, thetaMid)
        var dThetaRad = dThetaDeg * Math.PI / 180
        var ds = r * dThetaRad
        var headingRad = heading * Math.PI / 180

        x += ds * Math.cos(headingRad)
        y += ds * Math.sin(headingRad)
        heading += turnSign * dThetaDeg

        turnPoints.push({ x: x, y: y, heading: heading })
    }

    var relPoints = turnPoints.map(function(p) {
        return {
            x: p.x + shape.pathStartPoint.x - shape.width / 2,
            y: p.y + shape.pathStartPoint.y - shape.height / 2,
            heading: p.heading
        }
    })

    var interior = sampleInteriorByArcLength(relPoints, turnMinSpacingFt, turnMaxSpacingFt, pixelsPerFoot)

    for (var j = 0; j < interior.length; j++) {
        var pt = interior[j]
        var headingRad2 = pt.heading * Math.PI / 180
        var insideAngleRad = headingRad2 - (-90 * turnSign) * Math.PI / 180

        var coneX = pt.x + Math.cos(insideAngleRad) * halfWidth
        var coneY = pt.y + Math.sin(insideAngleRad) * halfWidth
        var coneHeadingDeg = pt.heading

        cones.push({ x: coneX, y: coneY, heading: coneHeadingDeg, coneType: "leaning" })
    }

    var lastRel = relPoints[relPoints.length - 1]
    var lastRaw = turnPoints[turnPoints.length - 1]
    var exitHeadingRad = lastRaw.heading * Math.PI / 180

    cones = cones.concat(straightConeSegment(
        lastRel.x, lastRel.y, exitHeadingRad, el.leadOutLength,
        halfWidth, pixelsPerFoot, leadMinSpacingFt, leadMaxSpacingFt
    ))

    return cones
}

function getConePlacements(el, pixelsPerFoot) {
    switch (el.shapeName) {
    case "Straight": return straightCones(el, pixelsPerFoot)
    case "Slalom": return slalomCones(el, pixelsPerFoot)
    case "Chicane": return chicaneCones(el, pixelsPerFoot)
    case "Hairpin": return hairpinCones(el, pixelsPerFoot)
    }
    return []
}

// ---- PostProcessor.qml run(), from "Step 1" on; targets are { xPos, yPos } in pixels ----

export function run(trackElements, pixelsPerFoot, targetA, targetB) {
    var originX = targetA.xPos
    var originY = targetA.yPos
    var axisDx = targetB.xPos - originX
    var axisDy = targetB.yPos - originY
    var frameRotationRad = Math.atan2(axisDy, axisDx)

    var elementConeGroups = []
    for (var i = 0; i < trackElements.length; i++) {
        var element = trackElements[i]
        var localCones = getConePlacements(element, pixelsPerFoot)
        var globalCones = []

        var elementRotRad = element.elementRotation * Math.PI / 180
        var cosE = Math.cos(elementRotRad)
        var sinE = Math.sin(elementRotRad)

        for (var j = 0; j < localCones.length; j++) {
            var local = localCones[j]
            globalCones.push({
                x: element.xPos + (local.x * cosE - local.y * sinE),
                y: element.yPos + (local.x * sinE + local.y * cosE),
                heading: element.elementRotation + local.heading,
                coneType: local.coneType
            })
        }

        elementConeGroups.push({ element: element, cones: globalCones })
    }

    var epsilonFt = .4
    dedupeElementCones(elementConeGroups, epsilonFt * pixelsPerFoot)

    var chains = buildChains(trackElements, elementConeGroups)
    var orderedGlobalCones = stitchChains(chains)

    var cones = []
    for (var k = 0; k < orderedGlobalCones.length; k++) {
        var gc = orderedGlobalCones[k]
        var dx = gc.x - originX
        var dy = gc.y - originY

        var cosF = Math.cos(-frameRotationRad)
        var sinF = Math.sin(-frameRotationRad)

        var frameX = (dx * cosF - dy * sinF) / pixelsPerFoot
        var frameY = (dx * sinF + dy * cosF) / pixelsPerFoot
        var frameHeadingDeg = gc.heading - (frameRotationRad * 180 / Math.PI)

        cones.push({ index: k, coneType: gc.coneType, x: frameX, y: frameY, heading: frameHeadingDeg })
    }
    return cones
}
```

- [ ] **Step 2: Write the sample track** — `app/tests/qml/fixtures/sampletrack.mjs`

```js
// The port check's sample track: every element type, joins (one entered backwards at its exit), a changing-radius
// turn, a left turn and two free elements to stitch, on an angled Origin -> Direction axis. Built with the new
// commands, then converted to the prototype's pixel elements for tests/qml/fixtures/prototype.mjs.
import * as Commands from "../../../qml/logic/commands.mjs"
import { FOOT } from "../../../qml/logic/units.mjs"

export function track() {
    const steps = [
        ["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 }],      // 0.1 m per pixel
        ["setTarget", { which: "origin", point: { x: 200, y: 600 } }],
        ["setTarget", { which: "direction", point: { x: 900, y: 300 } }],
        ["add", { type: "straight", x: 30, y: 40 }],                                                        // e1
        ["add", { type: "slalom", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } }],                 // e2
        ["add", { type: "turn", x: 0, y: 0, props: { radiusType: "changing", exitRadius: 10 },
                  snap: { ownEnd: "A", id: "e2", end: "B" } }],                                              // e3
        ["add", { type: "chicane", x: 0, y: 0, snap: { ownEnd: "B", id: "e3", end: "B" } }],                // e4, backwards
        ["add", { type: "straight", x: 20, y: 70, rotation: 30, props: { length: 15 } }],                   // e5, alone
        ["add", { type: "turn", x: 90, y: 15, rotation: -20, props: { direction: "left", angle: 90, radius: 9 } }]  // e6
    ]
    const stack = new Commands.UndoStack()
    let t = Commands.emptyTrack()
    for (const [name, args] of steps)
        t = Commands.run(stack, t, name, args)
    return t
}

const SHAPE_NAMES = { straight: "Straight", slalom: "Slalom", chicane: "Chicane", turn: "Hairpin" }

// The same elements as the prototype held them: pixels, its property names, mates as { element, gate }.
export function prototypeElements(track) {
    const k = 1 / track.photo.metresPerPixel
    const list = track.elements.map(el => {
        const p = el.props
        const base = { shapeName: SHAPE_NAMES[el.type], xPos: el.x * k, yPos: el.y * k, elementRotation: el.rotation,
                       gateAMate: null, gateBMate: null }
        switch (el.type) {
        case "straight":
            return Object.assign(base, { length: p.length * k, trackWidth: p.trackWidth * k })
        case "slalom":
            return Object.assign(base, { leadInLength: p.leadIn * k, leadOutLength: p.leadOut * k,
                                         numSlaloms: p.coneCount, initialDirection: p.firstTurn,
                                         apexOffset: p.weaveOffset * k, slalomOffset: p.coneSpacing * k,
                                         trackWidth: p.trackWidth * k })
        case "chicane":
            return Object.assign(base, { leadInLength: p.leadIn * k, leadOutLength: p.leadOut * k,
                                         leadWidthOffset: p.shiftLength * k, leadHeightOffset: p.shift * k,
                                         trackWidth: p.trackWidth * k, turnDirection: p.direction })
        case "turn":
            return Object.assign(base, { radiusType: p.radiusType, leadInLength: p.leadIn * k,
                                         leadOutLength: p.leadOut * k, primaryRadius: p.radius * k,
                                         secondaryRadius: p.exitRadius * k, degreesOfTurn: p.angle,
                                         turnDirection: p.direction, trackWidth: p.trackWidth * k })
        }
        return base
    })
    track.elements.forEach((el, i) => {
        for (const end of ["A", "B"]) {
            const mate = el.joins[end]
            if (mate)
                list[i]["gate" + end + "Mate"] = { element: list[track.elements.findIndex(e => e.id === mate.id)],
                                                   gate: mate.end }
        }
    })
    return list
}

export function pixelsPerFoot(track) {
    return FOOT / track.photo.metresPerPixel
}

export function prototypeTarget(point) {
    return { xPos: point.x, yPos: point.y }
}
```

- [ ] **Step 3: Write the port check** — `app/tests/qml/tst_portcheck.qml`

```qml
import QtQuick
import QtTest
import "../../qml/logic/postprocess.mjs" as Post
import "../../qml/logic/units.mjs" as Units
import "fixtures/prototype.mjs" as Prototype
import "fixtures/sampletrack.mjs" as Sample

// The spec's port check: the sample track through the prototype's cone code and through the new code gives the same
// cones, once the prototype's feet become metres, its y (to the right) is flipped to the left, and its clockwise
// headings become counter-clockwise.
TestCase {
    name: "PortCheck"

    function angleGap(a, b) {
        let d = (a - b) % 360
        if (d > 180) d -= 360
        if (d < -180) d += 360
        return Math.abs(d)
    }

    function test_theSampleTrackCoversWhatMatters() {
        const t = Sample.track()
        compare(t.elements.length, 6)
        compare(t.elements[3].joins.B.id, "e3")         // the chicane is entered at its exit
        compare(t.elements[4].joins.A, null)            // the lone straight
    }

    function test_conesMatchThePrototype() {
        const t = Sample.track()
        const ours = Post.run(t)
        verify(!ours.error, ours.error ? ours.error.message : "")
        const theirs = Prototype.run(Sample.prototypeElements(t), Sample.pixelsPerFoot(t),
                                     Sample.prototypeTarget(t.targets.origin), Sample.prototypeTarget(t.targets.direction))
        compare(ours.cones.length, theirs.length)
        verify(theirs.length > 60, "a real sample: " + theirs.length + " cones")
        for (let i = 0; i < theirs.length; i++) {
            const a = ours.cones[i]
            const b = theirs[i]
            const where = "cone " + i
            compare(a.type, b.coneType, where)
            verify(Math.abs(a.x - b.x * Units.FOOT) < 1e-6, where + " x " + a.x + " vs " + b.x * Units.FOOT)
            verify(Math.abs(a.y + b.y * Units.FOOT) < 1e-6, where + " y " + a.y + " vs " + (-b.y * Units.FOOT))
            verify(angleGap(a.heading, -b.heading) < 1e-6, where + " heading " + a.heading + " vs " + (-b.heading))
        }
    }
}
```

- [ ] **Step 4: Run it**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_portcheck.qml
```

Expected: both tests pass. If a cone differs, the port (Task 3 or Task 6) changed behaviour: compare that element type's code with its transcription line by line and fix the port, never the fixture. If only the count differs by one pair at a straight's boundary, print `length / maxSpacing` for that row on both sides; a quotient within 1e-12 of a whole number is a rounding tie, and the sample element's length should then be nudged by 0.01 m in `sampletrack.mjs` (record why in a comment).

- [ ] **Step 5: Run every QML test and commit**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp
```

Expected: `qml: N passed, 0 failed`.

```bash
git add app/tests/qml/fixtures app/tests/qml/tst_portcheck.qml
git commit -m "Port check: the prototype's cone code kept as a fixture; the new cones match it after units and axes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: `viewport.mjs` — zoom and pan maths

**Files:**
- Create: `app/qml/logic/viewport.mjs`
- Test: `app/tests/qml/tst_viewport.qml`

**Interfaces:**
- Produces: `CONE_METRES` (10.5 in); `fit(viewW, viewH, contentW, contentH) -> {zoom, panX, panY}`; `limits(fitZoom, metresPerPixel) -> {min, max}`; `zoomAt(view, factor, sx, sy, min, max) -> view`; `toWorld(view, sx, sy)`; `toScreen(view, wx, wy)`. A view is `{zoom, panX, panY}`: screen = pan + zoom × world, world in photo pixels.

- [ ] **Step 1: Write the failing test** — `app/tests/qml/tst_viewport.qml`

```qml
import QtQuick
import QtTest
import "../../qml/logic/viewport.mjs" as Viewport

TestCase {
    name: "Viewport"

    function test_fitCentresTheWholePhoto() {
        const v = Viewport.fit(1000, 500, 1280, 720)
        fuzzyCompare(v.zoom, 500 / 720 * 0.95, 1e-12)
        const centre = Viewport.toScreen(v, 640, 360)
        fuzzyCompare(centre.x, 500, 1e-9)
        fuzzyCompare(centre.y, 250, 1e-9)
        const corner = Viewport.toScreen(v, 1280, 720)
        verify(corner.x <= 1000 && corner.y <= 500)
    }

    function test_fitWithNothingToFit() {
        compare(JSON.stringify(Viewport.fit(0, 500, 1280, 720)), JSON.stringify({ zoom: 1, panX: 0, panY: 0 }))
    }

    function test_zoomKeepsThePointUnderTheCursor() {
        const v0 = { zoom: 1.3, panX: -40, panY: 25 }
        const under = Viewport.toWorld(v0, 300, 200)
        const v1 = Viewport.zoomAt(v0, 1.7, 300, 200, 0.1, 50)
        fuzzyCompare(v1.zoom, 1.3 * 1.7, 1e-12)
        const after = Viewport.toScreen(v1, under.x, under.y)
        fuzzyCompare(after.x, 300, 1e-9)
        fuzzyCompare(after.y, 200, 1e-9)
    }

    function test_zoomStaysWithinItsLimits() {
        compare(Viewport.zoomAt({ zoom: 1, panX: 0, panY: 0 }, 100, 0, 0, 0.1, 10).zoom, 10)
        compare(Viewport.zoomAt({ zoom: 1, panX: 0, panY: 0 }, 0.001, 0, 0, 0.1, 10).zoom, 0.1)
    }

    function test_screenAndWorldAreInverses() {
        const v = { zoom: 2.5, panX: 13, panY: -7 }
        const w = Viewport.toWorld(v, 101, 57)
        const s = Viewport.toScreen(v, w.x, w.y)
        fuzzyCompare(s.x, 101, 1e-9)
        fuzzyCompare(s.y, 57, 1e-9)
    }

    function test_limitsReachFromTheWholePhotoToSingleCones() {
        const l = Viewport.limits(0.5, 0.1)
        compare(l.min, 0.25)
        fuzzyCompare(l.max, 80 * 0.1 / Viewport.CONE_METRES, 1e-9)
        const noScale = Viewport.limits(0.5, 0)
        compare(noScale.max, 16)
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_viewport.qml
```

Expected: FAIL (`viewport.mjs` missing).

- [ ] **Step 3: Write `app/qml/logic/viewport.mjs`**

```js
// Zoom and pan for the canvas. World coordinates are photo pixels; a view { zoom, panX, panY } puts a world point
// at screen = pan + zoom × world. The window's size never changes the zoom, only how much is visible.
// Tests: tests/qml/tst_viewport.qml.

export const CONE_METRES = 10.5 * 0.0254

// The whole photo, centred, with a small margin.
export function fit(viewW, viewH, contentW, contentH) {
    if (!(viewW > 0 && viewH > 0 && contentW > 0 && contentH > 0))
        return { zoom: 1, panX: 0, panY: 0 }
    const zoom = Math.min(viewW / contentW, viewH / contentH) * 0.95
    return { zoom: zoom, panX: (viewW - contentW * zoom) / 2, panY: (viewH - contentH * zoom) / 2 }
}

// From half the whole-photo zoom out, down to one cone about 80 screen pixels across (16× before the ruler is set).
export function limits(fitZoom, metresPerPixel) {
    const min = fitZoom * 0.5
    const max = metresPerPixel > 0 ? Math.max(min, 80 * metresPerPixel / CONE_METRES) : Math.max(min, 16)
    return { min: min, max: max }
}

// Zooms by `factor` about the screen point (sx, sy), which keeps the same world point under it.
export function zoomAt(view, factor, sx, sy, min, max) {
    const zoom = Math.min(max, Math.max(min, view.zoom * factor))
    const k = zoom / view.zoom
    return { zoom: zoom, panX: sx - (sx - view.panX) * k, panY: sy - (sy - view.panY) * k }
}

export function toWorld(view, sx, sy) {
    return { x: (sx - view.panX) / view.zoom, y: (sy - view.panY) / view.zoom }
}

export function toScreen(view, wx, wy) {
    return { x: view.panX + wx * view.zoom, y: view.panY + wy * view.zoom }
}
```

- [ ] **Step 4: Run it and watch it pass**

```powershell
powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_viewport.qml
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add app/qml/logic/viewport.mjs app/tests/qml/tst_viewport.qml
git commit -m "Viewport: fit, zoom about the cursor within limits, screen and world points" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: C++ services — `Settings` and `FileIO`

**Files:**
- Create: `app/services/Settings.h`, `app/services/Settings.cpp`, `app/services/FileIO.h`, `app/services/FileIO.cpp`
- Modify: `app/CMakeLists.txt` (SOURCES), `app/tests/CMakeLists.txt`
- Test: `app/tests/tst_settings.cpp`, `app/tests/tst_fileio.cpp`

**Interfaces:**
- Produces (QML singletons in module `Conestructor`):
  - `Settings { units: "ftin"|"ft"|"m"; signal saveFailed(string message) }` — `Conestructor.ini` under `%APPDATA%\Conestructor` (`QSettings(IniFormat, UserScope, "Conestructor", "Conestructor")`); C++ statics `Settings::unitChoices()`, `Settings::defaultUnits()`.
  - `FileIO { toLocalPath(url) -> string; writeConeExport(path, targetDistance, cones) -> "" | error sentence }`; C++ statics `FileIO::coneExportJson(targetDistance, cones) -> QByteArray`, `FileIO::axesText()`. Cones are `{index, type, x, y, heading}` maps; x and y rounded to the millimetre, headings to 0.01°, targetDistance to the millimetre.

- [ ] **Step 1: Write the failing tests**

`app/tests/tst_settings.cpp`:

```cpp
#include <QFile>
#include <QSettings>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include "services/Settings.h"

class TestSettings : public QObject
{
    Q_OBJECT

    QTemporaryDir dir;

    static QSettings ini()
    {
        return QSettings(QSettings::IniFormat, QSettings::UserScope, QStringLiteral("Conestructor"),
                         QStringLiteral("Conestructor"));
    }

private slots:
    void initTestCase()
    {
        // Before any Settings exists, so the owner's real ini is never read or written.
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, dir.path());
    }

    void init()
    {
        QSettings settings = ini();
        settings.clear();
        settings.sync();
    }

    void defaultsToFeetAndInches()
    {
        Settings s;
        QCOMPARE(s.units(), QStringLiteral("ftin"));
        QCOMPARE(Settings::unitChoices(), QStringList({ "ftin", "ft", "m" }));
    }

    void unitsSurviveARestart()
    {
        {
            Settings s;
            QSignalSpy changed(&s, &Settings::unitsChanged);
            s.setUnits(QStringLiteral("m"));
            QCOMPARE(changed.count(), 1);
        }
        Settings again;
        QCOMPARE(again.units(), QStringLiteral("m"));
        QCOMPARE(ini().value("units").toString(), QStringLiteral("m"));
    }

    void theFileIsConestructorIni()
    {
        Settings s;
        s.setUnits(QStringLiteral("ft"));
        QVERIFY(QFile::exists(dir.path() + QStringLiteral("/Conestructor/Conestructor.ini")));
    }

    void unknownUnitsAreIgnored()
    {
        Settings s;
        QSignalSpy changed(&s, &Settings::unitsChanged);
        s.setUnits(QStringLiteral("furlongs"));
        QCOMPARE(changed.count(), 0);
        QCOMPARE(s.units(), QStringLiteral("ftin"));
    }

    void settingTheSameUnitsSaysNothing()
    {
        Settings s;
        QSignalSpy changed(&s, &Settings::unitsChanged);
        s.setUnits(QStringLiteral("ftin"));
        QCOMPARE(changed.count(), 0);
    }

    void aBadValueInTheFileFallsBackToTheDefault()
    {
        {
            QSettings file = ini();
            file.setValue("units", "cubits");
            file.sync();
        }
        Settings s;
        QCOMPARE(s.units(), QStringLiteral("ftin"));
    }

    void aFailedSaveIsReportedAndTheValueKept()
    {
        // A file where the Conestructor folder should be, so the ini cannot be written.
        QTemporaryDir blocked;
        QFile blocker(blocked.path() + QStringLiteral("/Conestructor"));
        QVERIFY(blocker.open(QIODevice::WriteOnly));
        blocker.close();
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, blocked.path());

        Settings s;
        QSignalSpy failed(&s, &Settings::saveFailed);
        s.setUnits(QStringLiteral("m"));
        QCOMPARE(failed.count(), 1);
        QVERIFY(!failed.first().first().toString().isEmpty());
        QCOMPARE(s.units(), QStringLiteral("m"));

        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, dir.path());
    }
};

QTEST_GUILESS_MAIN(TestSettings)
#include "tst_settings.moc"
```

`app/tests/tst_fileio.cpp`:

```cpp
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>

#include "services/FileIO.h"

class TestFileIO : public QObject
{
    Q_OBJECT

    QTemporaryDir dir;

private slots:
    void theExportHoldsMetresInTheExportFrame()
    {
        QVariantList cones;
        cones << QVariantMap{ { "index", 0 }, { "type", "standing" }, { "x", 1.23456 }, { "y", -4.0 }, { "heading", 90.123 } }
              << QVariantMap{ { "index", 1 }, { "type", "leaning" }, { "x", 2.0 }, { "y", -0.00001 }, { "heading", -45.0 } };
        const QString path = dir.filePath(QStringLiteral("cones.json"));

        FileIO io;
        QCOMPARE(io.writeConeExport(path, 41.2, cones), QString());

        QFile file(path);
        QVERIFY(file.open(QIODevice::ReadOnly));
        const QJsonObject doc = QJsonDocument::fromJson(file.readAll()).object();
        QCOMPARE(doc.value("units").toString(), QStringLiteral("m"));
        QCOMPARE(doc.value("axes").toString(),
                 QStringLiteral("x toward Direction target, y to the left, heading degrees counter-clockwise from +x"));
        QCOMPARE(doc.value("targetDistance").toDouble(), 41.2);
        const QJsonArray list = doc.value("cones").toArray();
        QCOMPARE(list.size(), 2);
        const QJsonObject first = list.at(0).toObject();
        QCOMPARE(first.value("index").toInt(), 0);
        QCOMPARE(first.value("type").toString(), QStringLiteral("standing"));
        QCOMPARE(first.value("x").toDouble(), 1.235);
        QCOMPARE(first.value("y").toDouble(), -4.0);
        QCOMPARE(first.value("heading").toDouble(), 90.12);
        const QJsonObject second = list.at(1).toObject();
        QCOMPARE(second.value("type").toString(), QStringLiteral("leaning"));
        QCOMPARE(second.value("y").toDouble(), 0.0);
        QVERIFY(!QJsonDocument(doc).toJson().contains("-0"));
    }

    void anUnwritablePathSaysWhy()
    {
        FileIO io;
        const QString message = io.writeConeExport(dir.filePath(QStringLiteral("missing/folder/cones.json")), 1.0, {});
        QVERIFY(!message.isEmpty());
        QVERIFY(message.contains(QStringLiteral("cones.json")));
    }

    void localPaths()
    {
        FileIO io;
        QCOMPARE(io.toLocalPath(QUrl::fromLocalFile(QStringLiteral("C:/lots/lot.png"))), QStringLiteral("C:/lots/lot.png"));
    }
};

QTEST_GUILESS_MAIN(TestFileIO)
#include "tst_fileio.moc"
```

Append to `app/tests/CMakeLists.txt`:

```cmake
conestructor_test(tst_settings SOURCES tst_settings.cpp LIBS conestructor_core)
conestructor_test(tst_fileio SOURCES tst_fileio.cpp LIBS conestructor_core)
```

- [ ] **Step 2: Build and watch it fail**

```powershell
powershell -NoProfile -File app\tests\build.ps1
```

Expected: FAIL to compile (`services/Settings.h` not found).

- [ ] **Step 3: Write `app/services/Settings.h` and `app/services/Settings.cpp`**

```cpp
#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// The owner's preferences, saved as Conestructor.ini under %APPDATA%\Conestructor (one file to find, read, back up or
// delete). Part 1 has one: the units lengths are shown and typed in. Files always hold metres whatever this says.
class Settings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString units READ units WRITE setUnits NOTIFY unitsChanged)

public:
    explicit Settings(QObject *parent = nullptr);

    QString units() const { return m_units; }
    // Ignores anything that is not one of unitChoices().
    void setUnits(const QString &units);

    static QStringList unitChoices();   // ftin (feet and inches), ft (decimal feet), m (metres)
    static QString defaultUnits();      // ftin

signals:
    void unitsChanged();
    // The ini could not be written; the value still applies for this session.
    void saveFailed(const QString &message);

private:
    void save();

    QString m_units;
};
```

```cpp
#include "Settings.h"

#include <QDir>
#include <QSettings>

namespace {

QSettings openIni()
{
    return QSettings(QSettings::IniFormat, QSettings::UserScope, QStringLiteral("Conestructor"),
                     QStringLiteral("Conestructor"));
}

} // namespace

Settings::Settings(QObject *parent) : QObject(parent), m_units(defaultUnits())
{
    QSettings ini = openIni();
    const QString stored = ini.value(QStringLiteral("units")).toString();
    if (unitChoices().contains(stored))
        m_units = stored;
}

QStringList Settings::unitChoices()
{
    return { QStringLiteral("ftin"), QStringLiteral("ft"), QStringLiteral("m") };
}

QString Settings::defaultUnits()
{
    return QStringLiteral("ftin");
}

void Settings::setUnits(const QString &units)
{
    if (!unitChoices().contains(units) || units == m_units)
        return;
    m_units = units;
    emit unitsChanged();
    save();
}

void Settings::save()
{
    QSettings ini = openIni();
    ini.setValue(QStringLiteral("units"), m_units);
    ini.sync();
    if (ini.status() != QSettings::NoError)
        emit saveFailed(tr("Could not save your preferences to %1. They apply until Conestructor closes.")
                            .arg(QDir::toNativeSeparators(ini.fileName())));
}
```

- [ ] **Step 4: Write `app/services/FileIO.h` and `app/services/FileIO.cpp`**

```cpp
#pragma once
#include <QByteArray>
#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Reading and writing files for QML. Part 1 writes the cone export; part 2 adds .cone files.
class FileIO : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit FileIO(QObject *parent = nullptr) : QObject(parent) {}

    // A file dialog's URL as a path to show or write to.
    Q_INVOKABLE QString toLocalPath(const QUrl &url) const;
    // Writes File > Export cones (JSON). Returns "" when written, otherwise a sentence saying what went wrong.
    // Cones are { index, type, x, y, heading } in the export frame, in metres and degrees.
    Q_INVOKABLE QString writeConeExport(const QString &path, double targetDistance, const QVariantList &cones) const;

    static QByteArray coneExportJson(double targetDistance, const QVariantList &cones);
    static QString axesText();
};
```

```cpp
#include "FileIO.h"

#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <cmath>

namespace {

// Rounded to `places` decimals; adding 0.0 turns -0 into 0 so the file never says "-0".
double rounded(double value, int places)
{
    const double factor = std::pow(10.0, places);
    return std::round(value * factor) / factor + 0.0;
}

} // namespace

QString FileIO::toLocalPath(const QUrl &url) const
{
    return url.isLocalFile() ? url.toLocalFile() : url.toString();
}

QString FileIO::axesText()
{
    return QStringLiteral("x toward Direction target, y to the left, heading degrees counter-clockwise from +x");
}

QByteArray FileIO::coneExportJson(double targetDistance, const QVariantList &cones)
{
    QJsonArray list;
    for (const QVariant &value : cones) {
        const QVariantMap cone = value.toMap();
        QJsonObject item;
        item.insert(QStringLiteral("index"), cone.value(QStringLiteral("index")).toInt());
        item.insert(QStringLiteral("type"), cone.value(QStringLiteral("type")).toString());
        item.insert(QStringLiteral("x"), rounded(cone.value(QStringLiteral("x")).toDouble(), 3));
        item.insert(QStringLiteral("y"), rounded(cone.value(QStringLiteral("y")).toDouble(), 3));
        item.insert(QStringLiteral("heading"), rounded(cone.value(QStringLiteral("heading")).toDouble(), 2));
        list.append(item);
    }
    QJsonObject document;
    document.insert(QStringLiteral("units"), QStringLiteral("m"));
    document.insert(QStringLiteral("axes"), axesText());
    document.insert(QStringLiteral("targetDistance"), rounded(targetDistance, 3));
    document.insert(QStringLiteral("cones"), list);
    return QJsonDocument(document).toJson(QJsonDocument::Indented);
}

QString FileIO::writeConeExport(const QString &path, double targetDistance, const QVariantList &cones) const
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return tr("Could not write %1: %2").arg(QDir::toNativeSeparators(path), file.errorString());
    file.write(coneExportJson(targetDistance, cones));
    if (!file.commit())
        return tr("Could not write %1: %2").arg(QDir::toNativeSeparators(path), file.errorString());
    return {};
}
```

In `app/CMakeLists.txt`, extend the module's `SOURCES`:

```cmake
    SOURCES
        services/AppInfo.h
        services/Settings.h services/Settings.cpp
        services/FileIO.h services/FileIO.cpp
```

- [ ] **Step 5: Build and run**

```powershell
powershell -NoProfile -File app\tests\build.ps1
powershell -NoProfile -File app\tests\run.ps1 -NoQml
```

Expected: `ctest: passed` (tst_qmlload, tst_settings, tst_fileio). If `aFailedSaveIsReportedAndTheValueKept` does not see a failure on this machine, make the ini itself read-only instead (create `Conestructor/Conestructor.ini` in the temporary folder and call `QFile::setPermissions(path, QFileDevice::ReadOwner)`), and keep the test's assertions.

- [ ] **Step 6: Commit**

```bash
git add app/services app/CMakeLists.txt app/tests/CMakeLists.txt app/tests/tst_settings.cpp app/tests/tst_fileio.cpp
git commit -m "Settings (units in Conestructor.ini) and FileIO (the JSON cone export in metres) as QML singletons" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: App shell — `TrackStore`, `CanvasView` with zoom and pan, menus, status bar, error banner

**Files:**
- Create: `app/qml/TrackStore.qml`, `app/qml/CanvasView.qml`, `app/qml/ElementView.qml`, `app/qml/StatusBar.qml`, `app/qml/ErrorBanner.qml`, `app/qml/logic/demo.mjs`
- Rewrite: `app/qml/Main.qml`
- Modify: `app/CMakeLists.txt` (QML files, singleton), `app/main.cpp` (demo affordance), `app/tests/tst_qmlload.cpp` (demo test)

**Interfaces:**
- Consumes: every logic module; `AppInfo`, `Settings`.
- Produces:
  - `TrackStore` (QML singleton): properties `track`, `mpp` (metres per photo pixel), `elementCount`, `frame`, `selectedId` ("" | element id | "ruler" | "origin" | "direction"), `selectedElement`, `message`, `previewOn`, `preview` (a `Post.run` result), `showCones`, `showRoute`, `canUndo`, `canRedo`, `undoLabel`, `redoLabel`; functions `run(name, args)`, `undo()`, `redo()`, `seal()`, `loadTrack(track)`, `newGestureKey()`, `exists(id)`, `element(id)`, `select(id)`, `selectLast()`, `deleteSelected()`, `duplicateSelected()`, `report(message, target)`, `processed() -> result | null`, `placeCones()`, `clearPreview()`; signals `problem(message, target)`, `problemsCleared()`.
  - `CanvasView`: properties `zoom`, `panX`, `panY`, `view`, `mpp`, `hover` (photo pixel under the cursor or null), `fitPending`; functions `toWorld(sx, sy)`, `toScreen(wx, wy)`, `fitToPhoto()`, `zoomBy(factor, sx, sy)`, `centreOn(wx, wy)`, `showTarget(target)`. Later tasks add placing and gestures.
  - `ElementView { element; zoom; selected; dimmed }`.
  - `ErrorBanner { show(message, target); hide(); signal showMe(target) }`; `StatusBar { canvas }`.
  - `Main`: functions `newTrack()`, `loadDemo(withCones)`, `conesPlaced() -> int`, `setBackground(path)`; ids `canvasView` (not `canvas`, which would read as the `canvas` property inside `StatusBar { canvas: … }`), `banner`, `sideColumn`, `photoDialog`, `viewMenu`, `editMenu`, `fileMenu`.
  - `Demo.demoTrack()`: ruler at 0.1 m per pixel on the blueprint (128 m × 72 m), both targets, Straight → Slalom → Turn → Chicane joined.

- [ ] **Step 1: Write `app/qml/logic/demo.mjs`**

```js
// An example track on the blueprint (1280 × 720 pixels; 128 m × 72 m at the ruler's 0.1 m per pixel), for
// screenshots (CONESTRUCTOR_DEMO) and the QML smoke test: every element type, joined end to end.
import * as Commands from "./commands.mjs"

export function demoTrack() {
    const steps = [
        ["setRuler", { a: { x: 140, y: 660 }, b: { x: 340, y: 660 }, realLength: 20 }],
        ["setTarget", { which: "origin", point: { x: 150, y: 560 } }],
        ["setTarget", { which: "direction", point: { x: 1150, y: 560 } }],
        ["add", { type: "straight", x: 30, y: 30 }],
        ["add", { type: "slalom", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } }],
        ["add", { type: "turn", x: 0, y: 0, snap: { ownEnd: "A", id: "e2", end: "B" } }],
        ["add", { type: "chicane", x: 0, y: 0, snap: { ownEnd: "A", id: "e3", end: "B" } }]
    ]
    const stack = new Commands.UndoStack()
    let track = Commands.emptyTrack()
    for (const [name, args] of steps)
        track = Commands.run(stack, track, name, args)
    return track
}
```

- [ ] **Step 2: Write `app/qml/TrackStore.qml`**

```qml
pragma Singleton
import QtQuick
import "logic/commands.mjs" as Commands
import "logic/frame.mjs" as Frame
import "logic/postprocess.mjs" as Post

// The track being edited and every change to it. The track is plain data (see logic/commands.mjs); every edit runs
// as a command through the undo stack, and the canvas and panels draw from `track`. Nothing drawn keeps a copy.
QtObject {
    id: store

    property var track: Commands.emptyTrack()
    readonly property real mpp: track.photo.metresPerPixel
    readonly property int elementCount: track.elements.length
    readonly property var frame: Frame.makeFrame(track.targets.origin, track.targets.direction, mpp)

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
```

- [ ] **Step 3: Write `app/qml/ElementView.qml`**

```qml
import QtQuick
import QtQuick.Shapes
import Conestructor
import "logic/elements.mjs" as Elements

// One track element drawn from data, in photo pixels: a translucent band in its colour as wide as the track, a
// dashed centreline, a ring at each open end and a green dot at each joined end. Selected: a white outline and the
// rotate handle. Draws only; CanvasView handles every click and drag.
Item {
    id: view

    property var element: null
    property real zoom: 1
    property bool selected: false
    property bool dimmed: false

    readonly property real mpp: TrackStore.mpp
    readonly property bool drawable: element !== null && mpp > 0
    readonly property color colour: element ? Elements.COLOURS[element.type] : "white"
    readonly property var points: drawable ? Elements.pathWorld(element).map(p => Qt.point(p.x / mpp, p.y / mpp)) : []
    readonly property var ends: drawable ? Elements.endsWorld(element) : null
    readonly property real bandWidth: drawable ? element.props.trackWidth / mpp : 0
    readonly property var handle: drawable && selected ? Elements.rotateHandle(element, 24 / zoom * mpp) : null

    visible: drawable
    opacity: dimmed ? 0.3 : 1

    Shape {
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: view.selected ? "#ffffff" : "transparent"
            strokeWidth: view.bandWidth + 4 / view.zoom
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: view.points }
        }
        ShapePath {
            strokeColor: Qt.rgba(view.colour.r, view.colour.g, view.colour.b, 0.45)
            strokeWidth: view.bandWidth
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: view.points }
        }
        ShapePath {
            strokeColor: view.colour
            strokeWidth: 1.5 / view.zoom
            strokeStyle: ShapePath.DashLine
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
    }

    Repeater {
        model: view.drawable ? 2 : 0
        Rectangle {
            required property int index
            readonly property string end: index === 0 ? "A" : "B"
            readonly property bool joined: view.element.joins[end] !== null
            readonly property var at: view.ends[end]
            width: (joined ? 8 : 10) / view.zoom
            height: width
            radius: width / 2
            x: at.x / view.mpp - width / 2
            y: at.y / view.mpp - height / 2
            color: joined ? "#4caf50" : "transparent"
            border.color: joined ? "#4caf50" : "#ffffff"
            border.width: 1.5 / view.zoom
        }
    }

    Rectangle {
        visible: view.handle !== null
        width: 12 / view.zoom
        height: width
        radius: width / 2
        x: view.handle ? view.handle.x / view.mpp - width / 2 : 0
        y: view.handle ? view.handle.y / view.mpp - height / 2 : 0
        color: "#ffffff"
        border.color: "#202020"
        border.width: 1 / view.zoom
    }
}
```

- [ ] **Step 4: Write `app/qml/CanvasView.qml`**

```qml
import QtQuick
import QtQuick.Controls
import Conestructor
import "logic/viewport.mjs" as Viewport

// The canvas: the lot photo with the track over it, under one zoom and pan. World coordinates are photo pixels;
// elements are stored in metres and drawn at metres ÷ metresPerPixel. All pointer input is handled here in one
// place, so redrawing an element never interrupts a drag. Window size changes what is visible, never the scale.
Item {
    id: canvas
    clip: true
    focus: true

    property real zoom: 1
    property real panX: 0
    property real panY: 0
    readonly property var view: ({ zoom: canvas.zoom, panX: canvas.panX, panY: canvas.panY })
    readonly property real mpp: TrackStore.mpp
    readonly property string blueprint: "qrc:/qt/qml/Conestructor/assets/images/blueprintBackground.png"
    readonly property string photoPath: TrackStore.track.photo.path
    property bool fitPending: true
    property bool spaceHeld: false
    property var hover: null          // the photo pixel under the cursor, or null

    property string mode: ""          // the gesture in progress: "pan" (later tasks add more)
    property var press: null          // where the gesture started and what it started on
    property string gestureKey: ""

    onPhotoPathChanged: fitPending = true
    onWidthChanged: tryFit()
    onHeightChanged: tryFit()

    function toWorld(sx, sy) { return Viewport.toWorld(view, sx, sy) }
    function toScreen(wx, wy) { return Viewport.toScreen(view, wx, wy) }

    function fitToPhoto() {
        const v = Viewport.fit(width, height, photo.implicitWidth, photo.implicitHeight)
        zoom = v.zoom
        panX = v.panX
        panY = v.panY
    }

    function tryFit() {
        if (fitPending && photo.status === Image.Ready && width > 0 && height > 0) {
            fitPending = false
            fitToPhoto()
        }
    }

    function zoomBy(factor, sx, sy) {
        const l = Viewport.limits(Viewport.fit(width, height, photo.implicitWidth, photo.implicitHeight).zoom, mpp)
        const v = Viewport.zoomAt(view, factor, sx, sy, l.min, l.max)
        zoom = v.zoom
        panX = v.panX
        panY = v.panY
    }

    function centreOn(wx, wy) {
        panX = width / 2 - wx * zoom
        panY = height / 2 - wy * zoom
    }

    // "Show me" from the error banner: pan to the thing at fault and select it.
    function showTarget(target) {
        if (!target)
            return
        const t = TrackStore.track
        if (target.kind === "ruler" && t.ruler) {
            centreOn((t.ruler.a.x + t.ruler.b.x) / 2, (t.ruler.a.y + t.ruler.b.y) / 2)
            TrackStore.select("ruler")
        } else if ((target.kind === "origin" || target.kind === "direction") && t.targets[target.kind]) {
            centreOn(t.targets[target.kind].x, t.targets[target.kind].y)
            TrackStore.select(target.kind)
        } else if (target.kind === "element" && mpp > 0) {
            const el = TrackStore.element(target.id)
            if (el) {
                centreOn(el.x / mpp, el.y / mpp)
                TrackStore.select(el.id)
            }
        }
    }

    function pressAt(e) {
        canvas.forceActiveFocus()
        press = { sx: e.x, sy: e.y, panX: panX, panY: panY }
        if (e.button === Qt.MiddleButton || e.button === Qt.LeftButton) {
            if (e.button === Qt.LeftButton && !spaceHeld)
                TrackStore.select("")
            mode = "pan"
        }
    }

    function moveTo(e) {
        hover = toWorld(e.x, e.y)
        if (!mouse.pressed || mode === "")
            return
        if (mode === "pan") {
            panX = press.panX + e.x - press.sx
            panY = press.panY + e.y - press.sy
        }
    }

    function releaseAt(e) {
        if (mode !== "" && mode !== "pan")
            TrackStore.seal()
        mode = ""
        press = null
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Space && !e.isAutoRepeat) {
            spaceHeld = true
            e.accepted = true
        }
    }
    Keys.onReleased: (e) => {
        if (e.key === Qt.Key_Space && !e.isAutoRepeat) {
            spaceHeld = false
            e.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#010426"
    }

    // Everything in photo pixels, under the zoom and pan.
    Item {
        id: world
        x: canvas.panX
        y: canvas.panY
        scale: canvas.zoom
        transformOrigin: Item.TopLeft

        Image {
            id: photo
            source: canvas.photoPath !== "" ? canvas.photoPath : canvas.blueprint
            asynchronous: true
            smooth: true
            mipmap: true
            onStatusChanged: canvas.tryFit()
        }

        Repeater {
            model: TrackStore.elementCount
            ElementView {
                required property int index
                element: TrackStore.track.elements[index] || null
                zoom: canvas.zoom
                selected: element !== null && TrackStore.selectedId === element.id
                dimmed: TrackStore.previewOn
            }
        }
    }

    // Labels drawn in screen pixels, so text stays sharp and the same size at any zoom.
    Item {
        id: overlay
        anchors.fill: parent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: canvas.mode === "pan" ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onPressed: (e) => canvas.pressAt(e)
        onPositionChanged: (e) => canvas.moveTo(e)
        onReleased: (e) => canvas.releaseAt(e)
        onExited: canvas.hover = null
        onWheel: (w) => canvas.zoomBy(Math.pow(1.0015, w.angleDelta.y), w.x, w.y)
    }
}
```

- [ ] **Step 5: Write `app/qml/StatusBar.qml` and `app/qml/ErrorBanner.qml`**

`StatusBar.qml`:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/frame.mjs" as Frame
import "logic/units.mjs" as Units

// Messages on the left; the cursor's position in the export frame (once both targets exist) and the zoom on the right.
Rectangle {
    id: bar
    required property CanvasView canvas

    implicitHeight: 28
    color: "#181818"

    readonly property var position: {
        const h = canvas.hover
        const f = TrackStore.frame
        return h && f ? Frame.toFrame(f, { x: h.x * TrackStore.mpp, y: h.y * TrackStore.mpp }) : null
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 18

        Label {
            Layout.fillWidth: true
            text: TrackStore.message
            elide: Text.ElideRight
            color: "#d0d0d0"
        }
        Label {
            visible: bar.position !== null
            text: bar.position ? "x " + Units.format(bar.position.x, Settings.units) + " · y "
                                 + Units.format(bar.position.y, Settings.units) : ""
            color: "#d0d0d0"
        }
        Label {
            text: qsTr("Zoom %1%").arg(Math.round(bar.canvas.zoom * 100))
            color: "#d0d0d0"
        }
    }
}
```

`ErrorBanner.qml`:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A problem over the canvas, with "Show me" when there is something to pan to.
Rectangle {
    id: banner

    property string text: ""
    property var target: null
    signal showMe(var target)

    function show(message, target) {
        banner.text = message
        banner.target = target || null
    }
    function hide() {
        banner.text = ""
        banner.target = null
    }

    visible: text !== ""
    width: Math.min(parent ? parent.width - 32 : 640, row.implicitWidth + 24)
    height: row.implicitHeight + 16
    radius: 6
    color: "#8c1d18"
    border.color: "#ff8a80"

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 8
        spacing: 12

        Label {
            Layout.fillWidth: true
            text: banner.text
            color: "#ffffff"
            wrapMode: Text.WordWrap
        }
        Button {
            text: qsTr("Show me")
            visible: banner.target !== null
            onClicked: banner.showMe(banner.target)
        }
        ToolButton {
            text: "✕"
            onClicked: banner.hide()
        }
    }
}
```

- [ ] **Step 6: Rewrite `app/qml/Main.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQml.Models
import QtQuick.Dialogs
import QtQuick.Layouts
import Conestructor
import "logic/demo.mjs" as Demo

ApplicationWindow {
    id: window
    width: 1600
    height: 960
    visible: true
    title: "Conestructor " + AppInfo.shortVersion + " — Untitled"
    color: "#1f1f1f"

    palette.window: "#262626"
    palette.windowText: "#e8e8e8"
    palette.base: "#1b1b1b"
    palette.text: "#f0f0f0"
    palette.button: "#333333"
    palette.buttonText: "#f0f0f0"
    palette.highlight: "#2f6fd6"
    palette.highlightedText: "#ffffff"
    palette.toolTipBase: "#333333"
    palette.toolTipText: "#f0f0f0"

    function newTrack() {
        TrackStore.run("newTrack")
        TrackStore.seal()
        TrackStore.clearPreview()
        canvasView.fitPending = true
        canvasView.tryFit()
    }

    function setBackground(path) {
        TrackStore.run("setPhoto", { path: path })
        TrackStore.seal()
    }

    function backgroundName(name) {
        return ({ duckPondBirdeye: qsTr("Duck pond"), riverwindBirdeye: qsTr("Riverwind") })[name] || name
    }

    // For screenshots (CONESTRUCTOR_DEMO) and the smoke test.
    function loadDemo(withCones) {
        TrackStore.loadTrack(Demo.demoTrack())
        canvasView.fitPending = true
        canvasView.tryFit()
        if (withCones)
            TrackStore.placeCones()
    }

    function conesPlaced() {
        return TrackStore.previewOn && TrackStore.preview ? TrackStore.preview.cones.length : 0
    }

    menuBar: MenuBar {
        Menu {
            id: fileMenu
            title: qsTr("&File")
            Action { text: qsTr("&New"); shortcut: StandardKey.New; onTriggered: window.newTrack() }
            Action { text: qsTr("Load lot photo…"); onTriggered: photoDialog.open() }
            MenuSeparator {}
            Action { text: qsTr("&Quit"); shortcut: StandardKey.Quit; onTriggered: Qt.quit() }
        }
        Menu {
            id: editMenu
            title: qsTr("&Edit")
            Action {
                text: TrackStore.canUndo ? qsTr("Undo %1").arg(TrackStore.undoLabel) : qsTr("Undo")
                enabled: TrackStore.canUndo
                shortcut: StandardKey.Undo
                onTriggered: TrackStore.undo()
            }
            Action {
                text: TrackStore.canRedo ? qsTr("Redo %1").arg(TrackStore.redoLabel) : qsTr("Redo")
                enabled: TrackStore.canRedo
                shortcut: "Ctrl+Y"
                onTriggered: TrackStore.redo()
            }
            MenuSeparator {}
            Action {
                text: qsTr("Duplicate")
                shortcut: "Ctrl+D"
                enabled: TrackStore.selectedElement !== null
                onTriggered: TrackStore.duplicateSelected()
            }
            Action {
                text: qsTr("Delete")
                shortcut: StandardKey.Delete
                enabled: TrackStore.selectedId !== ""
                onTriggered: TrackStore.deleteSelected()
            }
        }
        Menu {
            id: viewMenu
            title: qsTr("&View")
            Action { text: qsTr("Fit to photo"); shortcut: "F"; onTriggered: canvasView.fitToPhoto() }
            Action {
                text: qsTr("Show cones")
                shortcut: "C"
                checkable: true
                checked: TrackStore.showCones
                onTriggered: TrackStore.showCones = checked
            }
            Action {
                text: qsTr("Show route line")
                shortcut: "R"
                checkable: true
                checked: TrackStore.showRoute
                onTriggered: TrackStore.showRoute = checked
            }
            Menu {
                id: backgroundsMenu
                title: qsTr("Backgrounds")
                MenuItem { text: qsTr("Blueprint"); onTriggered: window.setBackground("") }
                Instantiator {
                    model: AppInfo.localBackgrounds
                    delegate: MenuItem {
                        required property string modelData
                        text: window.backgroundName(modelData)
                        onTriggered: window.setBackground("qrc:/qt/qml/Conestructor/assets/images/" + modelData + ".png")
                    }
                    onObjectAdded: (index, object) => backgroundsMenu.insertItem(index + 1, object)
                    onObjectRemoved: (index, object) => backgroundsMenu.removeItem(object)
                }
            }
        }
        Menu {
            title: qsTr("&Process")
            Action { text: qsTr("Place cones"); onTriggered: TrackStore.placeCones() }
            Action { text: qsTr("Clear preview"); enabled: TrackStore.previewOn; onTriggered: TrackStore.clearPreview() }
        }
    }

    // The Backgrounds menu exists only when this build bundled local lot pictures.
    Component.onCompleted: {
        if (AppInfo.localBackgrounds.length === 0)
            viewMenu.removeMenu(backgroundsMenu)
    }

    Shortcut { sequences: ["Ctrl+Shift+Z"]; onActivated: TrackStore.redo() }
    Shortcut { sequences: ["Backspace"]; onActivated: TrackStore.deleteSelected() }

    Connections {
        target: TrackStore
        function onProblem(message, target) { banner.show(message, target) }
        function onProblemsCleared() { banner.hide() }
    }
    Connections {
        target: Settings
        function onSaveFailed(message) { banner.show(message, null) }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        CanvasView {
            id: canvasView
            Layout.fillWidth: true
            Layout.fillHeight: true

            ErrorBanner {
                id: banner
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                onShowMe: (target) => canvasView.showTarget(target)
            }
        }

        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: "#262626"

            ColumnLayout {
                id: sideColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                Item { Layout.fillHeight: true }
            }
        }
    }

    footer: StatusBar { canvas: canvasView }

    FileDialog {
        id: photoDialog
        title: qsTr("Load lot photo")
        nameFilters: [qsTr("Photos (*.png *.jpg *.jpeg)")]
        onAccepted: probe.check(selectedFile)
    }

    // Tries a chosen photo before it replaces the background, so one that fails to load leaves the old one.
    Image {
        id: probe
        visible: false
        asynchronous: false
        sourceSize: Qt.size(64, 64)
        property string pending: ""

        function check(url) {
            source = ""
            pending = url.toString()
            source = url
        }

        onStatusChanged: {
            if (pending === "" || (status !== Image.Ready && status !== Image.Error))
                return
            if (status === Image.Ready)
                window.setBackground(pending)
            else
                TrackStore.report(qsTr("Could not open that photo. The background is unchanged."), null)
            pending = ""
            Qt.callLater(() => { probe.source = "" })
        }
    }
}
```

- [ ] **Step 7: Register the files and the demo affordance**

In `app/CMakeLists.txt`, before `qt_add_qml_module`, mark the singleton:

```cmake
set_source_files_properties(qml/TrackStore.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
```

and replace the module's `QML_FILES` with:

```cmake
    QML_FILES
        qml/Main.qml
        qml/TrackStore.qml
        qml/CanvasView.qml
        qml/ElementView.qml
        qml/StatusBar.qml
        qml/ErrorBanner.qml
        qml/logic/units.mjs
        qml/logic/conerows.mjs
        qml/logic/elements.mjs
        qml/logic/snapping.mjs
        qml/logic/commands.mjs
        qml/logic/frame.mjs
        qml/logic/postprocess.mjs
        qml/logic/viewport.mjs
        qml/logic/demo.mjs
```

In `app/main.cpp`, after `QObject *root = engine.rootObjects().first();`:

```cpp
    // Dev affordance for screenshots: open on the example track ("track"), with its cones placed ("cones").
    // Does nothing unless set.
    const QString demo = qEnvironmentVariable("CONESTRUCTOR_DEMO");
    if (!demo.isEmpty())
        QMetaObject::invokeMethod(root, "loadDemo", Q_ARG(QVariant, QVariant(demo == QStringLiteral("cones"))));
```

In `app/tests/tst_qmlload.cpp`, add after `mainOpensWithTheTitle`:

```cpp
    void theExampleTrackDrawsAndPlacesCones()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        QObject *root = engine.rootObjects().first();
        QVERIFY(QMetaObject::invokeMethod(root, "loadDemo", Q_ARG(QVariant, QVariant(true))));
        QTest::qWait(300);
        QVariant count;
        QVERIFY(QMetaObject::invokeMethod(root, "conesPlaced", Q_RETURN_ARG(QVariant, count)));
        QVERIFY2(count.toInt() > 40, qPrintable(QStringLiteral("%1 cones").arg(count.toInt())));
    }
```

- [ ] **Step 8: Build, test and look**

```powershell
powershell -NoProfile -File app\tests\build.ps1
powershell -NoProfile -File app\tests\run.ps1
powershell -NoProfile -File app\tests\grab.ps1 -Demo track
```

Expected: build succeeds; `ctest: passed`; `qml: … 0 failed`. Read `app\build\tests\grab.png`: the blueprint fills the canvas (fitted), the four elements are drawn as translucent bands with dashed centrelines, joined ends show green dots, the right panel is empty grey, the status bar shows "Zoom NN%". Fix anything that looks wrong before committing.

- [ ] **Step 9: Commit**

```bash
git add app/qml app/CMakeLists.txt app/main.cpp app/tests/tst_qmlload.cpp
git commit -m "App shell: TrackStore, a zoomable canvas drawing elements from data, menus, status bar and error banner" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Palette, ruler and targets

**Files:**
- Create: `app/qml/ElementPalette.qml`, `app/qml/RulerView.qml`, `app/qml/TargetsView.qml`
- Modify: `app/qml/CanvasView.qml` (placing, ruler and target gestures, labels), `app/qml/Main.qml` (palette in the side column), `app/CMakeLists.txt`

**Interfaces:**
- Consumes: `TrackStore.run("setRuler" | "setTarget" | "add")`, `Snapping.findSnap/placeToJoin`, `Elements.TYPES/NAMES/COLOURS/TIPS/defaults`.
- Produces: `CanvasView.beginPlacing(kind)`, `updatePlacing(sx, sy, ctrl)`, `finishPlacing(sx, sy)`, `placingKind`, `ghost`, `snapMetres()`, `hitAt(sx, sy) -> null | { kind: "rotate"|"rulerA"|"rulerB"|"ruler"|"target"|"element", id?, which? }` (this task fills in ruler and target hits; Task 12 adds elements and the rotate handle); `ElementPalette { canvas }` (not `Palette`, which Qt Quick already defines); `RulerView { zoom }`; `TargetsView { zoom }`.

- [ ] **Step 1: Write `app/qml/RulerView.qml`**

```qml
import QtQuick
import QtQuick.Shapes
import Conestructor

// The ruler in photo pixels: a line with end ticks and a round handle at each end. Its length label is drawn by
// CanvasView in screen pixels.
Item {
    id: view
    property real zoom: 1

    readonly property var ruler: TrackStore.track.ruler
    readonly property bool selected: TrackStore.selectedId === "ruler"
    readonly property real angle: ruler ? Math.atan2(ruler.b.y - ruler.a.y, ruler.b.x - ruler.a.x) : 0
    readonly property real tickX: -Math.sin(angle) * 8 / zoom
    readonly property real tickY: Math.cos(angle) * 8 / zoom

    visible: ruler !== null

    Shape {
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#f5cb42"
            strokeWidth: (view.selected ? 3 : 2) / view.zoom
            fillColor: "transparent"
            startX: view.ruler ? view.ruler.a.x : 0
            startY: view.ruler ? view.ruler.a.y : 0
            PathLine { x: view.ruler ? view.ruler.b.x : 0; y: view.ruler ? view.ruler.b.y : 0 }
            PathMove { x: view.ruler ? view.ruler.a.x - view.tickX : 0; y: view.ruler ? view.ruler.a.y - view.tickY : 0 }
            PathLine { x: view.ruler ? view.ruler.a.x + view.tickX : 0; y: view.ruler ? view.ruler.a.y + view.tickY : 0 }
            PathMove { x: view.ruler ? view.ruler.b.x - view.tickX : 0; y: view.ruler ? view.ruler.b.y - view.tickY : 0 }
            PathLine { x: view.ruler ? view.ruler.b.x + view.tickX : 0; y: view.ruler ? view.ruler.b.y + view.tickY : 0 }
        }
    }

    Repeater {
        model: view.ruler ? 2 : 0
        Rectangle {
            required property int index
            readonly property var at: index === 0 ? view.ruler.a : view.ruler.b
            width: 12 / view.zoom
            height: width
            radius: width / 2
            x: at.x - width / 2
            y: at.y - height / 2
            color: "#f5cb42"
            border.color: view.selected ? "#ffffff" : "#202020"
            border.width: 1.5 / view.zoom
        }
    }
}
```

- [ ] **Step 2: Write `app/qml/TargetsView.qml`**

```qml
import QtQuick
import QtQuick.Shapes
import Conestructor

// Origin and Direction in photo pixels: a crosshair each, and with both placed a dashed arrow from Origin through
// Direction. Their names and the distance between them are drawn by CanvasView in screen pixels.
Item {
    id: view
    property real zoom: 1

    readonly property var origin: TrackStore.track.targets.origin
    readonly property var direction: TrackStore.track.targets.direction
    readonly property bool both: origin !== null && direction !== null
    readonly property real length: both ? Math.hypot(direction.x - origin.x, direction.y - origin.y) : 0
    readonly property real ux: length > 0 ? (direction.x - origin.x) / length : 1
    readonly property real uy: length > 0 ? (direction.y - origin.y) / length : 0
    readonly property var tip: both ? Qt.point(direction.x + ux * 40 / zoom, direction.y + uy * 40 / zoom) : Qt.point(0, 0)

    Shape {
        visible: view.both && view.length > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#00ffff"
            strokeWidth: 1.5 / view.zoom
            strokeStyle: ShapePath.DashLine
            dashPattern: [6, 4]
            fillColor: "transparent"
            startX: view.origin ? view.origin.x : 0
            startY: view.origin ? view.origin.y : 0
            PathLine { x: view.tip.x; y: view.tip.y }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: "#00ffff"
            startX: view.tip.x
            startY: view.tip.y
            PathLine { x: view.tip.x - view.ux * 12 / view.zoom - view.uy * 6 / view.zoom; y: view.tip.y - view.uy * 12 / view.zoom + view.ux * 6 / view.zoom }
            PathLine { x: view.tip.x - view.ux * 12 / view.zoom + view.uy * 6 / view.zoom; y: view.tip.y - view.uy * 12 / view.zoom - view.ux * 6 / view.zoom }
            PathLine { x: view.tip.x; y: view.tip.y }
        }
    }

    Repeater {
        model: ["origin", "direction"]
        Item {
            required property string modelData
            readonly property var at: TrackStore.track.targets[modelData]
            readonly property bool selected: TrackStore.selectedId === modelData
            visible: at !== null
            x: at ? at.x : 0
            y: at ? at.y : 0

            Image {
                source: "qrc:/qt/qml/Conestructor/assets/images/crosshair.svg"
                width: 32 / view.zoom
                height: width
                x: -width / 2
                y: -height / 2
                sourceSize: Qt.size(64, 64)
            }
            Rectangle {
                width: (parent.selected ? 9 : 6) / view.zoom
                height: width
                radius: width / 2
                x: -width / 2
                y: -height / 2
                color: parent.selected ? "#ffffff" : "#00ffff"
            }
        }
    }
}
```

- [ ] **Step 3: Write `app/qml/ElementPalette.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/elements.mjs" as Elements

// Tiles dragged onto the canvas. One ruler and one of each target per track (their tiles grey out once placed);
// track elements wait for the ruler's real length.
GridLayout {
    id: palette
    required property CanvasView canvas

    columns: 2
    rowSpacing: 8
    columnSpacing: 8

    readonly property bool rulerReady: TrackStore.mpp > 0
    readonly property var tiles: [
        { kind: "ruler", name: qsTr("Ruler"), colour: "#f5cb42",
          tip: qsTr("Ruler: drag its ends onto something you know the length of, then type that length.") },
        { kind: "origin", name: qsTr("Origin"), colour: "#00ffff", tip: qsTr("Origin target: x and y are measured from here.") },
        { kind: "direction", name: qsTr("Direction"), colour: "#00ffff", tip: qsTr("Direction target: x points from Origin toward it.") },
        { kind: "straight", name: Elements.NAMES.straight, colour: Elements.COLOURS.straight, tip: Elements.TIPS.straight },
        { kind: "slalom", name: Elements.NAMES.slalom, colour: Elements.COLOURS.slalom, tip: Elements.TIPS.slalom },
        { kind: "chicane", name: Elements.NAMES.chicane, colour: Elements.COLOURS.chicane, tip: Elements.TIPS.chicane },
        { kind: "turn", name: Elements.NAMES.turn, colour: Elements.COLOURS.turn, tip: Elements.TIPS.turn }
    ]

    function available(kind) {
        if (kind === "ruler")
            return TrackStore.track.ruler === null
        if (kind === "origin" || kind === "direction")
            return TrackStore.track.targets[kind] === null
        return rulerReady
    }

    Repeater {
        model: palette.tiles
        delegate: Rectangle {
            id: tile
            required property var modelData
            readonly property bool usable: palette.available(modelData.kind)
            readonly property bool isTrack: Elements.TYPES.indexOf(modelData.kind) >= 0

            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 6
            color: area.containsMouse && usable ? "#3a3a3a" : "#303030"
            opacity: usable ? 1 : 0.4

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 8
                width: 6
                radius: 3
                color: tile.modelData.colour
            }
            Label {
                anchors.centerIn: parent
                text: tile.modelData.name
                color: "#f0f0f0"
            }

            ToolTip.visible: area.containsMouse
            ToolTip.delay: 400
            ToolTip.text: !usable && isTrack ? qsTr("Set the ruler first.") : modelData.tip

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                onPressed: (mouse) => {
                    if (!tile.usable) {
                        mouse.accepted = false
                        return
                    }
                    palette.canvas.beginPlacing(tile.modelData.kind)
                }
                onPositionChanged: (mouse) => {
                    if (!pressed)
                        return
                    const p = mapToItem(palette.canvas, mouse.x, mouse.y)
                    palette.canvas.updatePlacing(p.x, p.y, (mouse.modifiers & Qt.ControlModifier) !== 0)
                }
                onReleased: (mouse) => {
                    const p = mapToItem(palette.canvas, mouse.x, mouse.y)
                    palette.canvas.finishPlacing(p.x, p.y)
                }
            }
        }
    }

    Label {
        Layout.columnSpan: 2
        Layout.fillWidth: true
        visible: !palette.rulerReady
        text: qsTr("Set the ruler first.")
        color: "#b0b0b0"
        wrapMode: Text.WordWrap
    }
}
```

- [ ] **Step 4: Add placing, ruler and target gestures and labels to `CanvasView.qml`**

Add imports at the top:

```qml
import "logic/elements.mjs" as Elements
import "logic/snapping.mjs" as Snapping
import "logic/units.mjs" as Units
```

Add properties after `property string gestureKey: ""`:

```qml
    property string placingKind: ""   // a palette tile being dragged: a track type, "ruler", "origin" or "direction"
    property var ghost: null          // the track element being placed, as it would land
```

Add these functions after `showTarget`:

```qml
    // Snapping reaches 30 screen pixels, whatever the zoom.
    function snapMetres() {
        return 30 / zoom * mpp
    }

    function distance(a, b) {
        return Math.hypot(a.x - b.x, a.y - b.y)
    }

    // What is under a screen point, most specific first.
    function hitAt(sx, sy) {
        const w = toWorld(sx, sy)
        const reach = 10 / zoom
        const t = TrackStore.track
        if (t.ruler) {
            if (distance(t.ruler.a, w) < reach)
                return { kind: "rulerA" }
            if (distance(t.ruler.b, w) < reach)
                return { kind: "rulerB" }
        }
        for (const which of ["origin", "direction"]) {
            const p = t.targets[which]
            if (p && distance(p, w) < 16 / zoom)
                return { kind: "target", which: which }
        }
        if (t.ruler && Elements.pointSegmentDistance(w, t.ruler.a, t.ruler.b) < 6 / zoom)
            return { kind: "ruler" }
        return null
    }

    function beginPlacing(kind) {
        placingKind = kind
        ghost = null
    }

    function insideCanvas(sx, sy) {
        return sx >= 0 && sy >= 0 && sx <= width && sy <= height
    }

    function updatePlacing(sx, sy, ctrl) {
        if (Elements.TYPES.indexOf(placingKind) < 0 || !insideCanvas(sx, sy) || !(mpp > 0)) {
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

    function finishPlacing(sx, sy) {
        const kind = placingKind
        const g = ghost
        placingKind = ""
        ghost = null
        if (!insideCanvas(sx, sy))
            return
        const w = toWorld(sx, sy)
        if (kind === "ruler") {
            const half = 80 / zoom
            TrackStore.run("setRuler", { a: { x: w.x - half, y: w.y }, b: { x: w.x + half, y: w.y }, realLength: 0 })
            TrackStore.select("ruler")
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

Replace `pressAt` and `moveTo` with:

```qml
    function pressAt(e) {
        canvas.forceActiveFocus()
        gestureKey = TrackStore.newGestureKey()
        press = { sx: e.x, sy: e.y, panX: panX, panY: panY }
        if (e.button === Qt.MiddleButton || (e.button === Qt.LeftButton && spaceHeld)) {
            mode = "pan"
            return
        }
        if (e.button !== Qt.LeftButton)
            return
        const hit = hitAt(e.x, e.y)
        if (!hit) {
            TrackStore.select("")
            mode = "pan"
            return
        }
        const t = TrackStore.track
        if (hit.kind === "rulerA" || hit.kind === "rulerB" || hit.kind === "ruler") {
            TrackStore.select("ruler")
            press.ruler = t.ruler
            mode = hit.kind
        } else if (hit.kind === "target") {
            TrackStore.select(hit.which)
            press.which = hit.which
            press.target = t.targets[hit.which]
            mode = "target"
        }
    }

    function moveTo(e) {
        hover = toWorld(e.x, e.y)
        if (!mouse.pressed || mode === "")
            return
        const dx = (e.x - press.sx) / zoom
        const dy = (e.y - press.sy) / zoom
        if (mode === "pan") {
            panX = press.panX + e.x - press.sx
            panY = press.panY + e.y - press.sy
        } else if (mode === "rulerA" || mode === "rulerB" || mode === "ruler") {
            const r = press.ruler
            const a = mode === "rulerB" ? r.a : { x: r.a.x + dx, y: r.a.y + dy }
            const b = mode === "rulerA" ? r.b : { x: r.b.x + dx, y: r.b.y + dy }
            TrackStore.run("setRuler", { a: a, b: b, realLength: r.realLength, mergeKey: gestureKey })
        } else if (mode === "target") {
            TrackStore.run("setTarget", { which: press.which, point: { x: press.target.x + dx, y: press.target.y + dy },
                                          mergeKey: gestureKey })
        }
    }
```

Inside the `world` item, after the elements `Repeater`, add:

```qml
        ElementView {
            element: canvas.ghost
            zoom: canvas.zoom
            opacity: 0.6
        }
        RulerView { zoom: canvas.zoom }
        TargetsView { zoom: canvas.zoom }
```

Replace the empty `overlay` item with:

```qml
    // Labels drawn in screen pixels, so text stays sharp and the same size at any zoom.
    Item {
        id: overlay
        anchors.fill: parent

        Repeater {
            model: ["origin", "direction"]
            Label {
                required property string modelData
                readonly property var at: TrackStore.track.targets[modelData]
                visible: at !== null
                x: at ? canvas.toScreen(at.x, at.y).x + 14 : 0
                y: at ? canvas.toScreen(at.x, at.y).y - 24 : 0
                text: modelData === "origin" ? qsTr("Origin") : qsTr("Direction")
                color: "#00ffff"
                font.bold: true
                style: Text.Outline
                styleColor: "#000000"
            }
        }
        Label {
            readonly property var o: TrackStore.track.targets.origin
            readonly property var d: TrackStore.track.targets.direction
            visible: TrackStore.frame !== null
            x: visible ? canvas.toScreen((o.x + d.x) / 2, (o.y + d.y) / 2).x - width / 2 : 0
            y: visible ? canvas.toScreen((o.x + d.x) / 2, (o.y + d.y) / 2).y + 8 : 0
            text: TrackStore.frame ? Units.format(TrackStore.frame.distance, Settings.units) : ""
            color: "#00ffff"
            style: Text.Outline
            styleColor: "#000000"
        }
        Label {
            readonly property var r: TrackStore.track.ruler
            visible: r !== null
            x: r ? canvas.toScreen((r.a.x + r.b.x) / 2, (r.a.y + r.b.y) / 2).x - width / 2 : 0
            y: r ? canvas.toScreen((r.a.x + r.b.x) / 2, (r.a.y + r.b.y) / 2).y - height - 10 : 0
            text: !r ? "" : r.realLength > 0 ? Units.format(r.realLength, Settings.units) : qsTr("Set real length")
            color: "#f5cb42"
            font.bold: true
            style: Text.Outline
            styleColor: "#000000"
        }
    }
```

- [ ] **Step 5: Put the palette in the side column and register the files**

In `app/qml/Main.qml`, replace

```qml
                Item { Layout.fillHeight: true }
```

with

```qml
                ElementPalette {
                    canvas: canvasView
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }
```

In `app/CMakeLists.txt` `QML_FILES`, add after `qml/ErrorBanner.qml`:

```cmake
        qml/ElementPalette.qml
        qml/RulerView.qml
        qml/TargetsView.qml
```

- [ ] **Step 6: Build, test and look**

```powershell
powershell -NoProfile -File app\tests\build.ps1
powershell -NoProfile -File app\tests\run.ps1
powershell -NoProfile -File app\tests\grab.ps1 -Demo track
```

Expected: tests pass. In `grab.png`: the palette shows seven tiles with Ruler, Origin and Direction greyed (already placed in the demo); the ruler is drawn with ticks, handles and "65' 7\"" above it (20 m in feet and inches); both crosshairs with their names; a dashed arrow from Origin past Direction with "328' 1\"" (100 m) under its middle.

Then run the app (`app\build\tests\appConestructor.exe`, with `D:\allNewQT6\6.11.1\msvc2022_64\bin` on PATH) on an empty track and try by hand: drag the Ruler tile onto the canvas, drag each end, drag the ruler's body; drag Origin and Direction tiles, drag them about; Ctrl+Z undoes each drag as one step and the Edit menu names it ("Undo Move Origin").

- [ ] **Step 7: Commit**

```bash
git add app/qml app/CMakeLists.txt
git commit -m "Palette, ruler and targets: drag tiles onto the canvas, drag ruler ends and targets, labels in screen pixels" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Selecting and editing track elements

**Files:**
- Modify: `app/qml/CanvasView.qml`

**Interfaces:**
- Consumes: `Elements.hitTest/rotateHandle`, `Snapping.findSnap/placeToJoin`, `TrackStore.run("place")`, `TrackStore.duplicateSelected/deleteSelected`, `Frame.normalize`.
- Produces: `CanvasView` gestures `"move"` and `"rotate"`, a right-click menu (Duplicate, Delete).

- [ ] **Step 1: Hit elements and the rotate handle**

Add `import "logic/frame.mjs" as Frame` to `CanvasView.qml`. In `hitAt`, before the `if (t.ruler) {` block that checks the ruler's ends, add:

```qml
        const selected = TrackStore.selectedElement
        if (selected && mpp > 0) {
            const h = Elements.rotateHandle(selected, 24 / zoom * mpp)
            if (distance({ x: h.x / mpp, y: h.y / mpp }, w) < reach)
                return { kind: "rotate", id: selected.id }
        }
```

and before the final `if (t.ruler && Elements.pointSegmentDistance(...` line add:

```qml
        if (mpp > 0) {
            const id = Elements.hitTest(t.elements, { x: w.x * mpp, y: w.y * mpp }, 4 / zoom * mpp)
            if (id !== "")
                return { kind: "element", id: id }
        }
```

- [ ] **Step 2: Move and rotate gestures**

In `pressAt`, replace

```qml
        if (e.button !== Qt.LeftButton)
            return
        const hit = hitAt(e.x, e.y)
```

with

```qml
        const hit = hitAt(e.x, e.y)
        if (e.button === Qt.RightButton) {
            if (hit && hit.kind === "element") {
                TrackStore.select(hit.id)
                elementMenu.popup()
            }
            return
        }
        if (e.button !== Qt.LeftButton)
            return
```

and in the same function, before `if (hit.kind === "rulerA" || …`, add:

```qml
        if (hit.kind === "element" || hit.kind === "rotate") {
            TrackStore.select(hit.id)
            press.el = TrackStore.element(hit.id)
            press.w = toWorld(e.x, e.y)
            mode = hit.kind === "rotate" ? "rotate" : "move"
            return
        }
```

Add this function after `finishPlacing`:

```qml
    // Puts the element where the drag says, snapped to the nearest open end unless Ctrl is held. The element
    // unjoins as it moves and joins again wherever it lands snapped.
    function placeDragged(moved, ctrl) {
        const snap = ctrl ? null : Snapping.findSnap(TrackStore.track.elements, moved, snapMetres())
        TrackStore.run("place", {
            id: moved.id, x: moved.x, y: moved.y, rotation: moved.rotation,
            snap: snap ? { ownEnd: snap.ownEnd, id: snap.targetId, end: snap.targetEnd } : null,
            verb: "Move", mergeKey: gestureKey
        })
    }
```

In `moveTo`, before `} else if (mode === "rulerA" || …`, add:

```qml
        } else if (mode === "move") {
            const ctrl = (e.modifiers & Qt.ControlModifier) !== 0
            placeDragged(Object.assign({}, press.el, { x: press.el.x + dx * mpp, y: press.el.y + dy * mpp }), ctrl)
        } else if (mode === "rotate") {
            const cx = press.el.x / mpp
            const cy = press.el.y / mpp
            const w = toWorld(e.x, e.y)
            let rotation = press.el.rotation
                + (Math.atan2(w.y - cy, w.x - cx) - Math.atan2(press.w.y - cy, press.w.x - cx)) * 180 / Math.PI
            if ((e.modifiers & Qt.ShiftModifier) !== 0)
                rotation = Math.round(rotation / 15) * 15
            TrackStore.run("place", { id: press.el.id, x: press.el.x, y: press.el.y, rotation: Frame.normalize(rotation),
                                      snap: null, verb: "Rotate", mergeKey: gestureKey })
```

(The `place` command computes the snapped placement itself from `snap`, so the drag passes the raw position.)

- [ ] **Step 3: The right-click menu**

Add at the end of `CanvasView.qml`, after the `MouseArea`:

```qml
    Menu {
        id: elementMenu
        MenuItem { text: qsTr("Duplicate"); onTriggered: TrackStore.duplicateSelected() }
        MenuItem { text: qsTr("Delete"); onTriggered: TrackStore.deleteSelected() }
    }
```

and make the `MouseArea`'s cursor show what a drag will do:

```qml
        cursorShape: canvas.mode === "pan" ? Qt.ClosedHandCursor
                     : canvas.mode === "move" || canvas.mode === "target" ? Qt.SizeAllCursor
                     : Qt.ArrowCursor
```

- [ ] **Step 4: Build, test and try it by hand**

```powershell
powershell -NoProfile -File app\tests\build.ps1
powershell -NoProfile -File app\tests\run.ps1
```

Expected: tests pass. Then run the app with `CONESTRUCTOR_DEMO=track` (set it in the shell before starting `appConestructor.exe`) and check each of these by hand, fixing what fails:

1. Click an element: white outline and a rotate handle above it. Click empty canvas: nothing selected.
2. Drag the Turn away: its neighbours' end dots turn to rings; drag it back near the Slalom's exit: it snaps (rotates to meet) and the dots turn green on release.
3. Hold Ctrl while dragging near an open end: no snapping.
4. Drag the rotate handle: it turns about its middle; with Shift it steps by 15°. The element unjoins.
5. Delete and Backspace delete the selection; Ctrl+D duplicates 2 m right and down, unjoined, and selects the copy; right-click offers Duplicate and Delete.
6. Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z step through each of those, one step per drag, with the step named in the Edit menu.
7. Space+drag and middle-drag pan even when starting on an element; the wheel zooms toward the cursor; F fits; resizing the window does not change the zoom.

- [ ] **Step 5: Commit**

```bash
git add app/qml/CanvasView.qml
git commit -m "Editing elements: select, drag with snapping (Ctrl to turn it off), rotate handle with Shift for 15 degrees, right-click menu" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Property panel, unit-aware fields and Preferences

**Files:**
- Create: `app/qml/PropField.qml`, `app/qml/PropertyPanel.qml`, `app/qml/PreferencesDialog.qml`
- Modify: `app/qml/Main.qml` (panel in the side column, Preferences action and dialog), `app/CMakeLists.txt`

**Interfaces:**
- Consumes: `Units.formatValue/parseValue/stepFor/UNITS/LABELS`, `Elements.clamp/propList/NAMES`, `Frame.toFrame/headingToFrame`, `Settings.units`, `TrackStore.run("setProp" | "setRuler")`, `TrackStore.seal()`.
- Produces: `PropField { def; value; emptyWhenZero; signal edited(newValue); signal finished() }`; `PropertyPanel`; `PreferencesDialog`.

- [ ] **Step 1: Write `app/qml/PropField.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/elements.mjs" as Elements
import "logic/units.mjs" as Units

// One setting: a field in the chosen units with up and down arrows (length, angle, count), or a two-way switch
// (choice). Changes apply as you type. Text that is not a value turns red and the old value stays until it is fixed
// or Esc puts it back; a value outside the setting's limits is kept within them, with a note.
ColumnLayout {
    id: field

    required property var def
    required property var value
    property bool emptyWhenZero: false
    signal edited(var newValue)
    signal finished()

    property bool bad: false
    property string note: ""
    readonly property string unit: Settings.units
    readonly property bool isChoice: def.kind === "choice"

    Layout.fillWidth: true
    spacing: 2

    function shown() {
        if (emptyWhenZero && !(value > 0))
            return ""
        return Units.formatValue(def.kind, value, unit)
    }

    function refresh() {
        if (!input.activeFocus) {
            input.text = shown()
            bad = false
        }
    }

    // Stores a parsed value, kept within limits; returns what was stored.
    function apply(parsed) {
        const c = Elements.clamp(def, parsed)
        note = c.clamped ? qsTr("Kept within %1 to %2").arg(Units.formatValue(def.kind, def.min, unit))
                                                          .arg(Units.formatValue(def.kind, def.max, unit)) : ""
        if (c.value !== value)
            edited(c.value)
        return c.value
    }

    function typed(text) {
        const parsed = Units.parseValue(def.kind, text, unit)
        bad = isNaN(parsed)
        if (!bad)
            apply(parsed)
    }

    function step(direction) {
        const stored = apply(Number(value) + direction * Units.stepFor(def.kind, unit))
        input.text = Units.formatValue(def.kind, stored, unit)
        bad = false
    }

    onValueChanged: refresh()
    onUnitChanged: {
        input.text = shown()
        bad = false
    }
    Component.onCompleted: refresh()

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Label {
            text: field.def.label
            color: "#e0e0e0"
            Layout.preferredWidth: 104
            elide: Text.ElideRight
        }

        RowLayout {
            visible: field.isChoice
            spacing: 0
            Repeater {
                model: field.isChoice ? field.def.choices.length : 0
                Button {
                    required property int index
                    text: field.def.labels[index]
                    checkable: true
                    checked: field.value === field.def.choices[index]
                    focusPolicy: Qt.NoFocus
                    onClicked: {
                        field.edited(field.def.choices[index])
                        field.finished()
                    }
                }
            }
        }

        TextField {
            id: input
            visible: !field.isChoice
            Layout.fillWidth: true
            color: field.bad ? "#ff6b6b" : "#f0f0f0"
            placeholderText: field.emptyWhenZero ? qsTr("Type it here") : ""
            selectByMouse: true
            onTextEdited: field.typed(text)
            onEditingFinished: {
                if (!field.bad)
                    text = field.shown()
                field.finished()
            }
            Keys.onEscapePressed: {
                field.bad = false
                field.note = ""
                text = field.shown()
            }
            Keys.onUpPressed: field.step(1)
            Keys.onDownPressed: field.step(-1)
        }

        ColumnLayout {
            visible: !field.isChoice
            spacing: 0
            ToolButton {
                text: "▲"
                font.pixelSize: 9
                implicitHeight: 15
                focusPolicy: Qt.NoFocus
                onClicked: { field.step(1); field.finished() }
            }
            ToolButton {
                text: "▼"
                font.pixelSize: 9
                implicitHeight: 15
                focusPolicy: Qt.NoFocus
                onClicked: { field.step(-1); field.finished() }
            }
        }
    }

    Label {
        visible: field.note !== ""
        text: field.note
        color: "#ffb74d"
        font.pixelSize: 11
        Layout.leftMargin: 110
    }
}
```

- [ ] **Step 2: Write `app/qml/PropertyPanel.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/elements.mjs" as Elements
import "logic/frame.mjs" as Frame
import "logic/units.mjs" as Units

// The settings of whatever is selected. For an element: where it is and which way it points in the export frame
// (once both targets exist), then its settings in plain words.
ScrollView {
    id: panel
    clip: true
    contentWidth: availableWidth

    readonly property var el: TrackStore.selectedElement
    readonly property string kind: el ? "element" : TrackStore.selectedId
    // Changes only when the selection or the set of visible settings changes, so fields are not rebuilt while typing.
    readonly property string fieldsKey: el ? el.id + ":" + Elements.propList(el.type, el.props).map(p => p.key).join(",") : ""
    property var defs: []
    onFieldsKeyChanged: defs = el ? Elements.propList(el.type, el.props) : []

    readonly property var framePosition: el && TrackStore.frame ? Frame.toFrame(TrackStore.frame, el) : null
    readonly property real frameRotation: el && TrackStore.frame ? Frame.headingToFrame(TrackStore.frame, el.rotation) : 0

    ColumnLayout {
        width: panel.availableWidth
        spacing: 8

        Label {
            text: panel.kind === "element" ? Elements.NAMES[panel.el.type]
                  : panel.kind === "ruler" ? qsTr("Ruler")
                  : panel.kind === "origin" ? qsTr("Origin target")
                  : panel.kind === "direction" ? qsTr("Direction target")
                  : qsTr("Nothing selected")
            font.bold: true
            font.pixelSize: 16
            color: "#ffffff"
        }
        Label {
            visible: panel.kind === ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Click something on the canvas to change it.")
            color: "#b0b0b0"
        }

        Label {
            visible: panel.framePosition !== null
            text: panel.framePosition ? qsTr("Position   x %1 · y %2").arg(Units.format(panel.framePosition.x, Settings.units))
                                                                     .arg(Units.format(panel.framePosition.y, Settings.units)) : ""
            color: "#b0b0b0"
        }
        Label {
            visible: panel.framePosition !== null
            text: qsTr("Rotation   %1").arg(Units.formatAngle(panel.frameRotation))
            color: "#b0b0b0"
        }

        Repeater {
            model: panel.defs
            PropField {
                required property var modelData
                def: modelData
                value: panel.el ? panel.el.props[modelData.key] : 0
                onEdited: (v) => TrackStore.run("setProp", { id: panel.el.id, key: modelData.key, value: v })
                onFinished: TrackStore.seal()
            }
        }

        Label {
            visible: panel.kind === "ruler"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Drag the ruler's ends onto something you know the length of, such as a parking space, then type its real length.")
            color: "#b0b0b0"
        }
        PropField {
            visible: panel.kind === "ruler"
            def: ({ key: "realLength", label: qsTr("Real length"), kind: "length", min: 0.1, max: 1000 })
            value: TrackStore.track.ruler ? TrackStore.track.ruler.realLength : 0
            emptyWhenZero: true
            onEdited: (v) => {
                const r = TrackStore.track.ruler
                TrackStore.run("setRuler", { a: r.a, b: r.b, realLength: v, mergeKey: "ruler-length" })
            }
            onFinished: TrackStore.seal()
        }

        Label {
            visible: panel.kind === "origin" || panel.kind === "direction"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: panel.kind === "origin" ? qsTr("x and y are measured from here. Drag it to move it.")
                                          : qsTr("x points from Origin toward here. Drag it to move it.")
            color: "#b0b0b0"
        }
        Label {
            visible: panel.kind === "direction" && TrackStore.frame !== null
            text: TrackStore.frame ? qsTr("From Origin: %1").arg(Units.format(TrackStore.frame.distance, Settings.units)) : ""
            color: "#b0b0b0"
        }
    }
}
```

- [ ] **Step 3: Write `app/qml/PreferencesDialog.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/units.mjs" as Units

// Edit > Preferences. Part 1 has one section, Units; parts 3 and 4 add Cones, Car and Team.
Dialog {
    id: dialog
    title: qsTr("Preferences")
    modal: true
    standardButtons: Dialog.Close
    anchors.centerIn: parent

    ColumnLayout {
        spacing: 6

        Label {
            text: qsTr("Units")
            font.bold: true
        }
        Label {
            text: qsTr("How lengths are shown and typed. Files always store metres.")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: 320
            color: "#b0b0b0"
        }
        ButtonGroup { id: unitGroup }
        Repeater {
            model: Units.UNITS
            RadioButton {
                required property string modelData
                text: Units.LABELS[modelData]
                ButtonGroup.group: unitGroup
                checked: Settings.units === modelData
                onToggled: if (checked) Settings.units = modelData
            }
        }
    }
}
```

- [ ] **Step 4: Wire them into `Main.qml` and CMake**

In `app/qml/Main.qml`, replace the side column's

```qml
                Item { Layout.fillHeight: true }
```

with

```qml
                PropertyPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
```

In the Edit menu, after the Delete action, add:

```qml
            MenuSeparator {}
            Action { text: qsTr("Preferences…"); shortcut: "Ctrl+,"; onTriggered: preferences.open() }
```

and after the `photoDialog` add:

```qml
    PreferencesDialog { id: preferences }
```

In `app/CMakeLists.txt` `QML_FILES`, add:

```cmake
        qml/PropField.qml
        qml/PropertyPanel.qml
        qml/PreferencesDialog.qml
```

- [ ] **Step 5: Build, test and try it by hand**

```powershell
powershell -NoProfile -File app\tests\build.ps1
powershell -NoProfile -File app\tests\run.ps1
powershell -NoProfile -File app\tests\grab.ps1 -Demo track
```

Expected: tests pass; the screenshot shows the panel under the palette ("Nothing selected"). Then by hand, with `CONESTRUCTOR_DEMO=track`:

1. Select the Turn: Position and Rotation in the export frame, then Lead-in, Lead-out, Turn angle, Radius, Radius type, Direction, Track width in feet and inches. Switch Radius type to Changing: Exit radius appears.
2. Type `12' 6"` into Track width: the band widens as you type; the chain stays joined. Type `abc`: red, element unchanged; Esc puts the old value back. Type `50 m`: kept at 20 m with the note "Kept within 3' 3" to 65' 7"".
3. While a field has focus, Backspace and Delete edit the text and do not delete the element; F, C and R type letters.
4. Up and down arrows (keys and buttons) step by an inch. One Ctrl+Z undoes a whole bout of typing in one field ("Undo Change Track width").
5. Select the ruler, type a new real length: elements keep their spots on the photo and their sizes, and the chain stays joined; Ctrl+Z puts everything back.
6. Edit › Preferences… (Ctrl+,): switch to Metres; every field, the ruler label, the target distance and the status bar change at once. Close and reopen the app: still Metres (then switch back to feet and inches).

- [ ] **Step 6: Commit**

```bash
git add app/qml app/CMakeLists.txt
git commit -m "Property panel with unit-aware fields that apply as you type, the ruler's real length, and Preferences for units" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Cone preview and the JSON export

**Files:**
- Create: `app/qml/ConePreview.qml`
- Modify: `app/qml/CanvasView.qml` (preview layer), `app/qml/Main.qml` (File › Export cones), `app/CMakeLists.txt`

**Interfaces:**
- Consumes: `TrackStore.preview.canvasCones`, `TrackStore.showCones/showRoute/previewOn`, `TrackStore.processed()`, `FileIO.toLocalPath/writeConeExport`.
- Produces: `ConePreview { zoom }`; `Main.exportCones()`, `Main.writeExport(url)`.

- [ ] **Step 1: Write `app/qml/ConePreview.qml`**

```qml
import QtQuick
import QtQuick.Shapes
import Conestructor

// Placed cones at true size (10.5 in base; a leaning cone is 18 in long), in photo pixels, and the yellow route line
// through them in driving order. View > Show cones (C) and Show route line (R) toggle each.
Item {
    id: layer
    property real zoom: 1

    readonly property real mpp: TrackStore.mpp
    readonly property var cones: TrackStore.previewOn && TrackStore.preview ? TrackStore.preview.canvasCones : []
    readonly property var routePoints: mpp > 0 ? cones.map(c => Qt.point(c.x / mpp, c.y / mpp)) : []
    readonly property real baseMetres: 10.5 * 0.0254
    readonly property real leaningMetres: 18 * 0.0254

    visible: cones.length > 0 && mpp > 0

    Shape {
        visible: TrackStore.showRoute && layer.routePoints.length > 1
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#ffff00"
            strokeWidth: 2 / layer.zoom
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: layer.routePoints }
        }
    }

    Repeater {
        model: TrackStore.showCones ? layer.cones : []
        Image {
            required property var modelData
            readonly property bool leaning: modelData.type === "leaning"
            source: leaning ? "qrc:/qt/qml/Conestructor/assets/images/sideways-cone.png"
                            : "qrc:/qt/qml/Conestructor/assets/images/upright-cone.png"
            width: layer.baseMetres / layer.mpp
            height: (leaning ? layer.leaningMetres : layer.baseMetres) / layer.mpp
            x: modelData.x / layer.mpp - width / 2
            y: modelData.y / layer.mpp - height / 2
            rotation: modelData.heading
            sourceSize: Qt.size(64, 64)
            smooth: true
        }
    }
}
```

- [ ] **Step 2: Add the preview to the canvas and the export to the File menu**

In `app/qml/CanvasView.qml`, inside `world`, between the ghost `ElementView` and `RulerView`, add:

```qml
        ConePreview { zoom: canvas.zoom }
```

In `app/qml/Main.qml`, add these functions after `conesPlaced()`:

```qml
    function exportCones() {
        const result = TrackStore.processed()
        if (!result)
            return
        exportDialog.result = result
        exportDialog.open()
    }

    function writeExport(url) {
        const result = exportDialog.result
        const path = FileIO.toLocalPath(url)
        const error = FileIO.writeConeExport(path, result.targetDistance, result.cones)
        if (error !== "")
            TrackStore.report(error, null)
        else
            TrackStore.message = qsTr("Exported %1 cones to %2").arg(result.cones.length).arg(path)
    }
```

In the File menu, after "Load lot photo…", add:

```qml
            Action { text: qsTr("Export cones (JSON)…"); onTriggered: window.exportCones() }
```

and after `photoDialog` add:

```qml
    FileDialog {
        id: exportDialog
        property var result: null
        title: qsTr("Export cones")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("JSON files (*.json)")]
        defaultSuffix: "json"
        onAccepted: window.writeExport(selectedFile)
    }
```

In `app/CMakeLists.txt` `QML_FILES`, add `qml/ConePreview.qml`.

- [ ] **Step 3: Build, test and look**

```powershell
powershell -NoProfile -File app\tests\build.ps1
powershell -NoProfile -File app\tests\run.ps1
powershell -NoProfile -File app\tests\grab.ps1
```

Expected: tests pass (the smoke test now also draws the preview). In `grab.png`: cones along every element, leaning cones in the slalom, turn and chicane, a yellow route line through them in order, the elements dimmed, and "Placed N cones" in the status bar.

Then by hand: View › Show cones (C) and Show route line (R) toggle; dragging an element while the preview is on redraws the cones; Process › Clear preview removes the overlay. On a new track, Process › Place cones shows the banner "Place the ruler on something of known length, then set its real length"; with a ruler of no length the banner says "Set the ruler's real length" and Show me pans to the ruler and selects it. File › Export cones (JSON)… writes a file; open it and check `"units": "m"`, the axes sentence, `targetDistance`, and cones with `index`, `type`, `x`, `y`, `heading`.

- [ ] **Step 4: Commit**

```bash
git add app/qml app/CMakeLists.txt
git commit -m "Cone preview with route line and toggles, and File > Export cones (JSON) in metres with y to the left" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: README, final checks, the owner's check, merge and push

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update `README.md`**

Replace the Prototype note, Build and Layout sections with:

```markdown
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
```

- [ ] **Step 2: Run everything**

```powershell
powershell -NoProfile -File app\tests\build.ps1
powershell -NoProfile -File app\tests\run.ps1
```

Expected: `ctest: passed` and `qml: N passed, 0 failed`. Use superpowers:verification-before-completion: quote the two summary lines in the report.

- [ ] **Step 3: A clean copy builds without the map images**

```powershell
$clean = Join-Path $env:TEMP 'conestructor-clean'
Remove-Item -Recurse -Force $clean -ErrorAction SilentlyContinue
git clone --quiet --branch part1-core-canvas . $clean
Test-Path "$clean\app\assets\images\duckPondBirdeye.png"     # expect False
powershell -NoProfile -File "$clean\app\tests\build.ps1"
powershell -NoProfile -File "$clean\app\tests\run.ps1"
```

Expected: `False`, then a clean build and all tests passing. (Without the images the View › Backgrounds menu is absent; the smoke test covers that path.)

- [ ] **Step 4: Check what would be pushed**

```bash
git diff --stat main...part1-core-canvas
git grep -n -I -E "192\.168\.|([0-9]{1,3}\.){3}[0-9]{1,3}|scp |password|secret|token|api[_-]?key" part1-core-canvas -- . ':!docs' ':!*.svg'
git log --format=%B main..part1-core-canvas | grep -n -i -E "192\.168|subdomain|\.(com|net|org|io)" 
```

Expected: the diff is the app, tests, docs, LICENSE, README and .gitignore; the greps find nothing but version-like numbers in code (read each hit). No map image, no `secrets.json`, no build output. If anything names the server or the home network, stop and ask the owner.

- [ ] **Step 5: Code review**

Use superpowers:requesting-code-review for the whole branch (`main...part1-core-canvas`), with the spec and this plan as context and the Review Focus list as the reviewer's checklist. Fix what it confirms, re-run Step 2, commit.

- [ ] **Step 6: The owner's 10-minute check**

Ask the owner to run the app (`app\build\tests\appConestructor.exe`, or build in Qt Creator) and walk the spec's check, reporting anything off:

1. File › Load lot photo… and pick a lot picture (or View › Backgrounds).
2. Drag the Ruler onto a parking space, drag its ends to the lines, type its real length.
3. Place Origin and Direction.
4. Build a short track with all four elements, joined.
5. Zoom with the wheel, pan by dragging empty canvas, resize the window (the scale stays).
6. Undo and redo a few steps; check the Edit menu names them.
7. Switch units in Preferences and back.
8. Process › Place cones.
9. File › Export cones (JSON)…, open the file, and check one visible cone has believable x and y (measured from Origin toward Direction, y to the left).

Fix what they report (each fix tested and committed) before going on.

- [ ] **Step 7: Commit the README, merge and push**

```bash
git add README.md
git commit -m "README: part 1 status, how to build and test, layout, licence" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Use superpowers:finishing-a-development-branch. Once the owner's check has passed: merge `part1-core-canvas` into `main` (`git switch main && git merge --no-ff part1-core-canvas`), repeat Step 4's greps on `main`, run Step 2 once more, then `git push origin main`. Tell the owner: what part 1 delivered, that the old `Conestructor\build\` and `.qtcreator\` folders left from the prototype can be deleted, and that part 2 (setup and `.cone` files) is next.


