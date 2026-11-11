# Conestructor v1 part 2 (setup and track files) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a track something a team keeps: a setup checklist that unlocks the track pieces, one `.cone` file per track (photo embedded, documented with a schema), unsaved-changes safety (title, warning, recent files, command line, drag and drop, autosave), and the editing gaps from the part 1 check (direction arrows with driving order that follows them, Reverse direction, typed rotation that turns the chain, multi-select).

**Architecture:** Part 1's shape stays: the track is plain data in `TrackStore`, every edit is a pure command with snapshot undo, logic lives in tested `.mjs` modules. New logic modules build and read the `.cone` document (`conefile.mjs`), report setup progress (`setup.mjs`) and work out shared settings and box hits (`selection.mjs`). Two new C++ singletons do what JS cannot do well: `PhotoStore` keeps photo bytes by a small id (shown through an image provider, so bytes never enter the track or its undo snapshots) and `TrackFile` writes the JS-built text with the photo added last as base64, opens files, and keeps the autosave backup.

**Tech Stack:** Qt 6.11.1 (MSVC 2022 64-bit), Qt Quick / Controls (Fusion) / Shapes / Dialogs, CMake + Ninja, Qt Test (C++), qmltestrunner (QML/JS), PowerShell scripts in `app/tests`.

**Spec:** `docs/superpowers/specs/2026-11-10-part2-setup-and-track-files-design.md` (the roadmap and part 1 design are in `2026-11-10-v1-roadmap-and-part1-core-canvas-design.md`; part 1's plan `docs/superpowers/plans/2026-11-10-part1-core-canvas.md` explains the existing code).

## Global Constraints

- The repo is public. Never write the team server's public subdomain or the home-network address into code, docs, tests or commit messages; examples use `<public host>`.
- The two satellite images (`app/assets/images/duckPondBirdeye.png`, `riverwindBirdeye.png`) stay gitignored and are bundled only when present at build time. A clean clone must build without them.
- Files use metres. Export frame: x from the Origin target toward the Direction target; y 90° to the left of x seen from above; headings in degrees counter-clockwise from +x.
- `.cone` file: plain UTF-8 JSON; keys in the order `format`, `version`, `name`, `app`, `saved`, `units`, `axes`, `targets`, `cones`, `design`, `photo`; `format` is `"conestructor-track"`, `version` is `1`; the photo is the original file's bytes as base64, never re-encoded, always last; `photo` is `null` for the blueprint.
- Photo bytes never enter the track object or its undo snapshots (the track holds only a small `ref`).
- Units on screen are a preference (feet and inches default, decimal feet, metres); files always hold metres.
- Version 0.3.0 from CMake; window title `Conestructor 0.3 — <name>`, with `*` after the name while there are unsaved changes; `<name>` is the file name without `.cone`, or `Untitled`.
- Logic lives in pure JavaScript modules in `app/qml/logic/`, tested with qmltestrunner; QML only draws and forwards input; C++ services are QML singletons (`QML_ELEMENT`/`QML_SINGLETON`).
- `tst_qmlload` keeps `QTest::failOnWarning` in `init()`: any QML warning fails a test.
- Qt Quick gotchas from part 1: don't name an id after an Item property used inside delegates (`palette`, `layer`, `state`, `data`, `children`); `FileDialog` has a final `result` property; a Repeater delegate rebuilt by its own handler must not touch its ids after emitting; Repeater delegates have no QObject parent (tests walk `childItems()`).
- Build: `powershell -NoProfile -File app\tests\build.ps1`, test: `powershell -NoProfile -File app\tests\run.ps1` (Qt 6.11.1 MSVC at `D:\allNewQT6\6.11.1\msvc2022_64`, CMake/Ninja under `D:\allNewQT6\Tools`).
- Work on branch `part2-setup-files`; merge to `main` and push only after the owner's check and a look at what is being pushed.
- Every commit message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (passed as a second `-m`).

## Decisions this plan adds to the spec

- **Turns are stepped at the middle of each step's heading** (a true arc) instead of the prototype's start-of-step heading. With the old stepping a reversed turn could not land on its own footprint (its ends would move by up to about 1% of the radius); with the new stepping Reverse is exact, as the spec requires. A turn's cones move by a few centimetres against part 1. The port check's prototype fixture carries the same change, marked `PART 2 CHANGE` like the owner's slalom correction, so every other cone still matches the prototype exactly.
- **The port check compares cones as a set.** Part 2 deliberately changes the driving order (it follows the arrows), so the order is no longer the prototype's; positions, types and headings still must match exactly. The order is tested in `tst_postprocess`.
- **Separate chains are stitched by the nearest start, never reversed.** Each chain now has a direction of travel, so the next chain is the one whose start is nearest the end of the course so far. (The spec said "nearest end first"; reversing a chain would drive it against its arrows.)
- **`targets.direction` and `targets.distance` are `null` until Origin, Direction and the ruler's real length are all set**, since Direction cannot be given in the frame before that. `targets.origin` is `{ x: 0, y: 0 }` once Origin is placed.
- **Setup status is its own module, `logic/setup.mjs`** (the spec listed it under `conefile.mjs`; it has nothing to do with files).
- **`FileIO` becomes `TrackFile`** (its `toLocalPath` moves there; the JSON export and `tst_fileio` go). `PhotoStore` also has `remove(ref)` so a refused open drops the photo it took in.
- **New is no longer an undo step:** like Open, it empties the undo history and the photo store (the spec says so for the store; an undoable New would need the old photos kept).
- **Selection:** `TrackStore.selection` is a list (element ids, or one of `"ruler"`, `"origin"`, `"direction"` alone); `selectedId` and `selectedElement` are derived from it and are set only when exactly one thing is selected. A plain click on an element that is already part of a multi-selection keeps the selection (so it can be dragged) and reduces it to that element only if the pointer is released without dragging.
- **Every cone carries `element`** from post-processing (the id of the element that made it), so the file can write it.
- **The demo track uses the blueprint and counts as saved**, so tests and screenshots start with setup done and no `*`.
- **Start-up:** `main.cpp` calls the window's `start(file)` once (`file` is the command-line argument or `""`); it offers a backup first, then opens the file. `tst_qmlload` calls `start` only where it tests start-up, so no other test sees the backup question.
- **The two questions (unsaved changes, restore backup) are Qt Quick Controls `Dialog`s**, so the offscreen tests can click them; the file pickers stay `QtQuick.Dialogs` `FileDialog`s and the tests call the functions behind them.
- **The schema test reads `docs/cone-format.schema.json` with `XMLHttpRequest`**; `run.ps1` sets `QML_XHR_ALLOW_FILE_READ=1` for qmltestrunner.
- **Rotation field:** steps 1° (Shift+arrow 15°), accepts −360° to 360° and the command wraps it into −180° to 180°.

## Review Focus

1. **A `.cone` file someone edited by hand** (a setting out of its limits, a setting missing, a join that names an element that does not join back): out-of-limit values are kept within them, missing settings take their defaults, and a one-sided join makes the file "damaged" instead of loading a broken track. Pinned in Task 7 (`test_aHandEditedFileIsReadSafely`).
2. **A track path with spaces and accents** (`Piste d'été.cone` in a folder with a space): it saves, opens, and the title shows `Piste d'été`. Pinned in Task 8 (`aPathWithAccentsAndSpacesWorks`).
3. **Reverse on an element inside a closed loop:** every joint of the loop still meets afterwards and undo restores it exactly. Pinned in Task 5 (`test_reversingInsideAClosedLoopKeepsItClosed`).
4. **A full-size phone photo** (4000 × 3000): save and open keep its bytes identical and take a few seconds at most. Pinned in Task 8 (`aBigPhotoRoundTrips`).
5. **Ctrl+click on the ruler or a target while several elements are selected:** it selects that item alone (no mixed selection), and Delete then deletes only it. Pinned in Task 13 (inside `selectingSeveralElements`).

## File structure

```
app/CMakeLists.txt                     version 0.3.0; new sources and logic modules
app/main.cpp                           calls the window's start(file) with the command-line file
app/services/PhotoStore.h/.cpp         NEW: photo bytes by ref; image://photo/<ref> provider (QML singleton)
app/services/TrackFile.h/.cpp          NEW (replaces FileIO): save/open .cone, the photo spliced in last; autosave backup
app/services/FileIO.h/.cpp             DELETED
app/services/Settings.h/.cpp           + recent files
app/qml/logic/elements.mjs             true-arc turns; reversedProps/reversed; pointsAlong, pathLength, arrowMarks
app/qml/logic/postprocess.mjs          chains walked the way their arrows point; backwards(); cones carry element
app/qml/logic/frame.mjs                + headingFromFrame
app/qml/logic/snapping.mjs             + chainOf, turnAbout, findGroupSnap, groupToJoin
app/qml/logic/commands.mjs             photo {kind, ref}; + reverse, rotateChain, setProps, removeMany, duplicateMany, placeMany
app/qml/logic/selection.mjs            NEW: sharedProps, boxHits
app/qml/logic/setup.mjs                NEW: the four setup steps
app/qml/logic/conefile.mjs             NEW: track <-> .cone document (all but the photo bytes)
app/qml/logic/demo.mjs                 uses the blueprint
app/qml/TrackStore.qml                 selection list; file state (filePath, name, dirty); save/open/new; backwardIds
app/qml/Main.qml                       File menu, title, dialogs, drop area, autosave, start-up
app/qml/SetupChecklist.qml             NEW: the checklist
app/qml/PaletteTile.qml                NEW: one draggable tile (palette and checklist)
app/qml/ElementPalette.qml             track tiles only, locked until setup is done
app/qml/ElementView.qml                arrows, ⚠, handle only when one is selected
app/qml/CanvasView.qml                 photo from PhotoStore; Ctrl+click, box select, group drag; ⚠ tip; Reverse in menu
app/qml/PropertyPanel.qml              typed rotation; several elements' shared settings
app/qml/PropField.qml                  stepSize, bigStep (Shift+arrow), mixed
app/tests/CMakeLists.txt               + tst_photostore, tst_trackfile; - tst_fileio
app/tests/run.ps1                      QML_XHR_ALLOW_FILE_READ=1
app/tests/tst_photostore.cpp           NEW
app/tests/tst_trackfile.cpp            NEW (replaces tst_fileio.cpp)
app/tests/tst_settings.cpp             + recent files
app/tests/tst_qmlload.cpp              + photo, files, start-up, checklist, arrows/reverse/rotation, multi-select
app/tests/qml/tst_elements.qml         + reversed, pointsAlong, arrowMarks
app/tests/qml/tst_postprocess.qml      driving order tests
app/tests/qml/tst_portcheck.qml        set comparison
app/tests/qml/fixtures/prototype.mjs   PART 2 CHANGE: true-arc turn stepping
app/tests/qml/tst_commands.qml         + new commands
app/tests/qml/tst_snapping.qml         + group snapping
app/tests/qml/tst_frame.qml            + headingFromFrame
app/tests/qml/tst_selection.qml        NEW
app/tests/qml/tst_setup.qml            NEW
app/tests/qml/tst_conefile.qml         NEW (includes the schema check)
app/tests/qml/fixtures/schemacheck.mjs NEW: a small JSON Schema validator for the keywords our schema uses
docs/cone-format.md                    NEW: the file format for other apps
docs/cone-format.schema.json           NEW: JSON Schema (draft 2020-12)
README.md                              part 2 status; links to the format and schema; "read the cones" example
```

---

### Task 1: Branch, version 0.3.0 and `PhotoStore`

**Files:**
- Create: `app/services/PhotoStore.h`, `app/services/PhotoStore.cpp`, `app/tests/tst_photostore.cpp`
- Modify: `app/CMakeLists.txt` (version, sources), `app/tests/CMakeLists.txt`, `app/tests/tst_qmlload.cpp:60` (title)

**Interfaces:**
- Produces: QML singleton `PhotoStore` with `load(pathOrUrl: string) -> { ref, width, height } | { error }`, `url(ref: int) -> "image://photo/<ref>"`, `clear(keep: int)`, `remove(ref: int)`; C++ `int add(const QByteArray &)` (-1 if not a PNG/JPEG picture), `bool has(int)`, `QByteArray bytes(int)`, `QString mediaType(int)` (`image/png` or `image/jpeg`), `QSize size(int)`; class `PhotoProvider(std::shared_ptr<PhotoStore::Shelf>)`. The image provider id is `photo`, registered by `PhotoStore::create` on the engine that creates the singleton. Refs start at 1 and are never reused. Error text: `Could not open that photo. The background is unchanged.`

- [ ] **Step 1: Create the branch**

```bash
git switch -c part2-setup-files
```

- [ ] **Step 2: Write the failing test**

Create `app/tests/tst_photostore.cpp`:

```cpp
#include <QColor>
#include <QFile>
#include <QImage>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>

#include "services/PhotoStore.h"

class TestPhotoStore : public QObject
{
    Q_OBJECT

    QTemporaryDir dir;

    QString picture(const QString &name, const char *format, QSize size)
    {
        QImage image(size, QImage::Format_RGB32);
        image.fill(QColor(200, 40, 40));
        const QString path = dir.filePath(name);
        image.save(path, format);
        return path;
    }

    static QByteArray bytesOf(const QString &path)
    {
        QFile file(path);
        file.open(QIODevice::ReadOnly);
        return file.readAll();
    }

private slots:
    void aPngLoadsWithItsBytesAndSize()
    {
        const QString path = picture(QStringLiteral("lot.png"), "PNG", QSize(40, 30));
        PhotoStore store;
        const QVariantMap r = store.load(path);
        QVERIFY2(!r.contains(QStringLiteral("error")), qPrintable(r.value(QStringLiteral("error")).toString()));
        const int ref = r.value(QStringLiteral("ref")).toInt();
        QVERIFY(ref > 0);
        QCOMPARE(r.value(QStringLiteral("width")).toInt(), 40);
        QCOMPARE(r.value(QStringLiteral("height")).toInt(), 30);
        QCOMPARE(store.bytes(ref), bytesOf(path));
        QCOMPARE(store.mediaType(ref), QStringLiteral("image/png"));
        QCOMPARE(store.size(ref), QSize(40, 30));
        QCOMPARE(store.url(ref), QStringLiteral("image://photo/%1").arg(ref));
    }

    void aJpegLoadsFromAFileUrl()
    {
        const QString path = picture(QStringLiteral("lot.jpg"), "JPEG", QSize(32, 24));
        PhotoStore store;
        const QVariantMap r = store.load(QUrl::fromLocalFile(path).toString());
        const int ref = r.value(QStringLiteral("ref")).toInt();
        QVERIFY(ref > 0);
        QCOMPARE(store.mediaType(ref), QStringLiteral("image/jpeg"));
        QCOMPARE(store.bytes(ref), bytesOf(path));
    }

    void theProviderServesThePicture()
    {
        PhotoStore store;
        const int ref = store.add(bytesOf(picture(QStringLiteral("p.png"), "PNG", QSize(16, 8))));
        PhotoProvider provider(store.shelf());
        QSize size;
        const QImage image = provider.requestImage(QString::number(ref), &size, QSize());
        QCOMPARE(size, QSize(16, 8));
        QCOMPARE(image.pixelColor(3, 3), QColor(200, 40, 40));
        QVERIFY(provider.requestImage(QStringLiteral("999"), &size, QSize()).isNull());
    }

    void somethingElseIsRefused()
    {
        PhotoStore store;
        QCOMPARE(store.add(QByteArray("not a picture")), -1);
        QFile notes(dir.filePath(QStringLiteral("notes.png")));
        QVERIFY(notes.open(QIODevice::WriteOnly));
        notes.write("hello");
        notes.close();
        QCOMPARE(store.load(notes.fileName()).value(QStringLiteral("error")).toString(),
                 QStringLiteral("Could not open that photo. The background is unchanged."));
        QVERIFY(store.load(dir.filePath(QStringLiteral("missing.png"))).contains(QStringLiteral("error")));
    }

    void refsAreNeverReusedAndClearKeepsOne()
    {
        PhotoStore store;
        const QByteArray png = bytesOf(picture(QStringLiteral("c.png"), "PNG", QSize(4, 4)));
        const int a = store.add(png);
        const int b = store.add(png);
        QVERIFY(b > a);
        store.clear(b);
        QVERIFY(!store.has(a));
        QVERIFY(store.has(b));
        store.remove(b);
        QVERIFY(!store.has(b));
        QVERIFY(store.add(png) > b);
        store.clear(-1);
        QVERIFY(!store.has(b + 1));
    }
};

QTEST_MAIN(TestPhotoStore)
#include "tst_photostore.moc"
```

Add it to `app/tests/CMakeLists.txt` after the `tst_fileio` line:

```cmake
conestructor_test(tst_photostore SOURCES tst_photostore.cpp LIBS conestructor_core)
```

- [ ] **Step 3: Run it to see it fail**

Run: `powershell -NoProfile -File app\tests\build.ps1`
Expected: the build fails with `services/PhotoStore.h: No such file or directory`.

- [ ] **Step 4: Write `PhotoStore`**

Create `app/services/PhotoStore.h`:

```cpp
#pragma once
#include <QByteArray>
#include <QHash>
#include <QMutex>
#include <QObject>
#include <QQuickImageProvider>
#include <QSize>
#include <QString>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>
#include <memory>

class QJSEngine;
class QQmlEngine;

// Lot photos for this session, each under a small id ("ref") that is never reused. The track holds only the ref, so
// undo snapshots stay light; the bytes are the original file's, kept unchanged for saving into .cone files. QML shows
// a photo as image://photo/<ref>.
class PhotoStore : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    struct Photo
    {
        QByteArray bytes;
        QString mediaType;
        QSize size;
    };
    // Shared with the image provider, which may run on a loader thread and may outlive the store.
    struct Shelf
    {
        QMutex mutex;
        QHash<int, Photo> photos;
        int next = 1;
    };

    explicit PhotoStore(QObject *parent = nullptr);
    // QML creates the store through this, which also registers image://photo/ with that engine.
    static PhotoStore *create(QQmlEngine *engine, QJSEngine *);

    // Reads a PNG or JPEG from a path, a file: URL or a qrc: URL. Returns { ref, width, height } or { error }.
    Q_INVOKABLE QVariantMap load(const QString &pathOrUrl);
    // "image://photo/<ref>".
    Q_INVOKABLE QString url(int ref) const;
    // Forgets every photo but `keep` (-1 keeps none).
    Q_INVOKABLE void clear(int keep);
    Q_INVOKABLE void remove(int ref);

    // A photo from a file's bytes; its ref, or -1 when the bytes are not a PNG or JPEG picture.
    int add(const QByteArray &bytes);
    bool has(int ref) const;
    QByteArray bytes(int ref) const;
    QString mediaType(int ref) const;   // "image/png" or "image/jpeg"
    QSize size(int ref) const;          // as shown (after the photo's own orientation tag)

    std::shared_ptr<Shelf> shelf() const { return m_shelf; }

private:
    std::shared_ptr<Shelf> m_shelf;
};

// Serves image://photo/<ref> from a store's shelf.
class PhotoProvider : public QQuickImageProvider
{
public:
    explicit PhotoProvider(std::shared_ptr<PhotoStore::Shelf> shelf);
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    std::shared_ptr<PhotoStore::Shelf> m_shelf;
};
```

Create `app/services/PhotoStore.cpp`:

```cpp
#include "PhotoStore.h"

#include <QBuffer>
#include <QFile>
#include <QImage>
#include <QImageReader>
#include <QMutexLocker>
#include <QQmlEngine>
#include <QUrl>

namespace {

QString couldNotOpen()
{
    return PhotoStore::tr("Could not open that photo. The background is unchanged.");
}

// Decodes bytes as a picture; a null image when they are not one.
QImage decode(const QByteArray &bytes, QByteArray *format)
{
    QByteArray copy = bytes;
    QBuffer buffer(&copy);
    buffer.open(QIODevice::ReadOnly);
    QImageReader reader(&buffer);
    reader.setAutoTransform(true);
    if (format)
        *format = reader.format().toLower();
    return reader.read();
}

} // namespace

PhotoStore::PhotoStore(QObject *parent) : QObject(parent), m_shelf(std::make_shared<Shelf>()) {}

PhotoStore *PhotoStore::create(QQmlEngine *engine, QJSEngine *)
{
    auto *store = new PhotoStore;
    engine->addImageProvider(QStringLiteral("photo"), new PhotoProvider(store->shelf()));
    return store;
}

QVariantMap PhotoStore::load(const QString &pathOrUrl)
{
    QString path = pathOrUrl;
    const QUrl url(pathOrUrl);
    if (url.scheme() == QLatin1String("qrc"))
        path = QLatin1Char(':') + url.path();
    else if (url.isLocalFile())
        path = url.toLocalFile();
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return { { QStringLiteral("error"), couldNotOpen() } };
    const int ref = add(file.readAll());
    if (ref < 0)
        return { { QStringLiteral("error"), couldNotOpen() } };
    const QSize s = size(ref);
    return { { QStringLiteral("ref"), ref }, { QStringLiteral("width"), s.width() },
             { QStringLiteral("height"), s.height() } };
}

QString PhotoStore::url(int ref) const
{
    return QStringLiteral("image://photo/%1").arg(ref);
}

void PhotoStore::clear(int keep)
{
    QMutexLocker lock(&m_shelf->mutex);
    const Photo kept = m_shelf->photos.value(keep);
    const bool had = m_shelf->photos.contains(keep);
    m_shelf->photos.clear();
    if (had)
        m_shelf->photos.insert(keep, kept);
}

void PhotoStore::remove(int ref)
{
    QMutexLocker lock(&m_shelf->mutex);
    m_shelf->photos.remove(ref);
}

int PhotoStore::add(const QByteArray &bytes)
{
    QByteArray format;
    const QImage image = decode(bytes, &format);
    QString mediaType;
    if (format == "png")
        mediaType = QStringLiteral("image/png");
    else if (format == "jpeg" || format == "jpg")
        mediaType = QStringLiteral("image/jpeg");
    if (image.isNull() || mediaType.isEmpty())
        return -1;
    QMutexLocker lock(&m_shelf->mutex);
    const int ref = m_shelf->next++;
    m_shelf->photos.insert(ref, { bytes, mediaType, image.size() });
    return ref;
}

bool PhotoStore::has(int ref) const
{
    QMutexLocker lock(&m_shelf->mutex);
    return m_shelf->photos.contains(ref);
}

QByteArray PhotoStore::bytes(int ref) const
{
    QMutexLocker lock(&m_shelf->mutex);
    return m_shelf->photos.value(ref).bytes;
}

QString PhotoStore::mediaType(int ref) const
{
    QMutexLocker lock(&m_shelf->mutex);
    return m_shelf->photos.value(ref).mediaType;
}

QSize PhotoStore::size(int ref) const
{
    QMutexLocker lock(&m_shelf->mutex);
    return m_shelf->photos.value(ref).size;
}

PhotoProvider::PhotoProvider(std::shared_ptr<PhotoStore::Shelf> shelf)
    : QQuickImageProvider(QQuickImageProvider::Image), m_shelf(std::move(shelf))
{
}

QImage PhotoProvider::requestImage(const QString &id, QSize *size, const QSize &)
{
    QByteArray bytes;
    {
        QMutexLocker lock(&m_shelf->mutex);
        bytes = m_shelf->photos.value(id.toInt()).bytes;
    }
    const QImage image = bytes.isEmpty() ? QImage() : decode(bytes, nullptr);
    if (size)
        *size = image.size();
    return image;
}
```

In `app/CMakeLists.txt`, change the project line to `project(Conestructor VERSION 0.3.0 LANGUAGES CXX)` and add the files to `SOURCES` after the FileIO line:

```cmake
        services/PhotoStore.h services/PhotoStore.cpp
```

In `app/tests/tst_qmlload.cpp` `mainOpensWithTheTitle`, the expected title becomes `QStringLiteral("Conestructor 0.3 \u2014 Untitled")`.

- [ ] **Step 5: Run the tests**

Run: `powershell -NoProfile -File app\tests\build.ps1` then `powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed` (tst_photostore's five tests among them) and `qml: 180 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add app/services/PhotoStore.h app/services/PhotoStore.cpp app/tests/tst_photostore.cpp app/tests/CMakeLists.txt app/CMakeLists.txt app/tests/tst_qmlload.cpp
git commit -m "PhotoStore: lot photos by ref, served as image://photo/<ref>; version 0.3.0" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The track's photo is a kind and a ref

**Files:**
- Modify: `app/qml/logic/commands.mjs` (emptyTrack, setPhoto, label, header comment), `app/qml/logic/demo.mjs`, `app/qml/CanvasView.qml` (photo source), `app/qml/Main.qml` (loading photos), `app/tests/qml/tst_commands.qml`, `app/tests/tst_qmlload.cpp`

**Interfaces:**
- Consumes: `PhotoStore.load`, `PhotoStore.url` (Task 1).
- Produces: track field `photo: { kind: "none" | "blueprint" | "image", ref: int | null, metresPerPixel }`, key order `kind, ref, metresPerPixel`; command `setPhoto { kind, ref? }` labelled `Load photo` (image) or `Use blueprint` (blueprint); `Main.loadPhoto(url)` (a URL, path or qrc: URL; one undo step; a banner when it can't be read) and `Main.useBlueprint()`; CanvasView's photo `Image` has `objectName: "photo"`. `tst_qmlload` gains static helpers `allItems`, `findBanner(QQuickWindow *)`, `findButton(QQuickWindow *, const QString &text)`.

- [ ] **Step 1: Write the failing tests**

In `app/tests/qml/tst_commands.qml`:
- in `test_everyCommandUndoesAndRedoesExactly_data`, replace the `load photo` row with:

```js
            { tag: "load photo", name: "setPhoto", args: { kind: "image", ref: 3 } },
            { tag: "use the blueprint", name: "setPhoto", args: { kind: "blueprint" } },
```

- in `test_labels`, replace `["setPhoto", { path: "file:///x.png" }, "Load photo"],` with:

```js
            ["setPhoto", { kind: "image", ref: 1 }, "Load photo"],
            ["setPhoto", { kind: "blueprint" }, "Use blueprint"],
```

- in `test_nothingChangedRecordsNothing`, the command becomes `Commands.run(stack, t, "setPhoto", { kind: "none" })`.
- add:

```js
    function test_aPhotoIsOnlyItsRef() {
        const t = Commands.run(new Commands.UndoStack(), base(), "setPhoto", { kind: "image", ref: 7 })
        compare(JSON.stringify(t.photo), JSON.stringify({ kind: "image", ref: 7, metresPerPixel: 0.1 }))
        const b = Commands.run(new Commands.UndoStack(), t, "setPhoto", { kind: "blueprint", ref: 7 })
        compare(b.photo.ref, null)
        compare(JSON.stringify(Commands.emptyTrack().photo), JSON.stringify({ kind: "none", ref: null, metresPerPixel: 0 }))
    }
```

In `app/tests/tst_qmlload.cpp`, move the `allItems` helper out of the class's private section into a file-level `static` function above the class (keep the class's own copy deleted), and add two more file-level helpers next to it:

```cpp
// Every item drawn under `root` (Repeater delegates have no QObject parent, so findChildren misses them).
static QList<QQuickItem *> allItems(QQuickItem *root)
{
    QList<QQuickItem *> out;
    for (QQuickItem *child : root->childItems()) {
        out << child;
        out << allItems(child);
    }
    return out;
}

static QQuickItem *findBanner(QQuickWindow *window)
{
    for (QQuickItem *item : allItems(window->contentItem()))
        if (QByteArray(item->metaObject()->className()).startsWith("ErrorBanner"))
            return item;
    return nullptr;
}

// A visible button with this text (dialog buttons included: the overlay is under the content item).
static QQuickItem *findButton(QQuickWindow *window, const QString &text)
{
    for (QQuickItem *item : allItems(window->contentItem()))
        if (item->isVisible() && item->property("text").toString() == text
            && QByteArray(item->metaObject()->className()).contains("Button"))
            return item;
    return nullptr;
}
```

(`thePreviewAndTheExport`'s own `banner` lambda can stay; it does the same.) Add `#include <QFile>` and `#include <QImage>` if missing, and this test:

```cpp
    // A lot photo loads through PhotoStore as one undo step; something that is not a picture leaves it alone.
    void aLotPhotoLoadsAndUndoes()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QObject *photos = engine.singletonInstance<QObject *>("Conestructor", "PhotoStore");
        auto *photo = window->findChild<QQuickItem *>(QStringLiteral("photo"));
        QVERIFY(store && photos && photo);
        auto kind = [&]() {
            return qvariant_cast<QJSValue>(store->property("track")).property("photo").property("kind").toString();
        };

        QImage image(200, 100, QImage::Format_RGB32);
        image.fill(Qt::darkGreen);
        const QString path = dir.filePath(QStringLiteral("lot.png"));
        QVERIFY(image.save(path));
        QMetaObject::invokeMethod(window, "loadPhoto", Q_ARG(QVariant, QVariant(QUrl::fromLocalFile(path))));
        QCOMPARE(kind(), QStringLiteral("image"));
        QVERIFY(photo->property("source").toString().startsWith(QStringLiteral("image://photo/")));
        QTRY_COMPARE(photo->property("status").toInt(), 1);          // Image.Ready
        QCOMPARE(photo->property("implicitWidth").toDouble(), 200.0);
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Load photo"));

        QFile notes(dir.filePath(QStringLiteral("notes.png")));
        QVERIFY(notes.open(QIODevice::WriteOnly));
        notes.write("hello");
        notes.close();
        QMetaObject::invokeMethod(window, "loadPhoto", Q_ARG(QVariant, QVariant(QUrl::fromLocalFile(notes.fileName()))));
        QCOMPARE(findBanner(window)->property("text").toString(),
                 QStringLiteral("Could not open that photo. The background is unchanged."));
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Load photo"));

        // A bundled picture loads through its qrc: URL (the Backgrounds menu does this).
        QVariantMap loaded;
        QVERIFY(QMetaObject::invokeMethod(photos, "load", Q_RETURN_ARG(QVariantMap, loaded),
                                          Q_ARG(QString, QStringLiteral("qrc:/qt/qml/Conestructor/assets/images/blueprintBackground.png"))));
        QVERIFY(loaded.value(QStringLiteral("ref")).toInt() > 0);

        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(kind(), QStringLiteral("none"));
        QCOMPARE(photo->property("source").toString(),
                 QStringLiteral("qrc:/qt/qml/Conestructor/assets/images/blueprintBackground.png"));
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: qml failures in `Commands::test_aPhotoIsOnlyItsRef` and the `setPhoto` rows; `tst_qmlload` fails `aLotPhotoLoadsAndUndoes` (no `photo` item / no `loadPhoto`).

- [ ] **Step 3: Change the track and the command**

In `app/qml/logic/commands.mjs`:
- header comment line 2 becomes `//   { photo: { kind, ref, metresPerPixel },  kind "none" (not chosen), "blueprint" or "image"; ref a PhotoStore id`, and add a line under it: `//                                            (image only, else null); metresPerPixel comes from the ruler`.
- `emptyTrack()` returns `{ photo: { kind: "none", ref: null, metresPerPixel: 0 }, ruler: null, targets: { origin: null, direction: null }, elements: [], nextId: 1 }`.
- `setPhoto` becomes:

```js
    setPhoto(t, a) {
        t.photo.kind = a.kind
        t.photo.ref = a.kind === "image" ? a.ref : null
        return t
    },
```

- in `label`, `case "setPhoto": return a.kind === "blueprint" ? "Use blueprint" : "Load photo"`.

In `app/qml/logic/demo.mjs`, the first step becomes `["setPhoto", { kind: "blueprint" }],` (before `setRuler`), and the header comment says "on the blueprint (chosen, so setup counts it done)".

- [ ] **Step 4: Show the photo from PhotoStore**

In `app/qml/CanvasView.qml`, replace `readonly property string photoPath: TrackStore.track.photo.path` with:

```qml
    // The lot photo from PhotoStore, or the blueprint when there is none.
    readonly property string photoSource: {
        const p = TrackStore.track.photo
        return p.kind === "image" && p.ref !== null ? PhotoStore.url(p.ref) : blueprint
    }
```

replace `onPhotoPathChanged: fitPending = true` with `onPhotoSourceChanged: fitPending = true`, and in the `Image { id: photo ... }` add `objectName: "photo"` and set `source: canvas.photoSource`.

In `app/qml/Main.qml`:
- replace `function setBackground(path) {...}` with:

```qml
    // Loads a lot photo (a file dialog's URL, a path or a qrc: URL) as one undo step; a banner if it can't be read.
    function loadPhoto(url) {
        const r = PhotoStore.load(url.toString())
        if (r.error) {
            TrackStore.report(r.error, null)
            return
        }
        TrackStore.run("setPhoto", { kind: "image", ref: r.ref })
        TrackStore.seal()
    }

    function useBlueprint() {
        TrackStore.run("setPhoto", { kind: "blueprint" })
        TrackStore.seal()
    }
```

- Backgrounds menu: `MenuItem { text: qsTr("Blueprint"); onTriggered: window.useBlueprint() }`, and the local items `onTriggered: window.loadPhoto("qrc:/qt/qml/Conestructor/assets/images/" + modelData + ".png")`.
- `photoDialog`: `onAccepted: window.loadPhoto(selectedFile)`.
- delete the `Image { id: probe ... }` block and its comment (PhotoStore decodes the photo before it is used).

- [ ] **Step 5: Run the tests**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`, `qml: 183 passed, 0 failed` (or the new total, with 0 failed).

- [ ] **Step 6: Commit**

```bash
git add app/qml/logic/commands.mjs app/qml/logic/demo.mjs app/qml/CanvasView.qml app/qml/Main.qml app/tests/qml/tst_commands.qml app/tests/tst_qmlload.cpp
git commit -m "The track's photo is a kind and a PhotoStore ref, never its bytes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Elements — true-arc turns, reversed, points along the centreline

**Files:**
- Modify: `app/qml/logic/elements.mjs` (turn stepping; new exports), `app/tests/qml/fixtures/prototype.mjs` (the same stepping, marked), `app/tests/qml/tst_elements.qml`

**Interfaces:**
- Produces (in `elements.mjs`): `reversedProps(type, props) -> props`; `reversed(el) -> { x, y, rotation, props }` (the element driven the other way, same footprint: its new end A is where end B was); `pathLength(el) -> metres`; `pointsAlong(el, fractions: number[]) -> [{ x, y, heading }]` (canvas metres, heading clockwise on screen, fractions of the centreline's length from entry); `arrowMarks(el, spacing) -> [{ x, y, heading }]` (`max(2, round(length / spacing))` marks at the middles of equal pieces).

- [ ] **Step 1: Write the failing tests**

Add to `app/tests/qml/tst_elements.qml`:

```js
    function samePoint(a, b, tolerance, what) {
        verify(Math.hypot(a.x - b.x, a.y - b.y) <= tolerance,
               what + ": (" + a.x + ", " + a.y + ") vs (" + b.x + ", " + b.y + ")")
    }

    function sameHeading(a, b, what) {
        const d = ((((a - b) % 360) + 540) % 360) - 180
        verify(Math.abs(d) < 1e-6, what + ": " + a + " vs " + b)
    }

    function test_reversedKeepsTheFootprint_data() {
        return [
            { tag: "straight", type: "straight", props: {} },
            { tag: "slalom, 4 cones", type: "slalom", props: { leadIn: 3, leadOut: 9 } },
            { tag: "slalom, 3 cones, right first", type: "slalom", props: { coneCount: 3, firstTurn: "right" } },
            { tag: "chicane, uneven leads", type: "chicane", props: { leadIn: 2, leadOut: 11 } },
            { tag: "chicane right", type: "chicane", props: { direction: "right" } },
            { tag: "turn", type: "turn", props: {} },
            { tag: "turn, changing, left", type: "turn",
              props: { radiusType: "changing", radius: 6, exitRadius: 14, angle: 135, direction: "left", leadIn: 2 } },
            { tag: "turn of 0 degrees", type: "turn", props: { angle: 0 } },
            { tag: "turn, wide", type: "turn", props: { radius: 100, angle: 180 } }
        ]
    }

    function test_reversedKeepsTheFootprint(row) {
        const a = el("e1", row.type, row.props, 12, -7, 33)
        const b = Object.assign({}, a, Elements.reversed(a))
        const ea = Elements.endsWorld(a)
        const eb = Elements.endsWorld(b)
        samePoint(eb.A, ea.B, 1e-6, "new entry at the old exit")
        samePoint(eb.B, ea.A, 1e-6, "new exit at the old entry")
        sameHeading(eb.A.heading, ea.B.heading, "entry faces where the exit did")
        sameHeading(eb.B.heading, ea.A.heading, "exit faces where the entry did")
        const p = Elements.pathWorld(a)
        const q = Elements.pathWorld(b).slice().reverse()
        compare(q.length, p.length)
        for (let i = 0; i < p.length; i++)
            samePoint(q[i], p[i], 1e-6, "path point " + i)
    }

    function test_reversedPropsSaysTheSameThingTheOtherWay() {
        const t = Elements.reversedProps("turn", Object.assign(Elements.defaults("turn"),
                                         { leadIn: 2, leadOut: 8, radiusType: "changing", radius: 6, exitRadius: 12 }))
        compare(t.direction, "left")
        compare(t.leadIn, 8)
        compare(t.leadOut, 2)
        compare(t.radius, 12)
        compare(t.exitRadius, 6)
        compare(Elements.reversedProps("turn", Elements.defaults("turn")).exitRadius, 10)   // constant: untouched
        compare(Elements.reversedProps("slalom", Elements.defaults("slalom")).firstTurn, "left")    // 4 cones
        compare(Elements.reversedProps("slalom", Object.assign(Elements.defaults("slalom"), { coneCount: 3 })).firstTurn,
                "right")
        compare(Elements.reversedProps("chicane", Elements.defaults("chicane")).direction, "left")
    }

    function test_pointsAlongAStraight() {
        const s = el("e1", "straight", {}, 5, 5, 0)
        const p = Elements.pointsAlong(s, [0, 0.5, 1])
        samePoint(p[0], { x: -5, y: 5 }, 1e-9, "start")
        samePoint(p[1], { x: 5, y: 5 }, 1e-9, "middle")
        samePoint(p[2], { x: 15, y: 5 }, 1e-9, "end")
        compare(p[1].heading, 0)
        compare(Elements.pointsAlong(el("e2", "straight", {}, 0, 0, 90), [0.5])[0].heading, 90)
        fuzzyCompare(Elements.pathLength(s), 20, 1e-9)
    }

    function test_pointsAlongSkipsAnEmptyLead() {
        const t = el("e1", "turn", { leadIn: 0, leadOut: 0 }, 0, 0, 0)
        verify(Math.abs(Elements.pointsAlong(t, [0])[0].heading) < 1, "starts heading along +x")
    }

    function test_arrowMarks() {
        compare(Elements.arrowMarks(el("e1", "straight", {}), 8).length, 3)               // 20 m
        compare(Elements.arrowMarks(el("e1", "straight", { length: 4 }), 8).length, 2)    // at least two
        const marks = Elements.arrowMarks(el("e1", "straight", {}, 0, 0, 0), 8)
        fuzzyCompare(marks[0].x, -10 + 20 / 6, 1e-9)
    }

    function test_aHalfTurnIsATrueArc() {
        const g = Elements.geometry("turn", Object.assign(Elements.defaults("turn"), { leadIn: 0, leadOut: 0 }))
        near(g.ends.B.x - g.ends.A.x, 0, 1e-3, "level with the entry")
        near(g.ends.B.y - g.ends.A.y, 12, 1e-3, "exactly a 12 m diameter")
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_elements.qml`
Expected: FAIL — `Elements.reversed is not a function` (and the arc test's 1e-3 tolerance fails with the old stepping).

- [ ] **Step 3: Step turns at the middle of each step**

In `app/qml/logic/elements.mjs` `turn(p)`, change the comment above the loop and the heading line:

```js
    // The arc from the end of the lead-in, in the entry frame (start at 0, 0 heading +x). Each step runs along the
    // heading at its middle, so the steps are chords of the true arc and the turn driven backwards retraces it exactly
    // (the prototype used the heading at the start of each step).
    ...
        const h = (heading + turnSign * dTheta / 2) * Math.PI / 180
```

In `app/tests/qml/fixtures/prototype.mjs`, extend the header's last sentence to `The exceptions are marked OWNER'S CORRECTION (the slalom pointer cones) and PART 2 CHANGE (turn steps follow the heading at their middle).` and, in both stepping loops (`hairpinShape` and `hairpinCones`), replace `var headingRad = heading * Math.PI / 180` with:

```js
        // PART 2 CHANGE (2026-11-10): each step follows the heading at its middle, so turns are true arcs and a
        // reversed turn retraces its footprint. The prototype had `heading * Math.PI / 180` here.
        var headingRad = (heading + turnSign * dThetaDeg / 2) * Math.PI / 180
```

- [ ] **Step 4: Add reversed and the points along the centreline**

Append to `app/qml/logic/elements.mjs`:

```js
// ---- Driving an element the other way ----

const OTHER_SIDE = { left: "right", right: "left" }

// The settings that describe the same element driven exit to entry: leads swap; a turn bends the other way and its
// radii swap; a slalom with an odd number of cones weaves first to the other side; a chicane keeps its direction.
export function reversedProps(type, props) {
    const q = Object.assign({}, props)
    if ("leadIn" in props) {
        q.leadIn = props.leadOut
        q.leadOut = props.leadIn
    }
    if (type === "turn") {
        q.direction = OTHER_SIDE[props.direction]
        if (props.radiusType === "changing") {
            q.radius = props.exitRadius
            q.exitRadius = props.radius
        }
    } else if (type === "slalom" && props.coneCount % 2 === 1) {
        q.firstTurn = OTHER_SIDE[props.firstTurn]
    }
    return q
}

// The element driven the other way: { x, y, rotation, props } that put its new entry (end A) where its exit was,
// facing the same way, so the centreline and both ends stay where they were.
export function reversed(el) {
    const props = reversedProps(el.type, el.props)
    const exit = endsWorld(el).B
    const entry = geometry(el.type, props).ends.A
    const rotation = normalizeAngle(exit.heading - entry.heading)
    const at = toWorld({ x: 0, y: 0, rotation: rotation }, entry)
    return { x: exit.x - at.x, y: exit.y - at.y, rotation: rotation, props: props }
}

// ---- Along the centreline ----

function lengthsAlong(path) {
    const lengths = [0]
    for (let i = 1; i < path.length; i++)
        lengths.push(lengths[i - 1] + Math.hypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y))
    return lengths
}

export function pathLength(el) {
    const lengths = lengthsAlong(pathWorld(el))
    return lengths[lengths.length - 1]
}

// Points at these fractions (0 to 1) of the way along the centreline from entry to exit, in canvas metres, each with
// the centreline's heading there (degrees clockwise on screen). Pieces of no length (an empty lead) are skipped.
export function pointsAlong(el, fractions) {
    const path = pathWorld(el)
    const lengths = lengthsAlong(path)
    const total = lengths[lengths.length - 1]
    return fractions.map(f => {
        const want = Math.max(0, Math.min(1, f)) * total
        let i = 1
        while (i < path.length - 1 && (lengths[i] < want || lengths[i] === lengths[i - 1]))
            i++
        const a = path[i - 1]
        const b = path[i]
        const span = lengths[i] - lengths[i - 1]
        const t = span > 0 ? Math.max(0, Math.min(1, (want - lengths[i - 1]) / span)) : 0
        return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t,
                 heading: Math.atan2(b.y - a.y, b.x - a.x) * 180 / Math.PI }
    })
}

// Where the direction-of-travel arrows go: about one every `spacing` metres and at least two, each in the middle of
// an equal piece of the centreline.
export function arrowMarks(el, spacing) {
    const n = Math.max(2, Math.round(pathLength(el) / spacing))
    const fractions = []
    for (let i = 0; i < n; i++)
        fractions.push((i + 0.5) / n)
    return pointsAlong(el, fractions)
}
```

- [ ] **Step 5: Run every test**

Run: `powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`, `qml: … passed, 0 failed`. The port check still passes (both sides changed the same way). If an older elements test with a 0.05 m tolerance on a turn now fails, check the new value is the exact geometric one (closer to the hand-worked number) before tightening it; do not loosen any test.

- [ ] **Step 6: Commit**

```bash
git add app/qml/logic/elements.mjs app/tests/qml/fixtures/prototype.mjs app/tests/qml/tst_elements.qml
git commit -m "Elements: true-arc turns, reversed (same footprint), points and arrows along the centreline" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 4: Driving order follows the arrows

**Files:**
- Modify: `app/qml/logic/postprocess.mjs`, `app/tests/qml/tst_postprocess.qml`, `app/tests/qml/tst_portcheck.qml`

**Interfaces:**
- Consumes: element joins and `Elements.conesWorld` (part 1).
- Produces: `Post.chains(elements) -> [[{ id, forward }]]` (each joined chain in driving order; `forward` = driven entry → exit); `Post.backwards(elements) -> [id]` (elements driven exit → entry); every cone from `Post.run` (in `cones` and `canvasCones`) and from `Post.coneGroups` carries `element` (the id that made it). `Post.stitch(chains)` never reverses a chain.

- [ ] **Step 1: Write the failing tests**

In `app/tests/qml/tst_postprocess.qml`:
- replace `test_separateChainsAreStitchedByNearestEnd` with:

```js
    function test_separateChainsKeepTheirArrows() {
        // The second straight points back toward the first (rotation 180): it is driven from its entry at x 70.
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 60, y: 5, rotation: 180 }]
        ]))
        compare(JSON.stringify(xs(Post.run(t))), JSON.stringify([0, 0, 10, 10, 20, 20, 70, 70, 60, 60, 50, 50]))
    }
```

- in `test_aReversedElementIsWalkedTheRightWay`, add at the end (a tie follows the earliest element):

```js
        compare(JSON.stringify(Post.backwards(t.elements)), JSON.stringify(["e2"]))
```

- in `test_canvasConesMatchTheExportCones`, add `compare(r.cones[3].element, "e1")` and `compare(r.canvasCones[3].element, "e1")`.
- add:

```js
    function test_aChainBuiltBackwardsIsDrivenTheWayItsArrowsPoint() {
        // e2 is added in front of e1 (its exit joins e1's entry), so the chain is driven e2 then e1.
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "B", id: "e1", end: "A" } }]
        ]))
        compare(JSON.stringify(xs(Post.run(t))), JSON.stringify([-20, -20, -10, -10, 0, 0, 10, 10, 20, 20]))
        compare(JSON.stringify(Post.backwards(t.elements)), "[]")
    }

    function test_theMajorityDecides() {
        const t = build(scale().concat(targets(), [
            ["add", { type: "straight", x: 10, y: 5 }],
            ["add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } }],
            ["add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "B", id: "e2", end: "B" } }]     // e3 faces back
        ]))
        compare(JSON.stringify(xs(Post.run(t))), JSON.stringify([0, 0, 10, 10, 20, 20, 30, 30, 40, 40, 50, 50, 60, 60]))
        compare(JSON.stringify(Post.backwards(t.elements)), JSON.stringify(["e3"]))
        const steps = Post.chains(t.elements)
        compare(steps.length, 1)
        compare(JSON.stringify(steps[0]), JSON.stringify([{ id: "e1", forward: true }, { id: "e2", forward: true },
                                                          { id: "e3", forward: false }]))
    }

    function test_aClosedLoopStartsAtItsEarliestElement() {
        const turn = { angle: 90, radius: 6, leadIn: 0, leadOut: 0 }
        let t = build(scale().concat(targets(), [
            ["add", { type: "turn", x: 20, y: 20, props: turn }],
            ["add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: "e1", end: "B" } }],
            ["add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: "e2", end: "B" } }],
            ["add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: "e3", end: "B" } }]
        ]))
        t = Commands.clone(t)
        Snapping.join(t.elements, "e4", "B", "e1", "A")
        const steps = Post.chains(t.elements)
        compare(steps.length, 1)
        compare(steps[0].map(s => s.id).join(","), "e1,e2,e3,e4")
        verify(steps[0].every(s => s.forward))
    }
```

In `app/tests/qml/tst_portcheck.qml`, change the header comment's last sentence to `... become counter-clockwise. Part 2 orders cones by the arrows (tested in tst_postprocess), so here the cones are compared as a set: every prototype cone must match one of ours exactly.` and replace the loop in `test_conesMatchThePrototype` (from `for (let i = 0; i < theirs.length; i++) {` to its closing brace) with:

```js
        const unmatched = ours.cones.slice()
        for (let i = 0; i < theirs.length; i++) {
            const b = theirs[i]
            const k = unmatched.findIndex(a => a.type === b.coneType
                                          && Math.abs(a.x - b.x * Units.FOOT) < 1e-6
                                          && Math.abs(a.y + b.y * Units.FOOT) < 1e-6
                                          && angleGap(a.heading, -b.heading) < 1e-6)
            verify(k >= 0, "prototype cone " + i + " (" + b.coneType + " at " + (b.x * Units.FOOT) + ", "
                           + (-b.y * Units.FOOT) + ") has no match")
            unmatched.splice(k, 1)
        }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\run.ps1 -NoCpp -Qml tst_postprocess.qml`
Expected: FAIL — `Post.backwards is not a function`, and the separate-chains order is the old one.

- [ ] **Step 3: Walk chains the way their arrows point**

In `app/qml/logic/postprocess.mjs`:
- header comment: replace `joined chains walked from an open end` with `joined chains walked the way most of their elements point (part 2)`, and `separate chains stitched nearest end first` with `separate chains stitched by the nearest start`.
- `coneGroups` becomes:

```js
// Each element's cones in canvas metres, in the element's own order (entry A to exit B), each naming its element.
export function coneGroups(elements) {
    return elements.map(el => ({ id: el.id, cones: Elements.conesWorld(el).map(c => Object.assign(c, { element: el.id })) }))
}
```

- replace `walk` and `buildChains` with:

```js
function byId(elements, id) {
    return elements.find(e => e.id === id)
}

// One joined chain from `start`, entered at `enter`: [{ id, forward }] in walking order (forward = entered at A).
function walkSteps(elements, start, enter) {
    const steps = []
    const seen = []
    let current = start
    let at = enter
    while (current && seen.indexOf(current.id) < 0) {
        seen.push(current.id)
        steps.push({ id: current.id, forward: at === "A" })
        const mate = current.joins[at === "A" ? "B" : "A"]
        if (mate && seen.indexOf(mate.id) < 0) {
            current = byId(elements, mate.id)
            at = mate.end
        } else {
            current = null
        }
    }
    return steps
}

// The same chain walked the other way. A closed loop keeps its first element first.
function turnedAround(steps, loop) {
    const order = loop ? [steps[0]].concat(steps.slice(1).reverse()) : steps.slice().reverse()
    return order.map(s => ({ id: s.id, forward: !s.forward }))
}

// Walked the way most of its elements point; on a tie, the way its earliest element in the list points.
function oriented(elements, steps, loop) {
    const forward = steps.filter(s => s.forward).length
    const backward = steps.length - forward
    let turn = backward > forward
    if (backward === forward) {
        const index = id => elements.findIndex(e => e.id === id)
        const earliest = steps.reduce((a, b) => index(b.id) < index(a.id) ? b : a)
        turn = !earliest.forward
    }
    return turn ? turnedAround(steps, loop) : steps
}

// Every joined chain in driving order: chains with an open end in the order their first element appears in the list,
// then closed loops from their earliest element.
export function chains(elements) {
    const visited = []
    const out = []
    for (const el of elements) {
        if (visited.indexOf(el.id) >= 0 || (el.joins.A !== null && el.joins.B !== null))
            continue
        const steps = walkSteps(elements, el, el.joins.A === null ? "A" : "B")
        steps.forEach(s => visited.push(s.id))
        out.push(oriented(elements, steps, false))
    }
    for (const el of elements) {
        if (visited.indexOf(el.id) >= 0)
            continue
        const steps = walkSteps(elements, el, "A")
        steps.forEach(s => visited.push(s.id))
        out.push(oriented(elements, steps, true))
    }
    return out
}

// The elements driven exit to entry: against the rest of their chain.
export function backwards(elements) {
    const out = []
    for (const steps of chains(elements))
        for (const s of steps)
            if (!s.forward)
                out.push(s.id)
    return out
}

// Cone lists, one per joined chain, in driving order.
export function buildChains(elements, groups) {
    const out = []
    for (const steps of chains(elements)) {
        const cones = []
        for (const s of steps) {
            const own = groups.find(g => g.id === s.id).cones
            if (s.forward)
                for (const c of own) cones.push(c)
            else
                for (let i = own.length - 1; i >= 0; i--) cones.push(own[i])
        }
        if (cones.length > 0)
            out.push(cones)
    }
    return out
}
```

- `stitch` becomes:

```js
// Chains joined into one list: from the first, the next chain is the one whose start is nearest the end so far.
// Chains are never reversed: each is driven the way its arrows point.
export function stitch(chains) {
    if (chains.length === 0)
        return []
    const remaining = chains.slice()
    let ordered = remaining.shift().slice()
    while (remaining.length > 0) {
        const end = ordered[ordered.length - 1]
        let best = 0
        for (let i = 1; i < remaining.length; i++)
            if (distance(end, remaining[i][0]) < distance(end, remaining[best][0]))
                best = i
        ordered = ordered.concat(remaining.splice(best, 1)[0])
    }
    return ordered
}
```

- in `run`, both pushes gain the element: `cones.push({ index: index, type: c.type, x: q.x, y: q.y, heading: Frame.headingToFrame(frame, c.heading), element: c.element })` and `canvasCones.push({ index: index, type: c.type, x: c.x, y: c.y, heading: c.heading, element: c.element })`.

- [ ] **Step 4: Run every test**

Run: `powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`, `qml: … passed, 0 failed` (the port check included).

- [ ] **Step 5: Commit**

```bash
git add app/qml/logic/postprocess.mjs app/tests/qml/tst_postprocess.qml app/tests/qml/tst_portcheck.qml
git commit -m "Driving order follows the arrows; cones name their element; port check compares cones as a set" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Reverse direction and typed rotation (commands)

**Files:**
- Modify: `app/qml/logic/frame.mjs`, `app/qml/logic/snapping.mjs`, `app/qml/logic/commands.mjs`, `app/tests/qml/tst_frame.qml`, `app/tests/qml/tst_commands.qml`

**Interfaces:**
- Consumes: `Elements.reversed` (Task 3).
- Produces: `Frame.headingFromFrame(frame, heading) -> canvas heading`; `Snapping.chainOf(elements, id) -> [id]` (every element joined to `id`, directly or through others, `id` first); `Snapping.turnAbout(elements, ids, pivot, degrees)` (changes them); commands `reverse { ids: [id] }` (label `Reverse <Type>` or `Reverse <n> elements`) and `rotateChain { id, rotation }` (canvas degrees; label `Rotate <Type>`; the merge key comes from `args.mergeKey`). `tst_commands.qml` gains helpers `meets`, `allJoinsHold`, `ring` (used again in Task 6).

- [ ] **Step 1: Write the failing tests**

Add to `app/tests/qml/tst_frame.qml`:

```js
    function test_headingFromFrameUndoesHeadingToFrame() {
        const f = Frame.makeFrame({ x: 37, y: 120 }, { x: 410, y: -55 }, 0.073)
        for (const h of [0, 33, -90, 179, -150])
            verify(Math.abs(Frame.normalize(Frame.headingFromFrame(f, Frame.headingToFrame(f, h)) - h)) < 1e-9, "heading " + h)
        compare(Frame.headingFromFrame(upFrame(), 0), -90)
    }
```

In `app/tests/qml/tst_commands.qml`, add rows to `test_everyCommandUndoesAndRedoesExactly_data`:

```js
            { tag: "reverse the turn", name: "reverse", args: { ids: ["e2"] } },
            { tag: "reverse two", name: "reverse", args: { ids: ["e1", "e2"] } },
            { tag: "type a rotation", name: "rotateChain", args: { id: "e1", rotation: 90 } },
```

add to `test_labels`' steps (before the `setPhoto` rows):

```js
            ["reverse", { ids: ["e2"] }, "Reverse Turn"],
            ["reverse", { ids: ["e1", "e2"] }, "Reverse 2 elements"],
            ["rotateChain", { id: "e1", rotation: 45 }, "Rotate Straight"],
```

and add:

```js
    function meets(track, aId, aEnd, bId, bEnd) {
        const pa = Elements.endsWorld(byId(track, aId))[aEnd]
        const pb = Elements.endsWorld(byId(track, bId))[bEnd]
        return Math.hypot(pa.x - pb.x, pa.y - pb.y) < 1e-6
    }

    // Every join is mutual and its ends meet; returns how many ends are joined.
    function allJoinsHold(t) {
        let n = 0
        for (const el of t.elements)
            for (const end of ["A", "B"]) {
                const mate = el.joins[end]
                if (!mate)
                    continue
                n += 1
                compare(byId(t, mate.id).joins[mate.end].id, el.id, el.id + "." + end + " is joined back")
                verify(meets(t, el.id, end, mate.id, mate.end), el.id + "." + end + " meets its mate")
            }
        return n
    }

    // Four quarter turns joined into a closed ring.
    function ring() {
        const turn = { angle: 90, radius: 6, leadIn: 0, leadOut: 0 }
        const s = new Commands.UndoStack()
        let t = Commands.run(s, Commands.emptyTrack(), "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 })
        t = Commands.run(s, t, "add", { type: "turn", x: 20, y: 20, props: turn })
        for (const id of ["e1", "e2", "e3"])
            t = Commands.run(s, t, "add", { type: "turn", x: 0, y: 0, props: turn, snap: { ownEnd: "A", id: id, end: "B" } })
        const e1 = byId(t, "e1")
        return Commands.run(s, t, "place", { id: "e1", x: e1.x, y: e1.y, rotation: e1.rotation,
                                             snap: { ownEnd: "A", id: "e4", end: "B" } })
    }

    function test_reversingKeepsTheChainJoined() {
        const t0 = base()
        const t = Commands.run(new Commands.UndoStack(), t0, "reverse", { ids: ["e2"] })
        const e2 = byId(t, "e2")
        compare(e2.props.direction, "left")
        compare(e2.joins.A.id, "e3")
        compare(e2.joins.B.id, "e1")
        compare(JSON.stringify(byId(t, "e1").joins.B), JSON.stringify({ id: "e2", end: "B" }))
        compare(JSON.stringify(byId(t, "e3").joins.A), JSON.stringify({ id: "e2", end: "A" }))
        compare(allJoinsHold(t), 4)
        for (const id of ["e1", "e3"]) {
            compare(byId(t, id).x, byId(t0, id).x)
            compare(byId(t, id).y, byId(t0, id).y)
            compare(byId(t, id).rotation, byId(t0, id).rotation)
        }
    }

    function test_reversingTwiceIsWhereYouStarted() {
        const t0 = base()
        const s = new Commands.UndoStack()
        const t = Commands.run(s, Commands.run(s, t0, "reverse", { ids: ["e2"] }), "reverse", { ids: ["e2"] })
        const a = byId(t0, "e2")
        const b = byId(t, "e2")
        compare(JSON.stringify(b.props), JSON.stringify(a.props))
        compare(JSON.stringify(b.joins), JSON.stringify(a.joins))
        verify(Math.abs(b.x - a.x) < 1e-9 && Math.abs(b.y - a.y) < 1e-9, "same place")
        verify(Math.abs(Elements.normalizeAngle(b.rotation - a.rotation)) < 1e-9, "same rotation")
    }

    function test_reversingInsideAClosedLoopKeepsItClosed() {
        const t0 = ring()
        const stack = new Commands.UndoStack()
        const t = Commands.run(stack, t0, "reverse", { ids: ["e2"] })
        compare(allJoinsHold(t), 8)
        compare(JSON.stringify(stack.undo()), JSON.stringify(t0))
    }

    function test_typingARotationTurnsTheWholeChain() {
        const t0 = base()
        const t = Commands.run(new Commands.UndoStack(), t0, "rotateChain", { id: "e1", rotation: 90 })
        compare(byId(t, "e1").rotation, 90)
        compare(byId(t, "e1").x, byId(t0, "e1").x)
        compare(byId(t, "e1").y, byId(t0, "e1").y)
        compare(allJoinsHold(t), 4)
        verify(Math.abs(Elements.normalizeAngle(byId(t, "e3").rotation - byId(t0, "e3").rotation - 90)) < 1e-9,
               "the far end turned too")
    }

    function test_anUnjoinedElementTurnsAlone() {
        const s = new Commands.UndoStack()
        const t0 = Commands.run(s, base(), "add", { type: "slalom", x: 40, y: 40 })
        const t = Commands.run(s, t0, "rotateChain", { id: "e4", rotation: -30 })
        compare(byId(t, "e4").rotation, -30)
        for (const id of ["e1", "e2", "e3"])
            compare(JSON.stringify(byId(t, id)), JSON.stringify(byId(t0, id)))
    }

    function test_aTypedRotationWraps() {
        const t = Commands.run(new Commands.UndoStack(), base(), "rotateChain", { id: "e1", rotation: 270 })
        compare(byId(t, "e1").rotation, -90)
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\run.ps1 -NoCpp`
Expected: FAIL — `Frame.headingFromFrame is not a function`, `Unknown command reverse`, `Unknown command rotateChain`.

- [ ] **Step 3: Add `headingFromFrame`, `chainOf`, `turnAbout`**

Append to `app/qml/logic/frame.mjs`:

```js
// An export heading (counter-clockwise from +x) as a canvas heading (clockwise on screen).
export function headingFromFrame(frame, heading) {
    return normalize(frame.theta - heading)
}
```

Append to `app/qml/logic/snapping.mjs`:

```js
// Every element joined to `id`, directly or through others; `id` first.
export function chainOf(elements, id) {
    const out = [id]
    for (let i = 0; i < out.length; i++) {
        const el = byId(elements, out[i])
        for (const end of ["A", "B"]) {
            const mate = el.joins[end]
            if (mate && out.indexOf(mate.id) < 0)
                out.push(mate.id)
        }
    }
    return out
}

// Turns elements `ids` as one about `pivot` (canvas metres) by `degrees` (clockwise on screen). Changes them.
export function turnAbout(elements, ids, pivot, degrees) {
    const r = degrees * Math.PI / 180
    const c = Math.cos(r)
    const s = Math.sin(r)
    for (const id of ids) {
        const el = byId(elements, id)
        const dx = el.x - pivot.x
        const dy = el.y - pivot.y
        el.x = pivot.x + dx * c - dy * s
        el.y = pivot.y + dx * s + dy * c
        el.rotation = Elements.normalizeAngle(el.rotation + degrees)
    }
}
```

- [ ] **Step 4: Add the commands**

In `app/qml/logic/commands.mjs` `COMMANDS`, add after `duplicate`:

```js
    // Drives each element the other way, in place: same footprint, entry and exit swapped, joins kept.
    reverse(t, a) {
        for (const id of a.ids) {
            const el = find(t, id)
            Object.assign(el, Elements.reversed(el))
            el.joins = { A: el.joins.B, B: el.joins.A }
            for (const end of ["A", "B"]) {
                const mate = el.joins[end]
                if (mate)
                    find(t, mate.id).joins[mate.end] = { id: el.id, end: end }
            }
        }
        return t
    },
    // A typed rotation: the element's whole joined chain turns about the element's middle and stays joined.
    rotateChain(t, a) {
        const el = find(t, a.id)
        const rotation = Elements.normalizeAngle(a.rotation)
        const turn = Elements.normalizeAngle(rotation - el.rotation)
        Snapping.turnAbout(t.elements, Snapping.chainOf(t.elements, el.id), { x: el.x, y: el.y }, turn)
        el.rotation = rotation
        return t
    }
```

and in `label`, before the closing of the `switch`:

```js
    case "reverse": return "Reverse " + (a.ids.length === 1 ? named(a.ids[0]) : a.ids.length + " elements")
    case "rotateChain": return "Rotate " + named(a.id)
```

- [ ] **Step 5: Run every test**

Run: `powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`, `qml: … passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add app/qml/logic/frame.mjs app/qml/logic/snapping.mjs app/qml/logic/commands.mjs app/tests/qml/tst_frame.qml app/tests/qml/tst_commands.qml
git commit -m "Commands: reverse (same footprint, joins kept) and rotateChain (typed rotation turns the chain)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Several elements at once (logic)

**Files:**
- Create: `app/qml/logic/selection.mjs`, `app/tests/qml/tst_selection.qml`
- Modify: `app/qml/logic/snapping.mjs`, `app/qml/logic/commands.mjs`, `app/CMakeLists.txt` (QML_FILES), `app/tests/qml/tst_snapping.qml`, `app/tests/qml/tst_commands.qml`

**Interfaces:**
- Consumes: `Snapping.turnAbout`, `Snapping.placeToJoin`; `tst_commands` helpers `meets`, `allJoinsHold` (Task 5).
- Produces: `Selection.sharedProps(elements) -> [{ def, value, mixed }]` (settings every element shows now, in the first element's order; `value` null when `mixed`); `Selection.boxHits(elements, cornerA, cornerB) -> [id]` (canvas metres; elements whose band the box touches); `Snapping.findGroupSnap(elements, group, maxDistance) -> { ownId, ownEnd, targetId, targetEnd, distance } | null`; `Snapping.groupToJoin(group, ownId, ownEnd, target, targetEnd) -> group copies`; commands `setProps { ids, key, value }` (label `Change <Label>` plus ` (<n> elements)` when more than one), `removeMany { ids }` (`Delete <Type>` / `Delete <n> elements`), `duplicateMany { ids }` (`Duplicate <Type>` / `Duplicate <n> elements`; copies offset 2 m keep joins between them; their ids follow `nextId` in the order given), `placeMany { moves: [{ id, x, y, rotation }], snap: { ownId, ownEnd, id, end } | null, verb?, mergeKey? }` (`Move <Type>` / `Move <n> elements`).

- [ ] **Step 1: Write the failing tests**

Create `app/tests/qml/tst_selection.qml`:

```qml
import QtQuick
import QtTest
import "../../qml/logic/elements.mjs" as Elements
import "../../qml/logic/selection.mjs" as Selection

TestCase {
    name: "Selection"

    function el(id, type, props, x, y, rotation) {
        return { id: id, type: type, x: x || 0, y: y || 0, rotation: rotation || 0,
                 props: Object.assign(Elements.defaults(type), props || {}), joins: { A: null, B: null } }
    }

    function keys(list) {
        return list.map(s => s.def.key).join(",")
    }

    function test_aStraightAndATurnShareOnlyTheTrackWidth() {
        compare(keys(Selection.sharedProps([el("e1", "straight"), el("e2", "turn")])), "trackWidth")
    }

    function test_turnsAndChicanesShareLeadsAndDirection() {
        compare(keys(Selection.sharedProps([el("e1", "turn"), el("e2", "chicane")])), "leadIn,leadOut,direction,trackWidth")
    }

    function test_differentValuesAreMixed() {
        const shared = Selection.sharedProps([el("e1", "straight", { trackWidth: 4 }), el("e2", "straight", { trackWidth: 5 })])
        const width = shared.find(s => s.def.key === "trackWidth")
        verify(width.mixed)
        compare(width.value, null)
        const length = shared.find(s => s.def.key === "length")
        verify(!length.mixed)
        compare(length.value, 20)
    }

    function test_exitRadiusOnlyWhenAllAreChanging() {
        const changing = { radiusType: "changing" }
        verify(keys(Selection.sharedProps([el("e1", "turn", changing), el("e2", "turn", changing)])).indexOf("exitRadius") >= 0)
        const mixed = Selection.sharedProps([el("e1", "turn", changing), el("e2", "turn")])
        compare(keys(mixed).indexOf("exitRadius"), -1)
        verify(mixed.find(s => s.def.key === "radiusType").mixed)
    }

    function test_nothingSelectedSharesNothing() {
        compare(Selection.sharedProps([]).length, 0)
    }

    function test_aBoxTouchingTheBandSelects() {
        // A 20 m straight from (0, 5) to (20, 5), 4 m wide: its band runs from y 3 to y 7.
        const list = [el("e1", "straight", {}, 10, 5, 0)]
        compare(JSON.stringify(Selection.boxHits(list, { x: 8, y: 6.5 }, { x: 12, y: 8 })), JSON.stringify(["e1"]))
        compare(JSON.stringify(Selection.boxHits(list, { x: 12, y: 8 }, { x: 8, y: 6.5 })), JSON.stringify(["e1"]))
        compare(JSON.stringify(Selection.boxHits(list, { x: 9, y: 4.5 }, { x: 11, y: 5.5 })), JSON.stringify(["e1"]))
        compare(Selection.boxHits(list, { x: 8, y: -1 }, { x: 12, y: 1 }).length, 0)
        compare(Selection.boxHits(list, { x: 25, y: 4 }, { x: 30, y: 6 }).length, 0)
    }
}
```

Add to `app/tests/qml/tst_snapping.qml` (and `import "../../qml/logic/commands.mjs" as Commands` at the top):

```js
    // e1 and e2 joined along the screen at y 5 (0 to 40 m); e3 alone, pointing down the screen from (70, 20).
    function groupTrack() {
        const s = new Commands.UndoStack()
        let t = Commands.run(s, Commands.emptyTrack(), "setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 })
        t = Commands.run(s, t, "add", { type: "straight", x: 10, y: 5 })
        t = Commands.run(s, t, "add", { type: "straight", x: 0, y: 0, snap: { ownEnd: "A", id: "e1", end: "B" } })
        t = Commands.run(s, t, "add", { type: "straight", x: 70, y: 30, rotation: 90 })
        return t
    }

    function shifted(t, ids, dx, dy) {
        return ids.map(id => {
            const e = Commands.clone(t).elements.find(x => x.id === id)
            e.x += dx
            e.y += dy
            return e
        })
    }

    // Ends meet within 1e-6 m, facing opposite ways (a turned group carries a little rounding).
    function meetWell(a, aEnd, b, bEnd) {
        const pa = Elements.endsWorld(a)[aEnd]
        const pb = Elements.endsWorld(b)[bEnd]
        const turn = (((pa.heading - pb.heading) % 360) + 360) % 360
        return Math.hypot(pa.x - pb.x, pa.y - pb.y) < 1e-6 && Math.abs(turn - 180) < 1e-6
    }

    function test_aGroupSnapsAsOne() {
        const t = groupTrack()
        const group = shifted(t, ["e1", "e2"], 25, 5)
        const s = Snapping.findGroupSnap(t.elements, group, 15)
        compare(s.ownId, "e2")
        compare(s.ownEnd, "B")
        compare(s.targetId, "e3")
        compare(s.targetEnd, "A")
        const e3 = t.elements.find(e => e.id === "e3")
        const placed = Snapping.groupToJoin(group, s.ownId, s.ownEnd, e3, s.targetEnd)
        const p1 = placed.find(e => e.id === "e1")
        const p2 = placed.find(e => e.id === "e2")
        verify(meetWell(p2, "B", e3, "A"), "the group's open end meets e3")
        verify(meetWell(p1, "B", p2, "A"), "the join inside the group still meets")
        compare(Math.round(p2.rotation), 90)
        compare(group[1].x, t.elements[1].x + 25)     // the group passed in is not changed
    }

    function test_endsJoinedInsideTheGroupDoNotSnap() {
        const lone = Commands.clone(groupTrack())
        lone.elements = lone.elements.filter(e => e.id !== "e3")
        compare(Snapping.findGroupSnap(lone.elements, shifted(lone, ["e1", "e2"], 1, 1), 15), null)
    }
```

Add to `app/tests/qml/tst_commands.qml` rows in `test_everyCommandUndoesAndRedoesExactly_data`:

```js
            { tag: "change two widths", name: "setProps", args: { ids: ["e1", "e3"], key: "trackWidth", value: 6 } },
            { tag: "delete two", name: "removeMany", args: { ids: ["e1", "e3"] } },
            { tag: "duplicate two", name: "duplicateMany", args: { ids: ["e1", "e2"] } },
            { tag: "drag two", name: "placeMany",
              args: { moves: [{ id: "e1", x: 40, y: 40, rotation: 0 }, { id: "e2", x: 60, y: 40, rotation: 0 }], snap: null } },
```

and these tests:

```js
    function test_severalElementsChangeTogether() {
        const stack = new Commands.UndoStack()
        const t = Commands.run(stack, base(), "setProps", { ids: ["e1", "e2"], key: "trackWidth", value: 50 })
        compare(byId(t, "e1").props.trackWidth, 20)
        compare(byId(t, "e2").props.trackWidth, 20)
        compare(stack.undoLabel(), "Change Track width (2 elements)")
        stack.seal()
        const t2 = Commands.run(stack, t, "setProps", { ids: ["e1", "e3"], key: "length", value: 30 })
        compare(byId(t2, "e3").props.length, 30)
        compare(allJoinsHold(t2), 4)
        const one = Commands.run(new Commands.UndoStack(), base(), "setProps", { ids: ["e2"], key: "radius", value: 8 })
        compare(byId(one, "e2").props.radius, 8)
    }

    function test_deletingSeveral() {
        const stack = new Commands.UndoStack()
        const t = Commands.run(stack, base(), "removeMany", { ids: ["e1", "e3"] })
        compare(t.elements.length, 1)
        compare(JSON.stringify(byId(t, "e2").joins), JSON.stringify({ A: null, B: null }))
        compare(stack.undoLabel(), "Delete 2 elements")
        Commands.run(stack, base(), "removeMany", { ids: ["e2"] })
        compare(stack.undoLabel(), "Delete Turn")
    }

    function test_duplicatingSeveralKeepsTheirJoins() {
        const stack = new Commands.UndoStack()
        const t0 = base()
        const t = Commands.run(stack, t0, "duplicateMany", { ids: ["e1", "e2"] })
        compare(t.elements.length, 5)
        compare(JSON.stringify(byId(t, "e4").joins), JSON.stringify({ A: null, B: { id: "e5", end: "A" } }))
        compare(JSON.stringify(byId(t, "e5").joins), JSON.stringify({ A: { id: "e4", end: "B" }, B: null }))
        compare(byId(t, "e4").x, byId(t0, "e1").x + 2)
        compare(byId(t, "e5").y, byId(t0, "e2").y + 2)
        compare(t.nextId, 6)
        compare(stack.undoLabel(), "Duplicate 2 elements")
        compare(allJoinsHold(t), 6)
    }

    function test_aGroupDragKeepsInnerJoinsAndBreaksOuterOnes() {
        const t0 = base()
        const e1 = byId(t0, "e1")
        const e2 = byId(t0, "e2")
        const stack = new Commands.UndoStack()
        const t = Commands.run(stack, t0, "placeMany", {
            moves: [{ id: "e1", x: e1.x + 30, y: e1.y, rotation: e1.rotation },
                    { id: "e2", x: e2.x + 30, y: e2.y, rotation: e2.rotation }], snap: null })
        compare(byId(t, "e1").joins.B.id, "e2")
        verify(meets(t, "e1", "B", "e2", "A"))
        compare(byId(t, "e2").joins.B, null)
        compare(byId(t, "e3").joins.A, null)
        compare(stack.undoLabel(), "Move 2 elements")
        compare(JSON.stringify(stack.undo()), JSON.stringify(t0))
    }

    function test_aGroupDragCanSnap() {
        const t0 = base()
        const e3 = byId(t0, "e3")
        const s = new Commands.UndoStack()
        let t = Commands.run(s, t0, "placeMany", { moves: [{ id: "e3", x: e3.x + 50, y: e3.y, rotation: e3.rotation }], snap: null })
        compare(byId(t, "e3").joins.A, null)
        t = Commands.run(s, t, "placeMany", { moves: [{ id: "e3", x: e3.x, y: e3.y, rotation: e3.rotation }],
                                              snap: { ownId: "e3", ownEnd: "A", id: "e2", end: "B" } })
        compare(byId(t, "e3").joins.A.id, "e2")
        compare(byId(t, "e2").joins.B.id, "e3")
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\run.ps1 -NoCpp`
Expected: FAIL — `tst_selection.qml` cannot import `selection.mjs`; `Snapping.findGroupSnap is not a function`; `Unknown command setProps`.

- [ ] **Step 3: Write `selection.mjs`**

Create `app/qml/logic/selection.mjs`:

```js
// Editing several elements at once: the settings they share and the elements a box touches. Elements are plain data
// (see commands.mjs). Tests: tests/qml/tst_selection.qml.
import * as Elements from "./elements.mjs"

// The settings every one of `elements` shows now, in the first element's order, each with the value they all have
// or `mixed: true`: [{ def, value, mixed }].
export function sharedProps(elements) {
    if (elements.length === 0)
        return []
    const lists = elements.map(el => Elements.propList(el.type, el.props))
    return lists[0]
        .filter(def => lists.every(list => list.some(d => d.key === def.key)))
        .map(def => {
            const values = elements.map(el => el.props[def.key])
            const mixed = values.some(v => v !== values[0])
            return { def: def, value: mixed ? null : values[0], mixed: mixed }
        })
}

// Whether segment a-b meets the rectangle r ({ x0, y0, x1, y1 }, x0 <= x1, y0 <= y1): Liang-Barsky clipping.
function segmentMeetsRect(a, b, r) {
    let t0 = 0
    let t1 = 1
    const dx = b.x - a.x
    const dy = b.y - a.y
    for (const [p, q] of [[-dx, a.x - r.x0], [dx, r.x1 - a.x], [-dy, a.y - r.y0], [dy, r.y1 - a.y]]) {
        if (p === 0) {
            if (q < 0)
                return false
        } else {
            const t = q / p
            if (p < 0) {
                if (t > t1)
                    return false
                t0 = Math.max(t0, t)
            } else {
                if (t < t0)
                    return false
                t1 = Math.min(t1, t)
            }
        }
    }
    return true
}

// The ids of the elements whose band (as wide as the track) a box touches. Corners in canvas metres, either way round.
export function boxHits(elements, cornerA, cornerB) {
    const out = []
    for (const el of elements) {
        const h = el.props.trackWidth / 2
        const r = { x0: Math.min(cornerA.x, cornerB.x) - h, y0: Math.min(cornerA.y, cornerB.y) - h,
                    x1: Math.max(cornerA.x, cornerB.x) + h, y1: Math.max(cornerA.y, cornerB.y) + h }
        const path = Elements.pathWorld(el)
        for (let i = 1; i < path.length; i++) {
            if (segmentMeetsRect(path[i - 1], path[i], r)) {
                out.push(el.id)
                break
            }
        }
    }
    return out
}
```

Add `qml/logic/selection.mjs` to `QML_FILES` in `app/CMakeLists.txt` (after `qml/logic/demo.mjs`).

- [ ] **Step 4: Group snapping**

Append to `app/qml/logic/snapping.mjs`:

```js
// The nearest pairing, within maxDistance, of an open end of `group` (elements as they would land) with an open end of
// an element outside it: { ownId, ownEnd, targetId, targetEnd, distance } or null. Ends joined inside the group are not
// open; an outside end joined to a group member counts as open (the drag unjoins it).
export function findGroupSnap(elements, group, maxDistance) {
    const ids = group.map(g => g.id)
    let best = null
    let bestDistance = maxDistance
    for (const g of group) {
        const own = Elements.endsWorld(g)
        for (const ownEnd of ["A", "B"]) {
            const mate = g.joins[ownEnd]
            if (mate && ids.indexOf(mate.id) >= 0)
                continue
            for (const el of elements) {
                if (ids.indexOf(el.id) >= 0)
                    continue
                const ends = Elements.endsWorld(el)
                for (const targetEnd of ["A", "B"]) {
                    const theirs = el.joins[targetEnd]
                    if (theirs && ids.indexOf(theirs.id) < 0)
                        continue
                    const d = Math.hypot(own[ownEnd].x - ends[targetEnd].x, own[ownEnd].y - ends[targetEnd].y)
                    if (d < bestDistance) {
                        bestDistance = d
                        best = { ownId: g.id, ownEnd: ownEnd, targetId: el.id, targetEnd: targetEnd, distance: d }
                    }
                }
            }
        }
    }
    return best
}

// Copies of `group`, turned and shifted as one so that `ownEnd` of member `ownId` meets `target`'s `targetEnd`,
// facing the opposite way.
export function groupToJoin(group, ownId, ownEnd, target, targetEnd) {
    const own = group.find(g => g.id === ownId)
    const placed = placeToJoin(own, ownEnd, target, targetEnd)
    const copies = group.map(g => Object.assign({}, g))
    turnAbout(copies, copies.map(c => c.id), { x: own.x, y: own.y }, Elements.normalizeAngle(placed.rotation - own.rotation))
    const dx = placed.x - own.x
    const dy = placed.y - own.y
    for (const c of copies) {
        c.x += dx
        c.y += dy
    }
    Object.assign(copies.find(c => c.id === ownId), placed)
    return copies
}
```

- [ ] **Step 5: The commands**

In `app/qml/logic/commands.mjs` `COMMANDS`, add:

```js
    // One setting on several elements, each kept within its own limits; chains stay glued.
    setProps(t, a) {
        for (const id of a.ids) {
            const el = find(t, id)
            el.props[a.key] = Elements.clampProp(el.type, a.key, a.value).value
        }
        for (const id of a.ids)
            Snapping.settle(t.elements, id)
        Snapping.unjoinApart(t.elements)
        return t
    },
    removeMany(t, a) {
        for (const id of a.ids) {
            find(t, id)
            Snapping.unjoinAll(t.elements, id)
        }
        t.elements = t.elements.filter(e => a.ids.indexOf(e.id) < 0)
        return t
    },
    // Copies 2 m along x and y; joins between the copied elements are copied too.
    duplicateMany(t, a) {
        const copyOf = {}
        for (const id of a.ids) {
            find(t, id)
            copyOf[id] = "e" + t.nextId
            t.nextId += 1
        }
        for (const id of a.ids) {
            const source = find(t, id)
            const joins = { A: null, B: null }
            for (const end of ["A", "B"]) {
                const mate = source.joins[end]
                if (mate && copyOf[mate.id])
                    joins[end] = { id: copyOf[mate.id], end: mate.end }
            }
            t.elements.push({ id: copyOf[id], type: source.type, x: source.x + 2, y: source.y + 2,
                              rotation: source.rotation, props: Object.assign({}, source.props), joins: joins })
        }
        return t
    },
    // A group drag: each element to its new place. Joins inside the group stay; joins to elements outside it break.
    // `snap` joins one of the group's ends to an outside end (the caller has already brought them together).
    placeMany(t, a) {
        const ids = a.moves.map(m => m.id)
        for (const m of a.moves) {
            const el = find(t, m.id)
            for (const end of ["A", "B"])
                if (el.joins[end] && ids.indexOf(el.joins[end].id) < 0)
                    Snapping.unjoin(t.elements, el.id, end)
            el.x = m.x
            el.y = m.y
            el.rotation = m.rotation
        }
        if (a.snap) {
            Snapping.join(t.elements, a.snap.ownId, a.snap.ownEnd, a.snap.id, a.snap.end)
            for (const id of ids)
                Snapping.joinTouching(t.elements, id)
        }
        return t
    }
```

In `label`, add:

```js
    case "setProps": {
        const el = track.elements.find(e => e.id === a.ids[0])
        const def = el ? Elements.PROPS[el.type].find(p => p.key === a.key) : null
        return "Change " + (def ? def.label : a.key) + (a.ids.length > 1 ? " (" + a.ids.length + " elements)" : "")
    }
    case "removeMany": return "Delete " + (a.ids.length === 1 ? named(a.ids[0]) : a.ids.length + " elements")
    case "duplicateMany": return "Duplicate " + (a.ids.length === 1 ? named(a.ids[0]) : a.ids.length + " elements")
    case "placeMany":
        return (a.verb || "Move") + " " + (a.moves.length === 1 ? named(a.moves[0].id) : a.moves.length + " elements")
```

and in `mergeKeyFor`, before the final `return`:

```js
    if (name === "setProps")
        return "props:" + a.ids.join(",") + ":" + a.key
```

- [ ] **Step 6: Run every test**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`, `qml: … passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git add app/qml/logic/selection.mjs app/qml/logic/snapping.mjs app/qml/logic/commands.mjs app/CMakeLists.txt app/tests/qml/tst_selection.qml app/tests/qml/tst_snapping.qml app/tests/qml/tst_commands.qml
git commit -m "Several elements at once: shared settings, box hits, group snapping, setProps/removeMany/duplicateMany/placeMany" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Setup status, the `.cone` document, its schema and its docs

**Files:**
- Create: `app/qml/logic/setup.mjs`, `app/qml/logic/conefile.mjs`, `app/tests/qml/tst_setup.qml`, `app/tests/qml/tst_conefile.qml`, `app/tests/qml/fixtures/schemacheck.mjs`, `docs/cone-format.schema.json`, `docs/cone-format.md`
- Modify: `app/CMakeLists.txt` (QML_FILES), `app/tests/run.ps1`

**Interfaces:**
- Consumes: `Post.run` with `element` on cones (Task 4); `Commands.clone`, `Commands.rulerMetresPerPixel`; `Elements.TYPES/PROPS/defaults/clamp`; `Frame.makeFrame`.
- Produces: `Setup.status(track) -> { photo, ruler, origin, direction, count, done }`; `ConeFile.FORMAT = "conestructor-track"`, `ConeFile.VERSION = 1`, `ConeFile.MESSAGES = { notTrack, newer, damaged, photo }`; `ConeFile.timestamp(date) -> "2026-11-10T14:03:00Z"`; `ConeFile.toDocument(track, { name, app, saved }) -> object` (file order, no `photo`); `ConeFile.documentText(track, info) -> string` (two-space JSON of that object); `ConeFile.fromDocument(doc, photoRef) -> { track, warning } | { error }` (`warning` is `""` or `MESSAGES.photo`; `photoRef` is the PhotoStore ref of the file's photo, or -1). The schema file's path is `docs/cone-format.schema.json`.

- [ ] **Step 1: Write the failing tests**

Create `app/tests/qml/tst_setup.qml`:

```qml
import QtQuick
import QtTest
import "../../qml/logic/commands.mjs" as Commands
import "../../qml/logic/setup.mjs" as Setup

TestCase {
    name: "Setup"

    function after(steps) {
        const s = new Commands.UndoStack()
        let t = Commands.emptyTrack()
        for (const step of steps)
            t = Commands.run(s, t, step[0], step[1])
        return t
    }

    function test_aNewTrackHasNothingDone() {
        const s = Setup.status(Commands.emptyTrack())
        compare(JSON.stringify(s), JSON.stringify({ photo: false, ruler: false, origin: false, direction: false,
                                                    count: 0, done: false }))
    }

    function test_eachStepTicks() {
        const steps = [["setPhoto", { kind: "blueprint" }]]
        compare(Setup.status(after(steps)).count, 1)
        steps.push(["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 0 }])
        verify(!Setup.status(after(steps)).ruler, "a ruler without a length is not done")
        steps.push(["setRuler", { a: { x: 0, y: 0 }, b: { x: 100, y: 0 }, realLength: 10 }])
        verify(Setup.status(after(steps)).ruler)
        steps.push(["setTarget", { which: "origin", point: { x: 50, y: 50 } }])
        verify(Setup.status(after(steps)).origin)
        steps.push(["setTarget", { which: "direction", point: { x: 55, y: 50 } }])      // 0.5 m away
        verify(!Setup.status(after(steps)).direction, "too close to Origin")
        steps.push(["setTarget", { which: "direction", point: { x: 150, y: 50 } }])
        const s = Setup.status(after(steps))
        verify(s.direction)
        compare(s.count, 4)
        verify(s.done)
    }

    function test_aLotPhotoCountsToo() {
        verify(Setup.status(after([["setPhoto", { kind: "image", ref: 1 }]])).photo)
    }

    function test_directionWithNothingToMeasureCountsWhenPlaced() {
        verify(Setup.status(after([["setTarget", { which: "direction", point: { x: 1, y: 1 } }]])).direction)
    }
}
```

Create `app/tests/qml/fixtures/schemacheck.mjs`:

```js
// A small JSON Schema checker covering the keywords docs/cone-format.schema.json uses: type, const, enum, required,
// properties, items, minimum, anyOf and $ref to "#/$defs/<name>". Other keywords ($schema, title, description,
// format, contentEncoding) are notes and are ignored. problems() lists what does not fit; empty means it fits.

function typeOf(v) {
    if (v === null)
        return "null"
    if (Array.isArray(v))
        return "array"
    if (typeof v === "number")
        return Number.isInteger(v) ? "integer" : "number"
    return typeof v
}

function fits(type, v) {
    const t = typeOf(v)
    return type === t || (type === "number" && t === "integer")
}

function check(root, s, v, where, out) {
    if (s.$ref) {
        check(root, root.$defs[s.$ref.replace("#/$defs/", "")], v, where, out)
        return
    }
    if (s.anyOf) {
        const ok = s.anyOf.some(option => {
            const inner = []
            check(root, option, v, where, inner)
            return inner.length === 0
        })
        if (!ok)
            out.push(where + ": fits none of its choices")
    }
    if (s.type !== undefined) {
        const types = Array.isArray(s.type) ? s.type : [s.type]
        if (!types.some(t => fits(t, v))) {
            out.push(where + ": should be " + types.join(" or "))
            return
        }
    }
    if (s.const !== undefined && v !== s.const)
        out.push(where + ": should be " + JSON.stringify(s.const))
    if (s.enum && s.enum.indexOf(v) < 0)
        out.push(where + ": should be one of " + JSON.stringify(s.enum))
    if (s.minimum !== undefined && typeof v === "number" && v < s.minimum)
        out.push(where + ": below " + s.minimum)
    if (typeOf(v) === "object") {
        for (const key of s.required || [])
            if (!(key in v))
                out.push(where + ": missing " + key)
        for (const key in s.properties || {})
            if (key in v)
                check(root, s.properties[key], v[key], where + "." + key, out)
    }
    if (Array.isArray(v) && s.items)
        v.forEach((item, i) => check(root, s.items, item, where + "[" + i + "]", out))
}

export function problems(schema, value) {
    const out = []
    check(schema, schema, value, "$", out)
    return out
}
```

Create `app/tests/qml/tst_conefile.qml`:

```qml
import QtQuick
import QtTest
import "../../qml/logic/commands.mjs" as Commands
import "../../qml/logic/conefile.mjs" as ConeFile
import "../../qml/logic/demo.mjs" as Demo
import "fixtures/schemacheck.mjs" as SchemaCheck

TestCase {
    name: "ConeFile"

    property var schema: null
    property bool schemaRead: false
    readonly property var info: ({ name: "Duck pond", app: "Conestructor 0.3.0", saved: "2026-11-10T14:03:00Z" })

    // The schema is read from docs/ (run.ps1 sets QML_XHR_ALLOW_FILE_READ=1 so XMLHttpRequest may read files).
    function initTestCase() {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                schema = xhr.responseText ? JSON.parse(xhr.responseText) : null
                schemaRead = true
            }
        }
        xhr.open("GET", Qt.resolvedUrl("../../../docs/cone-format.schema.json"))
        xhr.send()
        tryVerify(() => schemaRead, 5000, "docs/cone-format.schema.json was read")
        verify(schema !== null, "the schema is JSON")
    }

    function doc(track) {
        return JSON.parse(ConeFile.documentText(track, info))
    }

    function withPhoto(track, ref) {
        return Commands.run(new Commands.UndoStack(), track, "setPhoto", { kind: "image", ref: ref })
    }

    function test_theDocumentReadsInFileOrder() {
        const text = ConeFile.documentText(Demo.demoTrack(), info)
        compare(Object.keys(JSON.parse(text)).join(","), "format,version,name,app,saved,units,axes,targets,cones,design")
        verify(text.startsWith('{\n  "format": "conestructor-track",\n  "version": 1,'), text.slice(0, 80))
        compare(ConeFile.timestamp(new Date(Date.UTC(2026, 10, 10, 14, 3, 0, 456))), "2026-11-10T14:03:00Z")
    }

    function test_conesAndTargetsAreInTheExportFrame() {
        const d = doc(Demo.demoTrack())
        compare(JSON.stringify(d.targets), JSON.stringify({ origin: { x: 0, y: 0 }, direction: { x: 100, y: 0 }, distance: 100 }))
        verify(d.cones.length > 40, d.cones.length + " cones")
        compare(d.cones[0].index, 0)
        compare(d.cones[0].element, "e1")
        for (const c of d.cones) {
            verify(c.type === "standing" || c.type === "leaning", c.type)
            verify(Math.abs(c.x * 1000 - Math.round(c.x * 1000)) < 1e-6, "x to the millimetre: " + c.x)
        }
        compare(d.units, "m")
        compare(d.axes, "x toward Direction target, y to the left, heading degrees counter-clockwise from +x")
    }

    function test_anUnfinishedTrackStillSaves() {
        const d = doc(Commands.emptyTrack())
        compare(d.cones.length, 0)
        compare(JSON.stringify(d.targets), JSON.stringify({ origin: null, direction: null, distance: null }))
    }

    function test_theDesignHoldsNoPhotoBytes() {
        compare(JSON.stringify(doc(withPhoto(Demo.demoTrack(), 5)).design.photo),
                JSON.stringify({ kind: "image", metresPerPixel: 0.1 }))
    }

    function test_aTrackComesBackExactly() {
        const t = withPhoto(Demo.demoTrack(), 9)
        const back = ConeFile.fromDocument(doc(t), 9)
        verify(!back.error, back.error)
        compare(JSON.stringify(back.track), JSON.stringify(t))
        compare(back.warning, "")
        compare(JSON.stringify(ConeFile.fromDocument(doc(Demo.demoTrack()), -1).track), JSON.stringify(Demo.demoTrack()))
        compare(JSON.stringify(ConeFile.fromDocument(doc(Commands.emptyTrack()), -1).track),
                JSON.stringify(Commands.emptyTrack()))
    }

    function test_refusals_data() {
        return [
            { tag: "not an object", what: "array", error: ConeFile.MESSAGES.notTrack },
            { tag: "another format", what: "format", error: ConeFile.MESSAGES.notTrack },
            { tag: "a newer version", what: "newer", error: ConeFile.MESSAGES.newer },
            { tag: "a version that is not a number", what: "version", error: ConeFile.MESSAGES.damaged },
            { tag: "no design", what: "design", error: ConeFile.MESSAGES.damaged },
            { tag: "an unknown element type", what: "type", error: ConeFile.MESSAGES.damaged },
            { tag: "a join that is not mutual", what: "join", error: ConeFile.MESSAGES.damaged },
            { tag: "elements without a ruler", what: "ruler", error: ConeFile.MESSAGES.damaged },
            { tag: "two elements with one id", what: "twins", error: ConeFile.MESSAGES.damaged }
        ]
    }

    function test_refusals(row) {
        let d = doc(Demo.demoTrack())
        switch (row.what) {
        case "array": d = []; break
        case "format": d.format = "geojson"; break
        case "newer": d.version = 2; break
        case "version": d.version = "one"; break
        case "design": d.design = null; break
        case "type": d.design.elements[0].type = "loop"; break
        case "join": d.design.elements[1].joins.A = null; break
        case "ruler": d.design.ruler = null; break
        case "twins": d.design.elements[1].id = "e1"; break
        }
        compare(ConeFile.fromDocument(d, -1).error, row.error)
    }

    function test_aPhotoThatCannotBeReadOpensOnTheBlueprint() {
        const back = ConeFile.fromDocument(doc(withPhoto(Demo.demoTrack(), 4)), -1)
        compare(JSON.stringify(back.track.photo), JSON.stringify({ kind: "none", ref: null, metresPerPixel: 0.1 }))
        compare(back.warning, ConeFile.MESSAGES.photo)
    }

    function test_aHandEditedFileIsReadSafely() {
        const d = doc(Demo.demoTrack())
        d.design.elements[0].props.trackWidth = 500           // beyond its limit
        delete d.design.elements[1].props.coneSpacing         // missing
        d.design.photo.metresPerPixel = 3                     // ignored: the ruler sets the scale
        d.design.nextId = 2                                   // too low for e4
        const back = ConeFile.fromDocument(d, -1)
        verify(!back.error, back.error)
        compare(back.track.elements[0].props.trackWidth, 20)
        compare(back.track.elements[1].props.coneSpacing, 10)
        compare(back.track.photo.metresPerPixel, 0.1)
        compare(back.track.nextId, 5)
    }

    function test_theDocumentMatchesTheSchema() {
        for (const t of [Demo.demoTrack(), Commands.emptyTrack()]) {
            const d = doc(t)
            d.photo = null
            compare(SchemaCheck.problems(schema, d).join("; "), "")
            d.photo = { mediaType: "image/png", width: 1280, height: 720, data: "iVBORw0KGgo=" }
            compare(SchemaCheck.problems(schema, d).join("; "), "")
        }
        const bad = doc(Demo.demoTrack())
        bad.photo = null
        bad.cones[0].type = "upright"
        delete bad.units
        const found = SchemaCheck.problems(schema, bad)
        compare(found.length, 2, found.join("; "))
    }
}
```

In `app/tests/run.ps1`, after the `$env:QT_QPA_FONTDIR = ...` line, add:

```powershell
# tst_conefile reads docs/cone-format.schema.json with XMLHttpRequest, which QML allows for local files only when asked.
$env:QML_XHR_ALLOW_FILE_READ = '1'
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\run.ps1 -NoCpp`
Expected: FAIL — `tst_setup.qml` and `tst_conefile.qml` cannot import their modules (and the schema file is missing).

- [ ] **Step 3: Write `setup.mjs`**

Create `app/qml/logic/setup.mjs`:

```js
// The setup checklist: which of the four steps are done. Photo: a lot photo is loaded or the blueprint was chosen.
// Ruler: placed, with a real length. Origin: placed. Direction: placed, and at least 1 m from Origin whenever Origin
// and the ruler's scale are there to measure it. Tests: tests/qml/tst_setup.qml.
import * as Frame from "./frame.mjs"
import { MIN_TARGET_DISTANCE } from "./postprocess.mjs"

export function status(track) {
    const scale = track.photo.metresPerPixel
    const photo = track.photo.kind === "image" || track.photo.kind === "blueprint"
    const ruler = track.ruler !== null && scale > 0
    const origin = track.targets.origin !== null
    let direction = track.targets.direction !== null
    if (direction && origin && scale > 0) {
        const frame = Frame.makeFrame(track.targets.origin, track.targets.direction, scale)
        direction = frame !== null && frame.distance >= MIN_TARGET_DISTANCE
    }
    const count = [photo, ruler, origin, direction].filter(done => done).length
    return { photo: photo, ruler: ruler, origin: origin, direction: direction, count: count, done: count === 4 }
}
```

- [ ] **Step 4: Write `conefile.mjs`**

Create `app/qml/logic/conefile.mjs`:

```js
// The .cone track file: one UTF-8 JSON document per track (docs/cone-format.md, docs/cone-format.schema.json). This
// module builds the document's text from the track, every field but the photo, which C++ (TrackFile) adds last as
// base64; and reads a parsed document back into a track, refusing anything it cannot use. Tests:
// tests/qml/tst_conefile.qml.
import * as Commands from "./commands.mjs"
import * as Elements from "./elements.mjs"
import * as Frame from "./frame.mjs"
import * as Post from "./postprocess.mjs"

export const FORMAT = "conestructor-track"
export const VERSION = 1
export const UNITS = "m"
export const AXES = "x toward Direction target, y to the left, heading degrees counter-clockwise from +x"
export const MESSAGES = {
    notTrack: "That file isn't a Conestructor track.",
    newer: "That track was made with a newer Conestructor.",
    damaged: "That track file is damaged.",
    photo: "The photo in that file couldn't be read; the blueprint is shown instead."
}

// Rounded to `places` decimals; adding 0 turns -0 into 0 so the file never says "-0".
function round(value, places) {
    const f = Math.pow(10, places)
    return Math.round(value * f) / f + 0
}

// ISO 8601 UTC to the second: "2026-11-10T14:03:00Z".
export function timestamp(date) {
    return date.toISOString().replace(/\.\d{3}Z$/, "Z")
}

// The document for `track` as an object whose keys are in file order, without the photo.
// `info`: { name, app, saved }.
export function toDocument(track, info) {
    const scale = track.photo.metresPerPixel
    const frame = Frame.makeFrame(track.targets.origin, track.targets.direction, scale)
    const targets = {
        origin: track.targets.origin ? { x: 0, y: 0 } : null,
        direction: frame ? { x: round(frame.distance, 3), y: 0 } : null,
        distance: frame ? round(frame.distance, 3) : null
    }
    const result = Post.run(track)
    const cones = result.error ? [] : result.cones.map(c => ({
        index: c.index, type: c.type, x: round(c.x, 3), y: round(c.y, 3), heading: round(c.heading, 2), element: c.element
    }))
    const design = Commands.clone(track)
    design.photo = { kind: track.photo.kind, metresPerPixel: scale }
    return { format: FORMAT, version: VERSION, name: info.name, app: info.app, saved: info.saved, units: UNITS,
             axes: AXES, targets: targets, cones: cones, design: design }
}

// The document's text, two-space indented, without the photo (TrackFile adds it last).
export function documentText(track, info) {
    return JSON.stringify(toDocument(track, info), null, 2)
}

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function isNumber(v) {
    return typeof v === "number" && isFinite(v)
}

// A point, or undefined when `v` is not one.
function point(v) {
    return isObject(v) && isNumber(v.x) && isNumber(v.y) ? { x: v.x, y: v.y } : undefined
}

// null for a target not placed; undefined when `v` is neither.
function target(v) {
    return v === null || v === undefined ? null : point(v)
}

// One element in the app's own shape, or null when it cannot be read. Settings outside their limits are kept within
// them; missing settings take their defaults.
function readElement(v) {
    if (!isObject(v) || typeof v.id !== "string" || Elements.TYPES.indexOf(v.type) < 0)
        return null
    if (!isNumber(v.x) || !isNumber(v.y) || !isNumber(v.rotation) || !isObject(v.props) || !isObject(v.joins))
        return null
    const props = Elements.defaults(v.type)
    for (const def of Elements.PROPS[v.type]) {
        const value = v.props[def.key]
        if (value === undefined)
            continue
        if (def.kind === "choice" ? def.choices.indexOf(value) < 0 : !isNumber(value))
            return null
        props[def.key] = Elements.clamp(def, value).value
    }
    const joins = {}
    for (const end of ["A", "B"]) {
        const j = v.joins[end]
        if (j === null || j === undefined)
            joins[end] = null
        else if (isObject(j) && typeof j.id === "string" && (j.end === "A" || j.end === "B"))
            joins[end] = { id: j.id, end: j.end }
        else
            return null
    }
    return { id: v.id, type: v.type, x: v.x, y: v.y, rotation: v.rotation, props: props, joins: joins }
}

// The track from a document's `design`, or null when it is damaged.
function readDesign(d) {
    if (!isObject(d) || !isObject(d.photo) || !isObject(d.targets) || !Array.isArray(d.elements))
        return null
    if (["none", "blueprint", "image"].indexOf(d.photo.kind) < 0)
        return null
    let ruler = null
    if (d.ruler !== null && d.ruler !== undefined) {
        if (!isObject(d.ruler))
            return null
        const a = point(d.ruler.a)
        const b = point(d.ruler.b)
        if (!a || !b || !isNumber(d.ruler.realLength) || d.ruler.realLength < 0)
            return null
        ruler = { a: a, b: b, realLength: d.ruler.realLength }
    }
    const origin = target(d.targets.origin)
    const direction = target(d.targets.direction)
    if (origin === undefined || direction === undefined)
        return null
    const elements = []
    for (const v of d.elements) {
        const el = readElement(v)
        if (!el || elements.some(e => e.id === el.id))
            return null
        elements.push(el)
    }
    for (const el of elements) {
        for (const end of ["A", "B"]) {
            const j = el.joins[end]
            if (!j)
                continue
            const other = elements.find(e => e.id === j.id)
            const back = other ? other.joins[j.end] : null
            if (!back || back.id !== el.id || back.end !== end)
                return null
        }
    }
    const scale = Commands.rulerMetresPerPixel(ruler)
    if (elements.length > 0 && !(scale > 0))
        return null
    let nextId = isNumber(d.nextId) ? Math.max(1, Math.floor(d.nextId)) : 1
    for (const el of elements) {
        const m = /^e(\d+)$/.exec(el.id)
        if (m)
            nextId = Math.max(nextId, Number(m[1]) + 1)
    }
    return { photo: { kind: d.photo.kind, ref: null, metresPerPixel: scale }, ruler: ruler,
             targets: { origin: origin, direction: direction }, elements: elements, nextId: nextId }
}

// A track from a parsed document whose photo TrackFile has already taken out: { track, warning } or { error }.
// `photoRef` is the photo's PhotoStore ref, or -1 when the file had none or it could not be read.
export function fromDocument(doc, photoRef) {
    if (!isObject(doc) || doc.format !== FORMAT)
        return { error: MESSAGES.notTrack }
    if (!isNumber(doc.version))
        return { error: MESSAGES.damaged }
    if (doc.version > VERSION)
        return { error: MESSAGES.newer }
    const track = readDesign(doc.design)
    if (!track)
        return { error: MESSAGES.damaged }
    let warning = ""
    if (track.photo.kind === "image") {
        if (photoRef >= 0) {
            track.photo.ref = photoRef
        } else {
            track.photo.kind = "none"
            warning = MESSAGES.photo
        }
    }
    return { track: track, warning: warning }
}
```

Add `qml/logic/setup.mjs` and `qml/logic/conefile.mjs` to `QML_FILES` in `app/CMakeLists.txt` (after `qml/logic/selection.mjs`).

- [ ] **Step 5: Write the schema**

Create `docs/cone-format.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Conestructor track (.cone), version 1",
  "description": "One autocross track: its targets and cones in metres in the export frame, Conestructor's own editable design, and the lot photo. See docs/cone-format.md. Readers ignore fields they do not know.",
  "type": "object",
  "required": ["format", "version", "name", "app", "saved", "units", "axes", "targets", "cones", "design", "photo"],
  "properties": {
    "format": { "const": "conestructor-track" },
    "version": { "type": "integer", "minimum": 1, "description": "1 for this structure; changes only when the structure changes." },
    "name": { "type": "string", "description": "The track's name (the file name when saved)." },
    "app": { "type": "string", "description": "The app and version that saved it." },
    "saved": { "type": "string", "format": "date-time", "description": "When it was saved, ISO 8601 UTC." },
    "units": { "const": "m" },
    "axes": { "type": "string", "description": "x toward Direction target, y to the left, heading degrees counter-clockwise from +x" },
    "targets": {
      "type": "object",
      "required": ["origin", "direction", "distance"],
      "properties": {
        "origin": { "anyOf": [{ "type": "null" }, { "$ref": "#/$defs/point" }], "description": "Always 0, 0 once placed." },
        "direction": { "anyOf": [{ "type": "null" }, { "$ref": "#/$defs/point" }], "description": "On +x; null until Origin, Direction and the ruler's real length are set." },
        "distance": { "type": ["number", "null"], "minimum": 0, "description": "Metres from Origin to Direction." }
      }
    },
    "cones": { "type": "array", "items": { "$ref": "#/$defs/cone" }, "description": "Every cone in driving order; empty when the track cannot be processed yet." },
    "design": { "type": "object", "description": "Conestructor's own editable track. It may change between app versions: read cones instead." },
    "photo": { "anyOf": [{ "type": "null" }, { "$ref": "#/$defs/photo" }] }
  },
  "$defs": {
    "point": {
      "type": "object",
      "required": ["x", "y"],
      "properties": { "x": { "type": "number" }, "y": { "type": "number" } }
    },
    "cone": {
      "type": "object",
      "required": ["index", "type", "x", "y", "heading", "element"],
      "properties": {
        "index": { "type": "integer", "minimum": 0 },
        "type": { "enum": ["standing", "leaning"] },
        "x": { "type": "number" },
        "y": { "type": "number" },
        "heading": { "type": "number", "description": "Degrees counter-clockwise from +x: where a leaning cone points; 0 for standing cones." },
        "element": { "type": ["string", "null"], "description": "The element that made it; null for a cone added by hand." },
        "edited": { "type": "boolean", "description": "Optional: true when someone changed this cone by hand." }
      }
    },
    "photo": {
      "type": "object",
      "required": ["mediaType", "width", "height", "data"],
      "properties": {
        "mediaType": { "enum": ["image/png", "image/jpeg"] },
        "width": { "type": "integer", "minimum": 1 },
        "height": { "type": "integer", "minimum": 1 },
        "data": { "type": "string", "contentEncoding": "base64", "description": "The original file's bytes." }
      }
    }
  }
}
```

- [ ] **Step 6: Write the format document**

Create `docs/cone-format.md`:

````markdown
# The `.cone` track file

A `.cone` file holds one autocross track designed in Conestructor: where every cone goes, in order, in metres, plus
everything Conestructor needs to edit the track again (its design and the lot photo). It is plain UTF-8 JSON, so any
JSON parser reads it. The JSON Schema is [`cone-format.schema.json`](cone-format.schema.json).

## Reading the cones

```python
import json

with open("Duck pond autocross.cone", encoding="utf-8") as f:
    track = json.load(f)

for cone in track["cones"]:
    print(cone["index"], cone["type"], cone["x"], cone["y"], cone["heading"])
```

## The frame

All positions are in metres, measured from the **Origin** target on the lot:

- **x** points from Origin toward the **Direction** target;
- **y** points 90° to the left of x, seen from above;
- **heading** is in degrees, counter-clockwise from +x.

To put the cones on the lot, find Origin and Direction there (they are two marks the track designer chose, such as a
light pole and a drain) and measure from them.

## Example

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
    { "index": 0, "type": "standing", "x": 1.77, "y": 7.76, "heading": 0, "element": "e1" },
    { "index": 1, "type": "standing", "x": 1.77, "y": 3.76, "heading": 0, "element": "e1" }
  ],
  "design": { "...": "Conestructor's own data" },
  "photo": { "mediaType": "image/jpeg", "width": 4032, "height": 3024, "data": "/9j/4AAQSkZJRg..." }
}
```

The fields always come in this order, and the photo is always last, so the readable part is at the top of the file.

## Fields

| Field | Meaning |
|---|---|
| `format` | Always `"conestructor-track"`. |
| `version` | Whole number, `1` for this structure. It changes only when the structure changes. |
| `name` | The track's name (the file name when it was saved). |
| `app` | The app and version that saved it. |
| `saved` | When it was saved, ISO 8601 UTC. |
| `units`, `axes` | Fixed: metres, and the frame in words. |
| `targets` | `origin` (always `{ "x": 0, "y": 0 }`), `direction` (always on +x) and the `distance` between them in metres. `origin` is `null` until Origin is placed; `direction` and `distance` are `null` until Origin, Direction and the scale are all set. |
| `cones` | Every cone in driving order. `index` counts from 0; `type` is `standing` or `leaning`; `x`, `y` in metres (to the millimetre); `heading` is where a leaning cone points (0 for standing cones); `element` is the id of the track element that made it (`null` for a cone added by hand). Empty when the track cannot be processed yet. |
| `design` | Conestructor's own editable track (element settings, joins, the ruler, positions on the photo). It may change between app versions; other apps should read `cones` instead. |
| `photo` | The lot photo: `mediaType` (`image/png` or `image/jpeg`), `width` and `height` in pixels, and `data`, the original file's bytes in base64. `null` when the track has no photo. |

## Rules for readers

- Ignore fields you do not know. New optional fields do not change `version`; only a change of structure does.
- `cones` is always the final list, including any cones someone changed by hand in Conestructor. Such a cone may carry
  `"edited": true`.
- Positions are rounded to the millimetre and headings to a hundredth of a degree.
````

- [ ] **Step 7: Run every test**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`, `qml: … passed, 0 failed`.

- [ ] **Step 8: Commit**

```bash
git add app/qml/logic/setup.mjs app/qml/logic/conefile.mjs app/CMakeLists.txt app/tests/run.ps1 app/tests/qml/tst_setup.qml app/tests/qml/tst_conefile.qml app/tests/qml/fixtures/schemacheck.mjs docs/cone-format.schema.json docs/cone-format.md
git commit -m "The .cone document: setup status, track <-> document, the JSON Schema and docs/cone-format.md" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: `TrackFile` (C++) and recent files

**Files:**
- Create: `app/services/TrackFile.h`, `app/services/TrackFile.cpp`, `app/tests/tst_trackfile.cpp`
- Delete: `app/services/FileIO.h`, `app/services/FileIO.cpp`, `app/tests/tst_fileio.cpp`
- Modify: `app/services/Settings.h`, `app/services/Settings.cpp`, `app/tests/tst_settings.cpp`, `app/CMakeLists.txt`, `app/tests/CMakeLists.txt`, `app/qml/Main.qml` (the JSON export goes), `app/tests/tst_qmlload.cpp` (the export check goes)

**Interfaces:**
- Consumes: `PhotoStore::add/has/bytes/mediaType/size` (Task 1).
- Produces: QML singleton `TrackFile` with `toLocalPath(url) -> string`, `baseName(path) -> string` (file name without `.cone`), `exists(path) -> bool`, `save(path, documentText, photoRef) -> "" | sentence`, `open(path) -> { text, photoRef, photoError } | { error: "missing" | "unreadable" | "notJson", message }` (`text` is the document without `photo`, as JSON), `writeBackup(documentText, photoRef, trackPath, name) -> "" | sentence`, `findBackup() -> { path, trackPath, name, time } | {}`, `deleteBackup()`; static `saveTo(path, text, const PhotoStore *, ref)`, `openFrom(path, PhotoStore *)`, `backupDir()` (the folder holding `Conestructor.ini`). `Settings.recentFiles` (QStringList, newest first, at most 8, native separators; a path already listed, compared ignoring case, moves to the top), `addRecentFile(path)`, `removeRecentFile(path)`, `clearRecentFiles()`, signal `recentFilesChanged`.

- [ ] **Step 1: Write the failing tests**

Create `app/tests/tst_trackfile.cpp`:

```cpp
#include <QBuffer>
#include <QColor>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QImage>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSettings>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>

#include "services/PhotoStore.h"
#include "services/TrackFile.h"

class TestTrackFile : public QObject
{
    Q_OBJECT

    QTemporaryDir dir;

    static QByteArray encoded(const QImage &image, const char *format)
    {
        QByteArray bytes;
        QBuffer buffer(&bytes);
        buffer.open(QIODevice::WriteOnly);
        image.save(&buffer, format);
        return bytes;
    }

    static QByteArray png(QSize size)
    {
        QImage image(size, QImage::Format_RGB32);
        image.fill(QColor(30, 120, 200));
        return encoded(image, "PNG");
    }

    static QByteArray read(const QString &path)
    {
        QFile file(path);
        file.open(QIODevice::ReadOnly);
        return file.readAll();
    }

    static void write(const QString &path, const QByteArray &bytes)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(bytes);
    }

    // What conefile.mjs would hand over: a JSON object without the photo.
    static QString document()
    {
        return QStringLiteral("{\n  \"format\": \"conestructor-track\",\n  \"version\": 1,\n  \"name\": \"Lot\",\n"
                              "  \"design\": {\n    \"nextId\": 3\n  }\n}");
    }

private slots:
    void initTestCase()
    {
        // The backup lives beside Conestructor.ini; keep it away from the owner's.
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, dir.path());
    }

    void saveThenOpenKeepsEverything()
    {
        PhotoStore photos;
        const QByteArray picture = png(QSize(64, 48));
        const int ref = photos.add(picture);
        const QString path = dir.filePath(QStringLiteral("Lot.cone"));
        QCOMPARE(TrackFile::saveTo(path, document(), &photos, ref), QString());

        const QByteArray raw = read(path);
        QVERIFY(raw.startsWith("{\n  \"format\": \"conestructor-track\""));
        QVERIFY(raw.indexOf("\"photo\"") > raw.indexOf("\"design\""));
        QVERIFY(raw.endsWith("\"\n  }\n}\n"));
        const QJsonObject json = QJsonDocument::fromJson(raw).object();
        const QJsonObject photo = json.value(QStringLiteral("photo")).toObject();
        QCOMPARE(photo.value(QStringLiteral("mediaType")).toString(), QStringLiteral("image/png"));
        QCOMPARE(photo.value(QStringLiteral("width")).toInt(), 64);
        QCOMPARE(photo.value(QStringLiteral("height")).toInt(), 48);
        QCOMPARE(QByteArray::fromBase64(photo.value(QStringLiteral("data")).toString().toLatin1()), picture);

        PhotoStore other;
        const QVariantMap opened = TrackFile::openFrom(path, &other);
        QVERIFY(!opened.contains(QStringLiteral("error")));
        const int newRef = opened.value(QStringLiteral("photoRef")).toInt();
        QVERIFY(newRef > 0);
        QCOMPARE(other.bytes(newRef), picture);
        QVERIFY(!opened.value(QStringLiteral("photoError")).toBool());
        const QJsonObject text = QJsonDocument::fromJson(opened.value(QStringLiteral("text")).toString().toUtf8()).object();
        QCOMPARE(text.value(QStringLiteral("name")).toString(), QStringLiteral("Lot"));
        QCOMPARE(text.value(QStringLiteral("design")).toObject().value(QStringLiteral("nextId")).toInt(), 3);
        QVERIFY(!text.contains(QStringLiteral("photo")));
    }

    void withoutAPhotoTheFieldIsNull()
    {
        const QString path = dir.filePath(QStringLiteral("Blueprint.cone"));
        QCOMPARE(TrackFile::saveTo(path, document(), nullptr, -1), QString());
        QVERIFY(QJsonDocument::fromJson(read(path)).object().value(QStringLiteral("photo")).isNull());
        const QVariantMap opened = TrackFile::openFrom(path, nullptr);
        QCOMPARE(opened.value(QStringLiteral("photoRef")).toInt(), -1);
        QVERIFY(!opened.value(QStringLiteral("photoError")).toBool());
    }

    void notJsonIsRefused()
    {
        const QString path = dir.filePath(QStringLiteral("notes.cone"));
        write(path, "hello");
        QCOMPARE(TrackFile::openFrom(path, nullptr).value(QStringLiteral("error")).toString(), QStringLiteral("notJson"));
    }

    void aMissingFileSaysSo()
    {
        const QVariantMap r = TrackFile::openFrom(dir.filePath(QStringLiteral("gone.cone")), nullptr);
        QCOMPARE(r.value(QStringLiteral("error")).toString(), QStringLiteral("missing"));
        QVERIFY(r.value(QStringLiteral("message")).toString().contains(QStringLiteral("gone.cone")));
    }

    void aBrokenPhotoOpensWithoutIt()
    {
        const QString path = dir.filePath(QStringLiteral("broken.cone"));
        write(path, "{\"format\": \"conestructor-track\", \"version\": 1, \"photo\": {\"mediaType\": \"image/png\", "
                    "\"width\": 1, \"height\": 1, \"data\": \"bm90IGFuIGltYWdl\"}}");
        PhotoStore photos;
        const QVariantMap r = TrackFile::openFrom(path, &photos);
        QVERIFY(!r.contains(QStringLiteral("error")));
        QCOMPARE(r.value(QStringLiteral("photoRef")).toInt(), -1);
        QVERIFY(r.value(QStringLiteral("photoError")).toBool());
    }

    void aSaveThatCannotWriteSaysWhy()
    {
        const QString path = dir.filePath(QStringLiteral("no such folder/x.cone"));
        QVERIFY(TrackFile::saveTo(path, document(), nullptr, -1).startsWith(QStringLiteral("Could not write")));
    }

    void aPathWithAccentsAndSpacesWorks()
    {
        QVERIFY(QDir(dir.path()).mkpath(QStringLiteral("Team tracks")));
        const QString path = dir.filePath(QStringLiteral("Team tracks/Piste d'\u00e9t\u00e9.cone"));
        TrackFile files;
        QCOMPARE(TrackFile::saveTo(path, document(), nullptr, -1), QString());
        QVERIFY(files.exists(path));
        QCOMPARE(files.baseName(path), QStringLiteral("Piste d'\u00e9t\u00e9"));
        QVERIFY(!TrackFile::openFrom(path, nullptr).contains(QStringLiteral("error")));
        QCOMPARE(files.toLocalPath(QUrl::fromLocalFile(path)), path);
    }

    // A full-size phone photo (4000 x 3000, noisy so it does not compress away) survives and does not crawl.
    void aBigPhotoRoundTrips()
    {
        QImage image(4000, 3000, QImage::Format_RGB32);
        quint32 seed = 12345;
        for (int y = 0; y < image.height(); ++y) {
            auto *line = reinterpret_cast<quint32 *>(image.scanLine(y));
            for (int x = 0; x < image.width(); ++x) {
                seed = seed * 1664525u + 1013904223u;
                line[x] = 0xff000000u | (seed >> 8);
            }
        }
        const QByteArray jpeg = encoded(image, "JPEG");
        PhotoStore photos;
        const int ref = photos.add(jpeg);
        QVERIFY(ref > 0);
        const QString path = dir.filePath(QStringLiteral("Big.cone"));
        QElapsedTimer timer;
        timer.start();
        QCOMPARE(TrackFile::saveTo(path, document(), &photos, ref), QString());
        PhotoStore other;
        const QVariantMap opened = TrackFile::openFrom(path, &other);
        const qint64 ms = timer.elapsed();
        QCOMPARE(other.bytes(opened.value(QStringLiteral("photoRef")).toInt()), jpeg);
        QVERIFY2(ms < 10000, qPrintable(QStringLiteral("%1 ms").arg(ms)));
    }

    void theBackupIsFoundAndDeleted()
    {
        TrackFile files;
        files.deleteBackup();
        QVERIFY(files.findBackup().isEmpty());
        QCOMPARE(files.writeBackup(document(), -1, QStringLiteral("C:/tracks/Lot.cone"), QStringLiteral("Lot")), QString());
        const QVariantMap b = files.findBackup();
        QCOMPARE(b.value(QStringLiteral("name")).toString(), QStringLiteral("Lot"));
        QCOMPARE(b.value(QStringLiteral("trackPath")).toString(), QStringLiteral("C:/tracks/Lot.cone"));
        QVERIFY(QRegularExpression(QStringLiteral("^\\d\\d:\\d\\d$")).match(b.value(QStringLiteral("time")).toString()).hasMatch());
        QVERIFY(QFile::exists(b.value(QStringLiteral("path")).toString()));
        QVERIFY(QDir::cleanPath(b.value(QStringLiteral("path")).toString()).startsWith(QDir::cleanPath(dir.path())));
        files.deleteBackup();
        QVERIFY(files.findBackup().isEmpty());
    }
};

QTEST_MAIN(TestTrackFile)
#include "tst_trackfile.moc"
```

Add to `app/tests/tst_settings.cpp` (with `#include <QDir>`):

```cpp
    void recentFilesAreNewestFirstAndAtMostEight()
    {
        Settings s;
        QSignalSpy changed(&s, &Settings::recentFilesChanged);
        for (int i = 1; i <= 10; ++i)
            s.addRecentFile(QStringLiteral("C:/tracks/t%1.cone").arg(i));
        QCOMPARE(s.recentFiles().size(), 8);
        QCOMPARE(s.recentFiles().first(), QDir::toNativeSeparators(QStringLiteral("C:/tracks/t10.cone")));
        QCOMPARE(s.recentFiles().last(), QDir::toNativeSeparators(QStringLiteral("C:/tracks/t3.cone")));
        QCOMPARE(changed.count(), 10);
    }

    void aFileOpenedAgainMovesToTheTop()
    {
        Settings s;
        s.addRecentFile(QStringLiteral("C:/tracks/a.cone"));
        s.addRecentFile(QStringLiteral("C:/tracks/b.cone"));
        s.addRecentFile(QStringLiteral("c:\\TRACKS\\a.cone"));     // the same file on Windows
        QCOMPARE(s.recentFiles(), QStringList({ QStringLiteral("c:\\TRACKS\\a.cone"),
                                                QDir::toNativeSeparators(QStringLiteral("C:/tracks/b.cone")) }));
    }

    void recentFilesCanBeRemovedAndCleared()
    {
        Settings s;
        s.addRecentFile(QStringLiteral("C:/tracks/a.cone"));
        s.addRecentFile(QStringLiteral("C:/tracks/b.cone"));
        s.removeRecentFile(QStringLiteral("C:/tracks/a.cone"));
        QCOMPARE(s.recentFiles().size(), 1);
        s.clearRecentFiles();
        QVERIFY(s.recentFiles().isEmpty());
    }

    void recentFilesSurviveARestart()
    {
        {
            Settings s;
            s.addRecentFile(QStringLiteral("C:/tracks/a.cone"));
            s.setUnits(QStringLiteral("m"));
        }
        Settings again;
        QCOMPARE(again.recentFiles(), QStringList({ QDir::toNativeSeparators(QStringLiteral("C:/tracks/a.cone")) }));
        QCOMPARE(again.units(), QStringLiteral("m"));
    }
```

In `app/tests/CMakeLists.txt`, replace the `tst_fileio` line with `conestructor_test(tst_trackfile SOURCES tst_trackfile.cpp LIBS conestructor_core)`, and delete `app/tests/tst_fileio.cpp` (`git rm`).

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\build.ps1`
Expected: the build fails: `services/TrackFile.h: No such file or directory`, and `recentFiles` is not a member of `Settings`.

- [ ] **Step 3: Write `TrackFile`**

Create `app/services/TrackFile.h`:

```cpp
#pragma once
#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class PhotoStore;

// Reading and writing .cone track files (docs/cone-format.md). QML builds the document's text (logic/conefile.mjs);
// this adds the photo last as base64 and writes through a temporary file, so a failed save leaves the old file as it
// was. Opening takes the photo out into the PhotoStore before QML reads the rest. Also the autosave backup, kept
// beside Conestructor.ini.
class TrackFile : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit TrackFile(QObject *parent = nullptr) : QObject(parent) {}

    // A file dialog's URL as a path to show or open.
    Q_INVOKABLE QString toLocalPath(const QUrl &url) const;
    // "Duck pond" for ".../Duck pond.cone".
    Q_INVOKABLE QString baseName(const QString &path) const;
    Q_INVOKABLE bool exists(const QString &path) const;
    // Writes the track: "" when written, otherwise a sentence saying what went wrong.
    Q_INVOKABLE QString save(const QString &path, const QString &documentText, int photoRef);
    // { text, photoRef, photoError } or { error: "missing" | "unreadable" | "notJson", message }. `text` is the
    // document without its photo; photoRef is -1 when it had none or it could not be read (then photoError is true).
    Q_INVOKABLE QVariantMap open(const QString &path);

    // The autosave backup: autosave.cone, and autosave.ini saying which track it is and when it was written.
    Q_INVOKABLE QString writeBackup(const QString &documentText, int photoRef, const QString &trackPath,
                                    const QString &name);
    // { path, trackPath, name, time ("14:02") }, or {} when there is no backup.
    Q_INVOKABLE QVariantMap findBackup() const;
    Q_INVOKABLE void deleteBackup();

    static QString saveTo(const QString &path, const QString &documentText, const PhotoStore *photos, int photoRef);
    static QVariantMap openFrom(const QString &path, PhotoStore *photos);
    // The folder holding Conestructor.ini (%APPDATA%\Conestructor).
    static QString backupDir();

private:
    PhotoStore *photos() const;
};
```

Create `app/services/TrackFile.cpp`:

```cpp
#include "TrackFile.h"

#include "PhotoStore.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlEngine>
#include <QSaveFile>
#include <QSettings>

namespace {

QString couldNotWrite(const QString &path, const QString &why)
{
    return TrackFile::tr("Could not write %1: %2").arg(QDir::toNativeSeparators(path), why);
}

QString backupFile()
{
    return QDir(TrackFile::backupDir()).filePath(QStringLiteral("autosave.cone"));
}

QString backupNotes()
{
    return QDir(TrackFile::backupDir()).filePath(QStringLiteral("autosave.ini"));
}

} // namespace

QString TrackFile::toLocalPath(const QUrl &url) const
{
    return url.isLocalFile() ? url.toLocalFile() : url.toString();
}

QString TrackFile::baseName(const QString &path) const
{
    const QString name = QFileInfo(path).fileName();
    return name.endsWith(QStringLiteral(".cone"), Qt::CaseInsensitive) ? name.chopped(5) : name;
}

bool TrackFile::exists(const QString &path) const
{
    return QFileInfo::exists(path);
}

QString TrackFile::save(const QString &path, const QString &documentText, int photoRef)
{
    return saveTo(path, documentText, photos(), photoRef);
}

QVariantMap TrackFile::open(const QString &path)
{
    return openFrom(path, photos());
}

QString TrackFile::saveTo(const QString &path, const QString &documentText, const PhotoStore *photos, int photoRef)
{
    QByteArray text = documentText.toUtf8().trimmed();
    if (!text.startsWith('{') || !text.endsWith('}'))
        return couldNotWrite(path, tr("the track could not be written out"));
    text.chop(1);
    while (!text.isEmpty() && QChar::fromLatin1(text.back()).isSpace())
        text.chop(1);

    QByteArray photo = "null";
    if (photos && photoRef >= 0 && photos->has(photoRef)) {
        const QSize size = photos->size(photoRef);
        photo = "{\n    \"mediaType\": \"" + photos->mediaType(photoRef).toUtf8() + "\",\n    \"width\": "
                + QByteArray::number(size.width()) + ",\n    \"height\": " + QByteArray::number(size.height())
                + ",\n    \"data\": \"" + photos->bytes(photoRef).toBase64() + "\"\n  }";
    }
    text += ",\n  \"photo\": " + photo + "\n}\n";

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return couldNotWrite(path, file.errorString());
    file.write(text);
    if (!file.commit())
        return couldNotWrite(path, file.errorString());
    return {};
}

QVariantMap TrackFile::openFrom(const QString &path, PhotoStore *photos)
{
    QFile file(path);
    if (!file.exists())
        return { { QStringLiteral("error"), QStringLiteral("missing") },
                 { QStringLiteral("message"), tr("%1 isn't there any more.").arg(QDir::toNativeSeparators(path)) } };
    if (!file.open(QIODevice::ReadOnly))
        return { { QStringLiteral("error"), QStringLiteral("unreadable") },
                 { QStringLiteral("message"),
                   tr("Could not read %1: %2").arg(QDir::toNativeSeparators(path), file.errorString()) } };
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject())
        return { { QStringLiteral("error"), QStringLiteral("notJson") } };

    QJsonObject object = doc.object();
    int ref = -1;
    bool photoError = false;
    const QJsonValue photo = object.value(QStringLiteral("photo"));
    if (photo.isObject()) {
        const auto decoded = QByteArray::fromBase64Encoding(
            photo.toObject().value(QStringLiteral("data")).toString().toLatin1(),
            QByteArray::AbortOnBase64DecodingErrors);
        if (decoded && photos)
            ref = photos->add(*decoded);
        photoError = ref < 0;
    } else if (!photo.isNull() && !photo.isUndefined()) {
        photoError = true;
    }
    object.remove(QStringLiteral("photo"));
    return { { QStringLiteral("text"), QString::fromUtf8(QJsonDocument(object).toJson(QJsonDocument::Compact)) },
             { QStringLiteral("photoRef"), ref }, { QStringLiteral("photoError"), photoError } };
}

QString TrackFile::backupDir()
{
    const QSettings ini(QSettings::IniFormat, QSettings::UserScope, QStringLiteral("Conestructor"),
                        QStringLiteral("Conestructor"));
    return QFileInfo(ini.fileName()).absolutePath();
}

QString TrackFile::writeBackup(const QString &documentText, int photoRef, const QString &trackPath,
                               const QString &name)
{
    QDir().mkpath(backupDir());
    const QString error = saveTo(backupFile(), documentText, photos(), photoRef);
    if (!error.isEmpty())
        return error;
    QSettings notes(backupNotes(), QSettings::IniFormat);
    notes.setValue(QStringLiteral("trackPath"), trackPath);
    notes.setValue(QStringLiteral("name"), name);
    notes.setValue(QStringLiteral("time"), QDateTime::currentDateTime().toString(QStringLiteral("HH:mm")));
    notes.sync();
    return {};
}

QVariantMap TrackFile::findBackup() const
{
    if (!QFileInfo::exists(backupFile()))
        return {};
    const QSettings notes(backupNotes(), QSettings::IniFormat);
    return { { QStringLiteral("path"), backupFile() },
             { QStringLiteral("trackPath"), notes.value(QStringLiteral("trackPath")).toString() },
             { QStringLiteral("name"), notes.value(QStringLiteral("name"), tr("Untitled")).toString() },
             { QStringLiteral("time"), notes.value(QStringLiteral("time")).toString() } };
}

void TrackFile::deleteBackup()
{
    QFile::remove(backupFile());
    QFile::remove(backupNotes());
}

PhotoStore *TrackFile::photos() const
{
    QQmlEngine *engine = qmlEngine(this);
    return engine ? engine->singletonInstance<PhotoStore *>("Conestructor", "PhotoStore") : nullptr;
}
```

In `app/CMakeLists.txt` `SOURCES`, replace `services/FileIO.h services/FileIO.cpp` with `services/TrackFile.h services/TrackFile.cpp`, then `git rm app/services/FileIO.h app/services/FileIO.cpp`.

- [ ] **Step 4: Recent files in `Settings`**

In `app/services/Settings.h`: add `Q_PROPERTY(QStringList recentFiles READ recentFiles NOTIFY recentFilesChanged)` under the units property; in `public:`

```cpp
    // Tracks opened or saved lately, newest first, at most eight, with native separators. Paths are compared
    // ignoring case (Windows paths).
    QStringList recentFiles() const { return m_recent; }
    Q_INVOKABLE void addRecentFile(const QString &path);
    Q_INVOKABLE void removeRecentFile(const QString &path);
    Q_INVOKABLE void clearRecentFiles();
```

in `signals:` add `void recentFilesChanged();`, and in `private:` add `void setRecent(const QStringList &list);` and `QStringList m_recent;`. Update the class comment's second sentence to "Part 1 has the units lengths are shown and typed in; part 2 adds the recent files."

In `app/services/Settings.cpp`:
- in the anonymous namespace, add:

```cpp
bool samePath(const QString &a, const QString &b)
{
    return QDir::cleanPath(QDir::fromNativeSeparators(a)).compare(QDir::cleanPath(QDir::fromNativeSeparators(b)),
                                                                 Qt::CaseInsensitive) == 0;
}
```

- in the constructor, after the units are read: `m_recent = ini.value(QStringLiteral("recentFiles")).toStringList();`
- add:

```cpp
void Settings::addRecentFile(const QString &path)
{
    QStringList list{ QDir::toNativeSeparators(path) };
    for (const QString &p : std::as_const(m_recent))
        if (!samePath(p, path) && list.size() < 8)
            list << p;
    setRecent(list);
}

void Settings::removeRecentFile(const QString &path)
{
    QStringList list;
    for (const QString &p : std::as_const(m_recent))
        if (!samePath(p, path))
            list << p;
    setRecent(list);
}

void Settings::clearRecentFiles()
{
    setRecent({});
}

void Settings::setRecent(const QStringList &list)
{
    if (list == m_recent)
        return;
    m_recent = list;
    emit recentFilesChanged();
    save();
}
```

- in `save()`, after `ini.setValue(QStringLiteral("units"), m_units);` add `ini.setValue(QStringLiteral("recentFiles"), m_recent);`.

- [ ] **Step 5: Remove the JSON export from the window**

In `app/qml/Main.qml`, delete the `exportCones()` and `writeExport(url)` functions, the `Action { text: qsTr("Export cones (JSON)…") ... }` line and the `FileDialog { id: exportDialog ... }` block.

In `app/tests/tst_qmlload.cpp`, rename `thePreviewAndTheExport` to `thePreviewAndItsBanners`, change its comment to `// Placing cones draws them; the toggles, Clear preview and the banners for what is missing.`, and delete the block from `// The export: metres, the axes sentence, the target distance, every cone.` down to and including the `QVERIFY(store->property("message").toString().startsWith(QStringLiteral("Exported ")));` line. (Task 9 adds the save and open checks.)

- [ ] **Step 6: Run every test**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed` (tst_trackfile, tst_settings with the four new tests), `qml: … passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git add -A app/services app/tests/tst_trackfile.cpp app/tests/tst_fileio.cpp app/tests/tst_settings.cpp app/tests/CMakeLists.txt app/CMakeLists.txt app/qml/Main.qml app/tests/tst_qmlload.cpp
git commit -m "TrackFile: .cone save/open with the photo last, autosave backup; recent files; the JSON export goes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Save, Open, the title and the unsaved-changes warning

**Files:**
- Modify: `app/qml/TrackStore.qml`, `app/qml/Main.qml`, `app/tests/tst_qmlload.cpp`

**Interfaces:**
- Consumes: `ConeFile.documentText/fromDocument/timestamp/MESSAGES` (Task 7); `TrackFile.save/open/baseName/toLocalPath/deleteBackup`, `Settings.addRecentFile/removeRecentFile/clearRecentFiles/recentFiles` (Task 8); `PhotoStore.clear/remove` (Task 1).
- Produces (TrackStore): `filePath` (string, `""` until saved), `name` (file name without `.cone`, or `Untitled`), `trackText` (JSON of `track`, bound), `savedText`, `dirty` (`trackText !== savedText`), `markSaved()`, `photoRef() -> int`, `documentText(name) -> string`, `newTrack()` (empty, untitled, no undo history, photo store emptied), `saveTo(path) -> bool`, `readTrack(path) -> { track, warning, photoRef } | null` (a banner says why not), `show(read)`, `openPath(path) -> bool`. (Main): `whenSaved(action)`, `save(then)`, `saveAs(then)`, `newTrack()`, `openTrack(path)`, `chooseTrack()`, `openRecent(path)`, `fitSoon()`; the `Dialog` with `objectName: "unsavedDialog"` and buttons `Save`, `Don't save`, `Cancel`; window `title` = `Conestructor 0.3 — <name>` plus `*` when dirty.

- [ ] **Step 1: Write the failing tests**

Add to `app/tests/tst_qmlload.cpp` (with `#include <QDir>` if missing):

```cpp
    // Save writes a .cone the title and Open Recent know about; Open brings it back exactly, with its photo and no
    // undo history; a file that is not a track, or has gone, leaves the open track alone.
    void savingAndOpeningATrack()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QObject *settings = engine.singletonInstance<QObject *>("Conestructor", "Settings");
        auto *photo = window->findChild<QQuickItem *>(QStringLiteral("photo"));
        QVERIFY(store && settings && photo);
        const QString dash = QStringLiteral("Conestructor 0.3 — ");

        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QCOMPARE(window->title(), dash + QStringLiteral("Untitled"));

        // An edit marks it unsaved; undoing back to the saved state clears the mark.
        QVariantMap move{ { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } };
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("place")), Q_ARG(QVariant, move));
        QCOMPARE(window->title(), dash + QStringLiteral("Untitled*"));
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(window->title(), dash + QStringLiteral("Untitled"));
        QMetaObject::invokeMethod(store, "redo");

        // Save, with a lot photo.
        QImage image(200, 100, QImage::Format_RGB32);
        image.fill(Qt::darkGreen);
        const QString picture = dir.filePath(QStringLiteral("save-lot.png"));
        QVERIFY(image.save(picture));
        QMetaObject::invokeMethod(window, "loadPhoto", Q_ARG(QVariant, QVariant(QUrl::fromLocalFile(picture))));
        const QString path = dir.filePath(QStringLiteral("Duck pond.cone"));
        QVariant ok;
        QMetaObject::invokeMethod(store, "saveTo", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, path));
        QVERIFY(ok.toBool());
        QCOMPARE(window->title(), dash + QStringLiteral("Duck pond"));
        QCOMPARE(settings->property("recentFiles").toStringList().value(0), QDir::toNativeSeparators(path));
        const QString saved = store->property("trackText").toString();

        QFile file(path);
        QVERIFY(file.open(QIODevice::ReadOnly));
        const QByteArray raw = file.readAll();
        file.close();
        QVERIFY(raw.startsWith("{\n  \"format\": \"conestructor-track\",\n  \"version\": 1,\n  \"name\": \"Duck pond\""));
        const QJsonObject doc = QJsonDocument::fromJson(raw).object();
        QVERIFY(doc.value(QStringLiteral("cones")).toArray().size() > 40);
        QCOMPARE(doc.value(QStringLiteral("photo")).toObject().value(QStringLiteral("mediaType")).toString(),
                 QStringLiteral("image/png"));
        QCOMPARE(doc.value(QStringLiteral("design")).toObject().value(QStringLiteral("elements")).toArray().size(), 4);

        // New, then open it again: the same track, its photo, no undo history.
        QMetaObject::invokeMethod(store, "newTrack");
        QCOMPARE(store->property("elementCount").toInt(), 0);
        QCOMPARE(window->title(), dash + QStringLiteral("Untitled"));
        QMetaObject::invokeMethod(window, "openTrack", Q_ARG(QVariant, path));
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QCOMPARE(window->title(), dash + QStringLiteral("Duck pond"));
        QVERIFY(!store->property("canUndo").toBool());
        auto withoutRef = [](const QString &text) {
            QJsonObject o = QJsonDocument::fromJson(text.toUtf8()).object();
            QJsonObject p = o.value(QStringLiteral("photo")).toObject();
            p.remove(QStringLiteral("ref"));
            o.insert(QStringLiteral("photo"), p);
            return o;
        };
        QCOMPARE(withoutRef(store->property("trackText").toString()), withoutRef(saved));
        QVERIFY(photo->property("source").toString().startsWith(QStringLiteral("image://photo/")));
        QTRY_COMPARE(photo->property("status").toInt(), 1);
        QCOMPARE(photo->property("implicitWidth").toDouble(), 200.0);

        // Not a track: a banner, and the open track stays.
        const QString notes = dir.filePath(QStringLiteral("notes.cone"));
        QFile bad(notes);
        QVERIFY(bad.open(QIODevice::WriteOnly));
        bad.write("hello");
        bad.close();
        QMetaObject::invokeMethod(window, "openTrack", Q_ARG(QVariant, notes));
        QCOMPARE(findBanner(window)->property("text").toString(), QStringLiteral("That file isn't a Conestructor track."));
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QCOMPARE(window->title(), dash + QStringLiteral("Duck pond"));

        // A recent file that has gone is dropped from the list.
        QVERIFY(QFile::remove(path));
        QMetaObject::invokeMethod(window, "openRecent", Q_ARG(QVariant, path));
        QVERIFY(findBanner(window)->property("text").toString().contains(QStringLiteral("isn't there any more")));
        QVERIFY(!settings->property("recentFiles").toStringList().contains(QDir::toNativeSeparators(path)));
    }

    // New and closing the window ask first when there are unsaved changes; Cancel keeps everything.
    void unsavedChangesAskFirst()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QObject *dialog = window->findChild<QObject *>(QStringLiteral("unsavedDialog"));
        QVERIFY(store && dialog);
        auto click = [&](const QString &text) {
            QQuickItem *button = findButton(window, text);
            QVERIFY2(button, qPrintable(text));
            QTest::mouseClick(window, Qt::LeftButton, {},
                              button->mapToScene(QPointF(button->width() / 2, button->height() / 2)).toPoint());
        };

        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QVariantMap move{ { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } };
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("place")), Q_ARG(QVariant, move));

        QMetaObject::invokeMethod(window, "newTrack");
        QTRY_VERIFY(dialog->property("opened").toBool());
        click(QStringLiteral("Cancel"));
        QTRY_VERIFY(!dialog->property("visible").toBool());
        QCOMPARE(store->property("elementCount").toInt(), 4);

        QMetaObject::invokeMethod(window, "newTrack");
        QTRY_VERIFY(dialog->property("opened").toBool());
        click(QStringLiteral("Don't save"));
        QTRY_COMPARE(store->property("elementCount").toInt(), 0);
        QCOMPARE(window->title(), QStringLiteral("Conestructor 0.3 — Untitled"));

        // Closing with changes asks too; Don't save closes.
        QMetaObject::invokeMethod(window, "useBlueprint");
        window->close();
        QTRY_VERIFY(dialog->property("opened").toBool());
        QVERIFY(window->isVisible());
        click(QStringLiteral("Don't save"));
        QTRY_VERIFY(!window->isVisible());
    }
```

In `thePreviewAndItsBanners`, replace `QMetaObject::invokeMethod(window, "newTrack");` with `QMetaObject::invokeMethod(store, "newTrack");` (the store's New does not ask; the window's does, and this test has moved an element).

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1 -R tst_qmlload -NoQml`
Expected: FAIL — `savingAndOpeningATrack` (no `saveTo`), `unsavedChangesAskFirst` (no `unsavedDialog`), and the title has no name logic.

- [ ] **Step 3: File state in `TrackStore`**

In `app/qml/TrackStore.qml`, add `import Conestructor` and `import "logic/conefile.mjs" as ConeFile` to the imports; update the header comment's last sentence to `... draw from \`track\`. Nothing drawn keeps a copy. It also knows which file the track came from and whether it has changed since.`; add these properties after `readonly property var frame`:

```qml
    // The open file ("" until first saved), the track's name, and whether it differs from what was last saved or
    // opened (undoing back to that state clears it).
    property string filePath: ""
    readonly property string name: filePath !== "" ? TrackFile.baseName(filePath) : qsTr("Untitled")
    readonly property string trackText: JSON.stringify(track)
    property string savedText: JSON.stringify(Commands.emptyTrack())
    readonly property bool dirty: trackText !== savedText
```

and these functions (after `loadTrack`):

```qml
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
        markSaved()
        Settings.addRecentFile(path)
        TrackFile.deleteBackup()
        message = qsTr("Saved %1").arg(path)
        return true
    }

    // Reads a track file: { track, warning, photoRef }, or null after a banner says why not (this track is untouched).
    function readTrack(path) {
        const r = TrackFile.open(path)
        if (r.error) {
            if (r.error === "missing")
                Settings.removeRecentFile(path)
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
        show(read)
        markSaved()
        Settings.addRecentFile(path)
        message = qsTr("Opened %1").arg(path)
        return true
    }
```

- [ ] **Step 4: The window: File menu, title, the question, closing**

In `app/qml/Main.qml`:
- `title: "Conestructor " + AppInfo.shortVersion + " — " + TrackStore.name + (TrackStore.dirty ? "*" : "")`
- replace `function newTrack() {...}` and `function loadDemo(withCones) {...}` with:

```qml
    // What waits on the unsaved-changes question: it runs once the track is saved or let go.
    property var pendingAction: null
    // Set once the person has answered for the track, so closing does not ask twice.
    property bool closing: false

    function fitSoon() {
        canvasView.fitPending = true
        canvasView.tryFit()
    }

    // Runs `action` now when nothing is unsaved; otherwise asks first (Save, Don't save, Cancel).
    function whenSaved(action) {
        if (!TrackStore.dirty) {
            action()
            return
        }
        pendingAction = action
        unsavedDialog.open()
    }

    function takePending() {
        const action = pendingAction
        pendingAction = null
        return action || function() {}
    }

    // Saves to the open file, or asks where first; `then` runs once it is saved.
    function save(then) {
        if (TrackStore.filePath === "") {
            saveAs(then)
            return
        }
        if (TrackStore.saveTo(TrackStore.filePath) && then)
            then()
    }

    function saveAs(then) {
        saveDialog.afterSave = then || null
        saveDialog.open()
    }

    function newTrack() {
        whenSaved(() => {
            TrackStore.newTrack()
            window.fitSoon()
        })
    }

    function openTrack(path) {
        if (TrackStore.openPath(path))
            fitSoon()
    }

    function chooseTrack() {
        whenSaved(() => openDialog.open())
    }

    function openRecent(path) {
        whenSaved(() => window.openTrack(path))
    }

    // For screenshots (CONESTRUCTOR_DEMO) and the tests: the example track, counted as saved.
    function loadDemo(withCones) {
        TrackStore.newTrack()
        TrackStore.loadTrack(Demo.demoTrack())
        TrackStore.markSaved()
        fitSoon()
        if (withCones)
            TrackStore.placeCones()
    }

    onClosing: (close) => {
        if (closing || !TrackStore.dirty) {
            TrackFile.deleteBackup()
            return
        }
        close.accepted = false
        whenSaved(() => {
            window.closing = true
            TrackFile.deleteBackup()
            window.close()
        })
    }
```

- the File menu becomes:

```qml
        Menu {
            id: fileMenu
            title: qsTr("&File")
            Action { text: qsTr("&New"); shortcut: StandardKey.New; onTriggered: window.newTrack() }
            Action { text: qsTr("&Open…"); shortcut: StandardKey.Open; onTriggered: window.chooseTrack() }
            Menu {
                id: recentMenu
                title: qsTr("Open &Recent")
                enabled: Settings.recentFiles.length > 0
                Instantiator {
                    model: Settings.recentFiles
                    delegate: MenuItem {
                        required property string modelData
                        text: modelData
                        onTriggered: window.openRecent(modelData)
                    }
                    onObjectAdded: (index, object) => recentMenu.insertItem(index, object)
                    onObjectRemoved: (index, object) => recentMenu.removeItem(object)
                }
                MenuSeparator {}
                MenuItem { text: qsTr("Clear list"); onTriggered: Settings.clearRecentFiles() }
            }
            Action { text: qsTr("&Save"); shortcut: StandardKey.Save; onTriggered: window.save(null) }
            Action { text: qsTr("Save &As…"); shortcut: "Ctrl+Shift+S"; onTriggered: window.saveAs(null) }
            MenuSeparator {}
            Action { text: qsTr("Load lot photo…"); onTriggered: photoDialog.open() }
            MenuSeparator {}
            Action { text: qsTr("&Quit"); shortcut: StandardKey.Quit; onTriggered: window.close() }
        }
```

- after `FileDialog { id: photoDialog ... }`, add:

```qml
    FileDialog {
        id: openDialog
        title: qsTr("Open track")
        nameFilters: [qsTr("Conestructor tracks (*.cone)")]
        onAccepted: window.openTrack(TrackFile.toLocalPath(selectedFile))
    }

    FileDialog {
        id: saveDialog
        property var afterSave: null      // runs once saved ("result" is the dialog's own)
        title: qsTr("Save track")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("Conestructor tracks (*.cone)")]
        defaultSuffix: "cone"
        onAccepted: {
            const then = afterSave
            afterSave = null
            if (TrackStore.saveTo(TrackFile.toLocalPath(selectedFile)) && then)
                then()
        }
        onRejected: afterSave = null
    }

    Dialog {
        id: unsavedDialog
        objectName: "unsavedDialog"
        anchors.centerIn: Overlay.overlay
        modal: true
        title: qsTr("Unsaved changes")
        Label { text: qsTr("Save changes to %1?").arg(TrackStore.name) }
        footer: DialogButtonBox {
            Button { text: qsTr("Save"); DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole }
            Button { text: qsTr("Don't save"); DialogButtonBox.buttonRole: DialogButtonBox.DestructiveRole }
            Button { text: qsTr("Cancel"); DialogButtonBox.buttonRole: DialogButtonBox.RejectRole }
        }
        onAccepted: window.save(window.takePending())
        onDiscarded: {
            const action = window.takePending()
            unsavedDialog.close()
            TrackFile.deleteBackup()
            action()
        }
        onRejected: window.pendingAction = null
    }
```

- [ ] **Step 5: Run every test**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`, `qml: … passed, 0 failed`. If `Don't save` does not close the dialog or call `onDiscarded`, check that the footer `DialogButtonBox` is the dialog's own (it must be assigned to `footer`) before changing anything else.

- [ ] **Step 6: Commit**

```bash
git add app/qml/TrackStore.qml app/qml/Main.qml app/tests/tst_qmlload.cpp
git commit -m "Save, Open, Open Recent; the title shows the track and unsaved changes; New, Open and closing ask first" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Command line, drag and drop, autosave backup

**Files:**
- Modify: `app/main.cpp`, `app/qml/Main.qml`, `app/qml/TrackStore.qml`, `app/tests/tst_qmlload.cpp`

**Interfaces:**
- Consumes: Task 9's `whenSaved`, `openTrack`, `readTrack`, `show`, `documentText`, `photoRef`; `TrackFile.writeBackup/findBackup/deleteBackup` (Task 8).
- Produces: `Main.start(file)` (called once by `main.cpp`), `Main.dropped(url)`, `Main.backUp()` (the 2-minute timer's job), the `Dialog` with `objectName: "restoreDialog"` and buttons `Restore`, `Discard`; `TrackStore.restoreBackup(backup) -> bool` (opens the backup as unsaved changes to `backup.trackPath`).

- [ ] **Step 1: Write the failing tests**

Add to `app/tests/tst_qmlload.cpp`:

```cpp
    // A track named on the command line opens at start-up.
    void aFileNamedAtStartOpens()
    {
        const QString path = dir.filePath(QStringLiteral("Start.cone"));
        {
            QQmlApplicationEngine engine;
            engine.loadFromModule("Conestructor", "Main");
            QObject *window = engine.rootObjects().first();
            QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
            // No backup from an earlier test, so start() goes straight to the file.
            QMetaObject::invokeMethod(engine.singletonInstance<QObject *>("Conestructor", "TrackFile"), "deleteBackup");
            QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
            QVariant ok;
            QMetaObject::invokeMethod(store, "saveTo", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, path));
            QVERIFY(ok.toBool());
        }
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QMetaObject::invokeMethod(window, "start", Q_ARG(QVariant, path));
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QCOMPARE(window->title(), QStringLiteral("Conestructor 0.3 — Start"));
    }

    // Unsaved changes are backed up; at the next start the backup is offered; Discard forgets it; Save removes it.
    void aBackupIsOfferedAtStart()
    {
        auto click = [](QQuickWindow *window, const QString &text) {
            QQuickItem *button = findButton(window, text);
            QVERIFY2(button, qPrintable(text));
            QTest::mouseClick(window, Qt::LeftButton, {},
                              button->mapToScene(QPointF(button->width() / 2, button->height() / 2)).toPoint());
        };
        auto backup = [](QQmlApplicationEngine &engine) {
            QObject *files = engine.singletonInstance<QObject *>("Conestructor", "TrackFile");
            QVariantMap found;
            QMetaObject::invokeMethod(files, "findBackup", Q_RETURN_ARG(QVariantMap, found));
            return found;
        };
        {
            QQmlApplicationEngine engine;
            engine.loadFromModule("Conestructor", "Main");
            QObject *window = engine.rootObjects().first();
            QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
            QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
            QMetaObject::invokeMethod(window, "backUp");
            QVERIFY(backup(engine).isEmpty());                       // nothing unsaved, nothing backed up
            QVariantMap move{ { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } };
            QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("place")), Q_ARG(QVariant, move));
            QMetaObject::invokeMethod(window, "backUp");
            QCOMPARE(backup(engine).value(QStringLiteral("name")).toString(), QStringLiteral("Untitled"));
            // engine goes without a normal close: the backup stays, as after a crash
        }
        {
            QQmlApplicationEngine engine;
            engine.loadFromModule("Conestructor", "Main");
            auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
            QVERIFY(QTest::qWaitForWindowExposed(window));
            QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
            QObject *dialog = window->findChild<QObject *>(QStringLiteral("restoreDialog"));
            QVERIFY(dialog);
            QMetaObject::invokeMethod(window, "start", Q_ARG(QVariant, QString()));
            QTRY_VERIFY(dialog->property("opened").toBool());
            click(window, QStringLiteral("Restore"));
            QTRY_COMPARE(store->property("elementCount").toInt(), 4);
            QVERIFY(store->property("dirty").toBool());
            QCOMPARE(window->title(), QStringLiteral("Conestructor 0.3 — Untitled*"));
            QVERIFY(!backup(engine).isEmpty());                      // kept until saved or closed normally
            const QString path = dir.filePath(QStringLiteral("Restored.cone"));
            QVariant ok;
            QMetaObject::invokeMethod(store, "saveTo", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, path));
            QVERIFY(ok.toBool());
            QVERIFY(backup(engine).isEmpty());
        }
        {
            QQmlApplicationEngine engine;
            engine.loadFromModule("Conestructor", "Main");
            auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
            QVERIFY(QTest::qWaitForWindowExposed(window));
            QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
            QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
            QVariantMap move{ { "id", "e2" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } };
            QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("place")), Q_ARG(QVariant, move));
            QMetaObject::invokeMethod(window, "backUp");
            QMetaObject::invokeMethod(store, "newTrack");
            QMetaObject::invokeMethod(window, "start", Q_ARG(QVariant, QString()));
            QObject *dialog = window->findChild<QObject *>(QStringLiteral("restoreDialog"));
            QTRY_VERIFY(dialog->property("opened").toBool());
            click(window, QStringLiteral("Discard"));
            QTRY_VERIFY(backup(engine).isEmpty());
            QCOMPARE(store->property("elementCount").toInt(), 0);
        }
    }

    // Dropping a .cone opens it, a PNG or JPG becomes the lot photo, anything else gets a note.
    void droppingFilesOnTheWindow()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        const QString track = dir.filePath(QStringLiteral("Dropped.cone"));
        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QVariant ok;
        QMetaObject::invokeMethod(store, "saveTo", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, track));
        QMetaObject::invokeMethod(store, "newTrack");

        QMetaObject::invokeMethod(window, "dropped", Q_ARG(QVariant, QVariant(QUrl::fromLocalFile(track))));
        QCOMPARE(store->property("elementCount").toInt(), 4);

        QImage image(40, 30, QImage::Format_RGB32);
        image.fill(Qt::gray);
        const QString picture = dir.filePath(QStringLiteral("dropped.jpg"));
        QVERIFY(image.save(picture));
        QMetaObject::invokeMethod(window, "dropped", Q_ARG(QVariant, QVariant(QUrl::fromLocalFile(picture))));
        QCOMPARE(qvariant_cast<QJSValue>(store->property("track")).property("photo").property("kind").toString(),
                 QStringLiteral("image"));

        QMetaObject::invokeMethod(window, "dropped",
                                  Q_ARG(QVariant, QVariant(QUrl::fromLocalFile(dir.filePath(QStringLiteral("notes.txt"))))));
        QCOMPARE(findBanner(window)->property("text").toString(), QStringLiteral("Drop a .cone track or a PNG or JPG photo."));
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1 -R tst_qmlload -NoQml`
Expected: FAIL — no `start`, `backUp`, `dropped`, `restoreDialog`.

- [ ] **Step 3: Restoring a backup in `TrackStore`**

Add to `app/qml/TrackStore.qml` after `openPath`:

```qml
    // Opens the autosave backup as unsaved changes to the track it came from (`backup` from TrackFile.findBackup).
    function restoreBackup(backup) {
        const read = readTrack(backup.path)
        if (!read)
            return false
        filePath = backup.trackPath
        show(read)
        savedText = ""          // nothing on disk matches it: it stays unsaved until saved
        message = qsTr("Restored %1 from the backup made at %2").arg(name).arg(backup.time)
        return true
    }
```

- [ ] **Step 4: Start-up, dropping and the backup timer in the window**

In `app/qml/Main.qml`, add after `loadDemo`:

```qml
    // Called once by main.cpp when the window opens: offers a backup left by a crash, then opens `file` (the track
    // named on the command line, or "").
    function start(file) {
        const backup = TrackFile.findBackup()
        if (backup.path) {
            restoreDialog.backup = backup
            restoreDialog.file = file
            restoreDialog.open()
        } else if (file !== "") {
            openTrack(file)
        }
    }

    function afterRestoreQuestion(file) {
        if (file !== "")
            whenSaved(() => window.openTrack(file))
    }

    // A file dropped on the window: a .cone opens, a PNG or JPG becomes the lot photo.
    function dropped(url) {
        const path = TrackFile.toLocalPath(url)
        const lower = path.toLowerCase()
        if (lower.endsWith(".cone"))
            whenSaved(() => window.openTrack(path))
        else if (/\.(png|jpe?g)$/.test(lower))
            loadPhoto(url)
        else
            TrackStore.report(qsTr("Drop a .cone track or a PNG or JPG photo."), null)
    }

    // The track text last backed up, so an unchanged track is not written again.
    property string backedUpText: ""

    // Every two minutes: backs up unsaved changes that are not backed up yet. A failed write says nothing (it is a
    // safety net) and is tried again next time.
    function backUp() {
        if (!TrackStore.dirty || TrackStore.trackText === backedUpText)
            return
        const error = TrackFile.writeBackup(TrackStore.documentText(TrackStore.name), TrackStore.photoRef(),
                                            TrackStore.filePath, TrackStore.name)
        if (error === "")
            backedUpText = TrackStore.trackText
    }

    Timer {
        interval: 120000
        repeat: true
        running: true
        onTriggered: window.backUp()
    }
```

after the `RowLayout { ... }` that holds the canvas and side panel, add:

```qml
    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (drop.hasUrls && drop.urls.length > 0) {
                drop.accept(Qt.CopyAction)
                window.dropped(drop.urls[0])
            }
        }
    }
```

and after the `unsavedDialog`:

```qml
    Dialog {
        id: restoreDialog
        objectName: "restoreDialog"
        property var backup: ({})
        property string file: ""
        anchors.centerIn: Overlay.overlay
        modal: true
        closePolicy: Popup.NoAutoClose
        title: qsTr("Restore unsaved work?")
        Label {
            width: 420
            wrapMode: Text.WordWrap
            text: qsTr("Conestructor closed without saving %1 (backed up at %2). Restore it?")
                  .arg(restoreDialog.backup.name || "").arg(restoreDialog.backup.time || "")
        }
        footer: DialogButtonBox {
            Button { text: qsTr("Restore"); DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole }
            Button { text: qsTr("Discard"); DialogButtonBox.buttonRole: DialogButtonBox.DestructiveRole }
        }
        onAccepted: {
            if (TrackStore.restoreBackup(backup))
                window.fitSoon()
            window.afterRestoreQuestion(file)
        }
        onDiscarded: {
            restoreDialog.close()
            TrackFile.deleteBackup()
            window.afterRestoreQuestion(file)
        }
    }
```

- [ ] **Step 5: `main.cpp` calls `start`**

In `app/main.cpp`, after `QObject *root = engine.rootObjects().first();`, add:

```cpp
    // Offer a backup left by a crash, then open the track named on the command line (Conestructor.exe "x.cone").
    const QStringList args = QCoreApplication::arguments();
    QMetaObject::invokeMethod(root, "start", Q_ARG(QVariant, QVariant(args.size() > 1 ? args.at(1) : QString())));
```

- [ ] **Step 6: Run every test, then try it**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`, `qml: … passed, 0 failed`.

Then start the built app with a file argument to see it open (`build\tests\appConestructor.exe "<a .cone you saved>"` with `CONESTRUCTOR_SETTINGS_DIR` set to a scratch folder so the owner's settings and backup are not touched).

- [ ] **Step 7: Commit**

```bash
git add app/main.cpp app/qml/Main.qml app/qml/TrackStore.qml app/tests/tst_qmlload.cpp
git commit -m "Open a track from the command line or by dropping it; autosave backup with Restore at start-up" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: The setup checklist

**Files:**
- Create: `app/qml/SetupChecklist.qml`, `app/qml/PaletteTile.qml`
- Modify: `app/qml/ElementPalette.qml`, `app/qml/Main.qml` (side column), `app/CMakeLists.txt` (QML_FILES), `app/tests/tst_qmlload.cpp`

**Interfaces:**
- Consumes: `Setup.status` (Task 7); `Main.useBlueprint`, `photoDialog` (Task 2); `CanvasView.beginPlacing/updatePlacing/finishPlacing` (part 1).
- Produces: `PaletteTile { canvas, kind, name, colour, tip, usable, lockedTip }` (one draggable tile); `SetupChecklist { canvas; signal loadPhoto(); signal useBlueprint(); status; done; open; unfolded }` with `objectName: "setupChecklist"` in Main; `ElementPalette` shows only the four track tiles, usable once setup is done (`lockedTip` "Finish setup first.").

- [ ] **Step 1: Write the failing test**

Add to `app/tests/tst_qmlload.cpp`:

```cpp
    // The checklist ticks each step; the track tiles unlock with all four and lock again when one comes undone.
    void theChecklistUnlocksTheTrackPieces()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        auto *checklist = window->findChild<QQuickItem *>(QStringLiteral("setupChecklist"));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QVERIFY(canvas && checklist && store);
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);
        auto count = [&]() { return qvariant_cast<QJSValue>(checklist->property("status")).property("count").toInt(); };
        auto tile = [&](const QString &kind) -> QQuickItem * {
            for (QQuickItem *item : allItems(window->contentItem()))
                if (QByteArray(item->metaObject()->className()).startsWith("PaletteTile")
                    && item->property("kind").toString() == kind)
                    return item;
            return nullptr;
        };
        QVERIFY(tile(QStringLiteral("straight")) && tile(QStringLiteral("ruler")));
        QCOMPARE(count(), 0);
        QVERIFY(!tile(QStringLiteral("straight"))->property("usable").toBool());

        QQuickItem *blueprint = findButton(window, QStringLiteral("Use the blueprint"));
        QVERIFY(blueprint);
        QTest::mouseClick(window, Qt::LeftButton, {},
                          blueprint->mapToScene(QPointF(blueprint->width() / 2, blueprint->height() / 2)).toPoint());
        QCOMPARE(count(), 1);

        QVariantMap ruler{ { "a", QVariantMap{ { "x", 100 }, { "y", 100 } } },
                           { "b", QVariantMap{ { "x", 300 }, { "y", 100 } } }, { "realLength", 20 } };
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("setRuler")), Q_ARG(QVariant, ruler));
        QMetaObject::invokeMethod(canvas, "beginPlacing", Q_ARG(QVariant, QStringLiteral("origin")));
        QMetaObject::invokeMethod(canvas, "finishPlacing", Q_ARG(QVariant, 300.0), Q_ARG(QVariant, 300.0));
        QCOMPARE(count(), 3);
        QVERIFY(!tile(QStringLiteral("straight"))->property("usable").toBool());
        QMetaObject::invokeMethod(canvas, "beginPlacing", Q_ARG(QVariant, QStringLiteral("direction")));
        QMetaObject::invokeMethod(canvas, "finishPlacing", Q_ARG(QVariant, 700.0), Q_ARG(QVariant, 300.0));
        QCOMPARE(count(), 4);
        QVERIFY(tile(QStringLiteral("straight"))->property("usable").toBool());
        QVERIFY(!tile(QStringLiteral("ruler"))->property("usable").toBool());       // one ruler per track
        QVERIFY(checklist->property("done").toBool());
        QVERIFY(!checklist->property("open").toBool());                               // folded to one line

        // A step that comes undone locks the track tiles again and unfolds the list.
        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QStringLiteral("direction")));
        QMetaObject::invokeMethod(store, "deleteSelected");
        QCOMPARE(count(), 3);
        QVERIFY(!tile(QStringLiteral("straight"))->property("usable").toBool());
        QVERIFY(checklist->property("open").toBool());
    }
```

- [ ] **Step 2: Run it to see it fail**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1 -R tst_qmlload -NoQml`
Expected: FAIL — no `setupChecklist`.

- [ ] **Step 3: One tile component**

Create `app/qml/PaletteTile.qml` (the tile from `ElementPalette.qml`, made reusable):

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor

// One tile dragged from the side panel onto the canvas: a track element, the ruler or a target.
Rectangle {
    id: tile
    required property CanvasView canvas
    required property string kind
    required property string name
    required property color colour
    required property string tip
    property bool usable: true
    property string lockedTip: ""

    Layout.fillWidth: true
    Layout.preferredHeight: 52
    implicitWidth: 110
    implicitHeight: 52
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
        color: tile.colour
    }
    Label {
        anchors.centerIn: parent
        text: tile.name
        color: "#f0f0f0"
    }

    ToolTip.visible: area.containsMouse
    ToolTip.delay: 400
    ToolTip.text: !usable && lockedTip !== "" ? lockedTip : tip

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
            tile.canvas.beginPlacing(tile.kind)
        }
        onPositionChanged: (mouse) => {
            if (!pressed)
                return
            const p = mapToItem(tile.canvas, mouse.x, mouse.y)
            tile.canvas.updatePlacing(p.x, p.y, (mouse.modifiers & Qt.ControlModifier) !== 0)
        }
        onReleased: (mouse) => {
            const p = mapToItem(tile.canvas, mouse.x, mouse.y)
            tile.canvas.finishPlacing(p.x, p.y)
        }
    }
}
```

Replace `app/qml/ElementPalette.qml` with:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/elements.mjs" as Elements
import "logic/setup.mjs" as Setup

// The track tiles dragged onto the canvas. They unlock once setup is done (SetupChecklist holds the ruler and
// target tiles).
GridLayout {
    id: grid      // not "palette": inside each tile that name means the tile's own palette property
    required property CanvasView canvas

    columns: 2
    rowSpacing: 8
    columnSpacing: 8

    readonly property bool unlocked: Setup.status(TrackStore.track).done
    readonly property var tiles: Elements.TYPES.map(type => ({ kind: type, name: Elements.NAMES[type],
                                                               colour: Elements.COLOURS[type], tip: Elements.TIPS[type] }))

    Repeater {
        model: grid.tiles
        delegate: PaletteTile {
            required property var modelData
            canvas: grid.canvas
            kind: modelData.kind
            name: modelData.name
            colour: modelData.colour
            tip: modelData.tip
            usable: grid.unlocked
            lockedTip: qsTr("Finish setup first.")
        }
    }
}
```

- [ ] **Step 4: The checklist**

Create `app/qml/SetupChecklist.qml`:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor
import "logic/setup.mjs" as Setup

// The four setup steps at the top of the side panel: photo, ruler, Origin, Direction. Each row ticks when its step is
// done; the ruler and target rows hold the tiles dragged onto the canvas. With every step done it folds to one line
// (click it to unfold); a step that comes undone unfolds it again.
ColumnLayout {
    id: checklist
    required property CanvasView canvas
    signal loadPhoto()
    signal useBlueprint()

    readonly property var status: Setup.status(TrackStore.track)
    readonly property bool done: status.done
    property bool unfolded: false
    readonly property bool open: !done || unfolded
    onDoneChanged: unfolded = false

    spacing: 6

    // A step's number, or a tick once it is done.
    component Tick: Label {
        required property bool ticked
        required property int number
        text: ticked ? "✓" : String(number)
        color: ticked ? "#4caf50" : "#b0b0b0"
        font.bold: true
        Layout.preferredWidth: 18
    }

    // A step placed by dragging its tile onto the canvas.
    component Step: ColumnLayout {
        id: step
        required property CanvasView canvas
        required property bool ticked
        required property int number
        required property string kind
        required property string name
        required property color colour
        required property string hint
        required property bool placed
        Layout.fillWidth: true
        spacing: 2
        RowLayout {
            Tick { ticked: step.ticked; number: step.number }
            PaletteTile {
                canvas: step.canvas
                kind: step.kind
                name: step.name
                colour: step.colour
                tip: step.hint
                usable: !step.placed
                Layout.fillWidth: false
                Layout.preferredWidth: 110
                Layout.preferredHeight: 36
            }
        }
        Label {
            Layout.leftMargin: 24
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: step.hint
            color: "#b0b0b0"
            font.pixelSize: 11
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Label {
            text: checklist.done ? qsTr("Setup ✓ (photo, ruler, targets)") : qsTr("Setup")
            font.bold: true
            color: checklist.done ? "#4caf50" : "#ffffff"
        }
        Item { Layout.fillWidth: true }
        Label {
            visible: !checklist.done
            text: qsTr("%1 of 4").arg(checklist.status.count)
            color: "#b0b0b0"
        }
        TapHandler {
            enabled: checklist.done
            onTapped: checklist.unfolded = !checklist.unfolded
        }
    }

    ColumnLayout {
        visible: checklist.open
        spacing: 2
        RowLayout {
            Tick { ticked: checklist.status.photo; number: 1 }
            Label { text: qsTr("Photo"); color: "#e0e0e0" }
        }
        RowLayout {
            Layout.leftMargin: 24
            Button {
                text: qsTr("Load lot photo…")
                focusPolicy: Qt.NoFocus
                onClicked: checklist.loadPhoto()
            }
            Button {
                text: qsTr("Use the blueprint")
                focusPolicy: Qt.NoFocus
                onClicked: checklist.useBlueprint()
            }
        }
    }

    Step {
        visible: checklist.open
        canvas: checklist.canvas
        number: 2
        kind: "ruler"
        name: qsTr("Ruler")
        colour: "#f5cb42"
        ticked: checklist.status.ruler
        placed: TrackStore.track.ruler !== null
        hint: qsTr("Drag onto something you know the length of, such as a parking space, then type its real length.")
    }
    Step {
        visible: checklist.open
        canvas: checklist.canvas
        number: 3
        kind: "origin"
        name: qsTr("Origin")
        colour: "#00ffff"
        ticked: checklist.status.origin
        placed: TrackStore.track.targets.origin !== null
        hint: qsTr("x and y are measured from here.")
    }
    Step {
        visible: checklist.open
        canvas: checklist.canvas
        number: 4
        kind: "direction"
        name: qsTr("Direction")
        colour: "#00ffff"
        ticked: checklist.status.direction
        placed: TrackStore.track.targets.direction !== null
        hint: qsTr("x points from Origin toward here, at least 1 m away.")
    }

    Label {
        visible: !checklist.done
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("Track pieces unlock when setup is done.")
        color: "#b0b0b0"
    }
}
```

Add `qml/SetupChecklist.qml` and `qml/PaletteTile.qml` to `QML_FILES` in `app/CMakeLists.txt` (after `qml/ElementPalette.qml`).

In `app/qml/Main.qml`, in `sideColumn` before `ElementPalette`, add:

```qml
                SetupChecklist {
                    objectName: "setupChecklist"
                    canvas: canvasView
                    Layout.fillWidth: true
                    onLoadPhoto: photoDialog.open()
                    onUseBlueprint: window.useBlueprint()
                }
```

- [ ] **Step 5: Run every test and look at it**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`, `qml: … passed, 0 failed`.
Then `powershell -NoProfile -File app\tests\grab.ps1 -Demo ''` and open `app\build\tests\grab.png`: the checklist sits at the top of the side panel, unticked, with the four greyed track tiles under it; nothing overflows the 300 px panel. Then `grab.ps1 -Demo track`: the checklist is one green line.

- [ ] **Step 6: Commit**

```bash
git add app/qml/SetupChecklist.qml app/qml/PaletteTile.qml app/qml/ElementPalette.qml app/qml/Main.qml app/CMakeLists.txt app/tests/tst_qmlload.cpp
git commit -m "Setup checklist (photo, ruler, Origin, Direction) unlocks the track tiles" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Arrows, the ⚠, Reverse direction and typed rotation on screen

**Files:**
- Modify: `app/qml/ElementView.qml`, `app/qml/CanvasView.qml`, `app/qml/TrackStore.qml`, `app/qml/Main.qml` (Edit menu), `app/qml/PropertyPanel.qml`, `app/qml/PropField.qml`, `app/tests/tst_qmlload.cpp`

**Interfaces:**
- Consumes: `Elements.arrowMarks/pointsAlong` (Task 3), `Post.backwards` (Task 4), commands `reverse`, `rotateChain` and `Frame.headingFromFrame` (Task 5).
- Produces: `TrackStore.backwardIds` (array), `TrackStore.reverseSelected()`; `ElementView.backwards`, `ElementView.arrows`, `ElementView.middle` (canvas metres); `CanvasView.hoverWarning` (id of the backwards element whose ⚠ is under the cursor, or `""`) and a tip label `objectName: "warningTip"`; Edit › Reverse direction and the right-click menu's Reverse direction; `PropField.stepSize` (0 = the unit's step) and `PropField.bigStep` (Shift+arrow, 0 = none); the panel's `Rotation` field. `tst_qmlload` gains file-level helpers `findField(window, label)` and `textBox(field)`.

- [ ] **Step 1: Write the failing test**

In `app/tests/tst_qmlload.cpp`, add these file-level helpers after `findButton` (and use them in place of the `field`/`box` lambdas in `thePropertyPanelEditsTheSelection` if you like; they do the same):

```cpp
// The visible setting with this label.
static QQuickItem *findField(QQuickWindow *window, const QString &label)
{
    for (QQuickItem *item : allItems(window->contentItem())) {
        const QVariant def = item->property("def");
        if (def.isValid() && item->isVisible() && def.toMap().value(QStringLiteral("label")).toString() == label)
            return item;
    }
    return nullptr;
}

static QQuickItem *textBox(QQuickItem *field)
{
    for (QQuickItem *item : allItems(field))
        if (QByteArray(item->metaObject()->className()).contains("TextField"))
            return item;
    return nullptr;
}
```

and the test:

```cpp
    // Every element shows arrows; reversing a turn in the middle of a chain flags it with a ⚠ (with a tip on hover)
    // and reversing it back clears it; typing a rotation turns the chain.
    void arrowsReverseAndTypedRotation()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        window->requestActivate();
        QVERIFY(QTest::qWaitForWindowActive(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QVERIFY(canvas && store);
        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);

        auto element = [&](const QString &id) {
            QVariant v;
            QMetaObject::invokeMethod(store, "element", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, id));
            return qvariant_cast<QJSValue>(v).toVariant().toMap();
        };
        auto view = [&](const QString &id) -> QQuickItem * {
            for (QQuickItem *item : allItems(canvas))
                if (QByteArray(item->metaObject()->className()).startsWith("ElementView")
                    && qvariant_cast<QJSValue>(item->property("element")).property("id").toString() == id)
                    return item;
            return nullptr;
        };
        auto backwardIds = [&]() {
            return qvariant_cast<QJSValue>(store->property("backwardIds")).toVariant().toStringList();
        };
        auto label = [&]() { return store->property("undoLabel").toString(); };

        for (const QString id : { QStringLiteral("e1"), QStringLiteral("e2"), QStringLiteral("e3"), QStringLiteral("e4") })
            QVERIFY2(qvariant_cast<QJSValue>(view(id)->property("arrows")).property("length").toInt() >= 2, qPrintable(id));
        QVERIFY(backwardIds().isEmpty());

        // Reverse the turn in the middle: it now runs against the track.
        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QStringLiteral("e3")));
        QMetaObject::invokeMethod(store, "reverseSelected");
        QCOMPARE(label(), QStringLiteral("Reverse Turn"));
        QCOMPARE(element(QStringLiteral("e3")).value("props").toMap().value("direction").toString(), QStringLiteral("left"));
        QCOMPARE(element(QStringLiteral("e2")).value("joins").toMap().value("B").toMap().value("id").toString(), QStringLiteral("e3"));
        QCOMPARE(element(QStringLiteral("e4")).value("joins").toMap().value("A").toMap().value("id").toString(), QStringLiteral("e3"));
        QCOMPARE(backwardIds(), QStringList({ QStringLiteral("e3") }));
        QVERIFY(view(QStringLiteral("e3"))->property("backwards").toBool());

        // Hovering its ⚠ shows the tip.
        const double mpp = store->property("mpp").toDouble();
        const QVariantMap middle = qvariant_cast<QJSValue>(view(QStringLiteral("e3"))->property("middle")).toVariant().toMap();
        QVariant at;
        QMetaObject::invokeMethod(canvas, "toScreen", Q_RETURN_ARG(QVariant, at),
                                  Q_ARG(QVariant, middle.value("x").toDouble() / mpp),
                                  Q_ARG(QVariant, middle.value("y").toDouble() / mpp));
        const QVariantMap s = qvariant_cast<QJSValue>(at).toVariant().toMap();
        QTest::mouseMove(window, canvas->mapToScene(QPointF(s.value("x").toDouble(), s.value("y").toDouble())).toPoint());
        QTRY_COMPARE(canvas->property("hoverWarning").toString(), QStringLiteral("e3"));
        auto *tip = window->findChild<QQuickItem *>(QStringLiteral("warningTip"));
        QVERIFY(tip && tip->isVisible());

        // Reversing it back clears the ⚠.
        QMetaObject::invokeMethod(store, "reverseSelected");
        QVERIFY(backwardIds().isEmpty());

        // Typed rotation: 90° turns the whole chain; one undo puts it back; the arrows step 1° and Shift 15°.
        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QStringLiteral("e1")));
        QQuickItem *rotation = findField(window, QStringLiteral("Rotation"));
        QVERIFY(rotation);
        QQuickItem *input = textBox(rotation);
        QCOMPARE(input->property("text").toString(), QStringLiteral("0°"));
        QTest::mouseClick(window, Qt::LeftButton, {}, input->mapToScene(QPointF(input->width() / 2, input->height() / 2)).toPoint());
        QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
        QTest::keyClick(window, '9');
        QTest::keyClick(window, '0');
        QCOMPARE(element(QStringLiteral("e1")).value("rotation").toDouble(), -90.0);   // canvas headings are clockwise
        QVERIFY(!element(QStringLiteral("e1")).value("joins").toMap().value("B").isNull());
        QTest::keyClick(window, Qt::Key_Return);
        QCOMPARE(label(), QStringLiteral("Rotate Straight"));
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(element(QStringLiteral("e1")).value("rotation").toDouble(), 0.0);
        QTest::mouseClick(window, Qt::LeftButton, {}, input->mapToScene(QPointF(input->width() / 2, input->height() / 2)).toPoint());
        QTest::keyClick(window, Qt::Key_Up);
        QCOMPARE(element(QStringLiteral("e1")).value("rotation").toDouble(), -1.0);
        QTest::keyClick(window, Qt::Key_Up, Qt::ShiftModifier);
        QCOMPARE(element(QStringLiteral("e1")).value("rotation").toDouble(), -16.0);
    }
```

- [ ] **Step 2: Run it to see it fail**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1 -R tst_qmlload -NoQml`
Expected: FAIL — no `arrows` on ElementView, no `reverseSelected`, no Rotation field.

- [ ] **Step 3: Which elements run backwards, and Reverse**

In `app/qml/TrackStore.qml`, after `readonly property var selectedElement`, add:

```qml
    // Elements driven against the rest of their chain: they show a ⚠ (Reverse direction fixes it).
    readonly property var backwardIds: Post.backwards(track.elements)
```

and after `duplicateSelected`:

```qml
    function reverseSelected() {
        if (!selectedElement)
            return
        run("reverse", { ids: [selectedElement.id] })
        stack.seal()
    }
```

In `app/qml/Main.qml` Edit menu, after the Delete action, add:

```qml
            Action {
                text: qsTr("Reverse direction")
                enabled: TrackStore.selectedElement !== null
                onTriggered: TrackStore.reverseSelected()
            }
```

In `app/qml/CanvasView.qml` `elementMenu`, add `MenuItem { text: qsTr("Reverse direction"); onTriggered: TrackStore.reverseSelected() }` after Delete.

- [ ] **Step 4: Draw the arrows and the ⚠**

In `app/qml/ElementView.qml`, add `import QtQuick.Controls` to the imports, change the header comment's first sentence to end `... a green dot at each joined end, and white arrows along the centreline pointing the way it is driven (entry to exit). An element driven against its chain shows a ⚠.`, and add:

```qml
    property bool backwards: false
    readonly property var arrows: drawable ? Elements.arrowMarks(element, 8) : []
    // The middle of the centreline (canvas metres), where the ⚠ sits.
    readonly property var middle: drawable ? Elements.pointsAlong(element, [0.5])[0] : null
```

and, after the `Shape { ... }` block:

```qml
    // Arrows: chevrons a fixed size on screen, pointing along the centreline.
    Repeater {
        model: view.arrows
        Shape {
            required property var modelData
            x: modelData.x / view.mpp
            y: modelData.y / view.mpp
            rotation: modelData.heading
            scale: 1 / view.zoom
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#ffffff"
                strokeWidth: 2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: -4
                startY: -6
                PathLine { x: 4; y: 0 }
                PathLine { x: -4; y: 6 }
            }
        }
    }

    Label {
        visible: view.backwards && view.middle !== null
        text: "⚠"
        color: "#ffb300"
        font.pixelSize: 20
        style: Text.Outline
        styleColor: "#000000"
        scale: 1 / view.zoom
        x: view.middle ? view.middle.x / view.mpp - width / 2 : 0
        y: view.middle ? view.middle.y / view.mpp - height / 2 : 0
    }
```

In `app/qml/CanvasView.qml`:
- the ElementView delegate gains `backwards: element !== null && TrackStore.backwardIds.indexOf(element.id) >= 0`
- add, after `property var ghost`:

```qml
    // The backwards element whose ⚠ is under the cursor ("" when none), for its tip.
    readonly property string hoverWarning: {
        if (!hover || !(mpp > 0))
            return ""
        const h = toScreen(hover.x, hover.y)
        for (const id of TrackStore.backwardIds) {
            const el = TrackStore.element(id)
            if (!el)
                continue
            const m = Elements.pointsAlong(el, [0.5])[0]
            const s = toScreen(m.x / mpp, m.y / mpp)
            if (Math.hypot(s.x - h.x, s.y - h.y) < 14)
                return id
        }
        return ""
    }
```

- in the `overlay` item, add:

```qml
        Label {
            objectName: "warningTip"
            visible: canvas.hoverWarning !== "" && canvas.hover !== null
            x: canvas.hover ? canvas.toScreen(canvas.hover.x, canvas.hover.y).x + 16 : 0
            y: canvas.hover ? canvas.toScreen(canvas.hover.x, canvas.hover.y).y + 12 : 0
            text: qsTr("Runs against the track: right-click › Reverse direction")
            color: "#f0f0f0"
            padding: 6
            background: Rectangle { color: "#333333"; radius: 4; border.color: "#ffb300" }
        }
```

- [ ] **Step 5: Typed rotation**

In `app/qml/PropField.qml`:
- add properties after `emptyWhenZero`:

```qml
    property real stepSize: 0       // what the arrows step by; 0 means the unit's usual step
    property real bigStep: 0        // what Shift+arrow steps by; 0 means the same as the arrows
```

- `step` becomes:

```qml
    function step(direction, big) {
        const size = big && bigStep > 0 ? bigStep : stepSize > 0 ? stepSize : Units.stepFor(def.kind, unit)
        const stored = apply(Number(value) + direction * size)
        input.text = Units.formatValue(def.kind, stored, unit)
        bad = false
    }
```

- the key handlers become `Keys.onUpPressed: (e) => field.step(1, (e.modifiers & Qt.ShiftModifier) !== 0)` and `Keys.onDownPressed: (e) => field.step(-1, (e.modifiers & Qt.ShiftModifier) !== 0)`; the ▲ ▼ buttons call `field.step(1, false)` and `field.step(-1, false)`.

In `app/qml/PropertyPanel.qml`, replace the `Rotation   %1` Label with:

```qml
        // Degrees counter-clockwise from the Origin -> Direction axis. Typing turns the element's whole joined chain.
        PropField {
            visible: panel.framePosition !== null
            def: ({ key: "rotation", label: qsTr("Rotation"), kind: "angle", min: -360, max: 360 })
            value: panel.frameRotation
            stepSize: 1
            bigStep: 15
            onEdited: (v) => TrackStore.run("rotateChain", { id: panel.el.id,
                                                             rotation: Frame.headingFromFrame(TrackStore.frame, v),
                                                             mergeKey: "rotation:" + panel.el.id })
            onFinished: TrackStore.seal()
        }
```

- [ ] **Step 6: Run every test and look at it**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`, `qml: … passed, 0 failed`.
Then `powershell -NoProfile -File app\tests\grab.ps1 -Demo track` and look at `app\build\tests\grab.png`: white chevrons along every element, pointing from the straight toward the chicane, readable and not cluttering the bands.

- [ ] **Step 7: Commit**

```bash
git add app/qml/ElementView.qml app/qml/CanvasView.qml app/qml/TrackStore.qml app/qml/Main.qml app/qml/PropertyPanel.qml app/qml/PropField.qml app/tests/tst_qmlload.cpp
git commit -m "Arrows show the direction of travel; a backwards element shows a warning; Reverse direction; typed rotation" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Selecting several elements

**Files:**
- Modify: `app/qml/TrackStore.qml`, `app/qml/CanvasView.qml`, `app/qml/ElementView.qml`, `app/qml/PropertyPanel.qml`, `app/qml/PropField.qml`, `app/qml/Main.qml` (Edit menu enablement), `app/tests/tst_qmlload.cpp`

**Interfaces:**
- Consumes: `Selection.sharedProps/boxHits`, `Snapping.findGroupSnap/groupToJoin`, commands `setProps`, `removeMany`, `duplicateMany`, `placeMany` (Task 6).
- Produces (TrackStore): `selection` (array: element ids, or one of `"ruler"`, `"origin"`, `"direction"` alone), `selectedId` (read-only: the one thing selected, else `""`), `selectedElements` (array), `selectedElement` (the one selected element, else null), `isSelected(id)`, `select(id)`, `toggle(id)` (elements only), `selectMany(ids, add)`; `deleteSelected`, `duplicateSelected`, `reverseSelected` act on every selected element. `ElementView.single` (handle shown only when true). `PropField.mixed`. `CanvasView` modes `moveGroup` and `box`, `box` rectangle `objectName: "selectionBox"`.

- [ ] **Step 1: Write the failing test**

Add to `app/tests/tst_qmlload.cpp`:

```cpp
    // Ctrl+click, a Shift+drag box, the shared settings, a group drag, duplicate and delete; Ctrl+click on a target
    // selects it alone.
    void selectingSeveralElements()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        window->requestActivate();
        QVERIFY(QTest::qWaitForWindowActive(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QVERIFY(canvas && store);
        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);

        auto element = [&](const QString &id) {
            QVariant v;
            QMetaObject::invokeMethod(store, "element", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, id));
            return qvariant_cast<QJSValue>(v).toVariant().toMap();
        };
        auto prop = [&](const QString &id, const QString &key) {
            return element(id).value(QStringLiteral("props")).toMap().value(key).toDouble();
        };
        auto joinedTo = [&](const QString &id, const QString &end) {
            return element(id).value(QStringLiteral("joins")).toMap().value(end).toMap().value(QStringLiteral("id")).toString();
        };
        auto selection = [&]() {
            return qvariant_cast<QJSValue>(store->property("selection")).toVariant().toStringList();
        };
        const double mpp = store->property("mpp").toDouble();
        auto screen = [&](double wx, double wy) {
            QVariant v;
            QMetaObject::invokeMethod(canvas, "toScreen", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, wx), Q_ARG(QVariant, wy));
            const QVariantMap p = qvariant_cast<QJSValue>(v).toVariant().toMap();
            return canvas->mapToScene(QPointF(p.value("x").toDouble(), p.value("y").toDouble())).toPoint();
        };
        auto middle = [&](const QString &id) {
            const QVariantMap e = element(id);
            return screen(e.value("x").toDouble() / mpp, e.value("y").toDouble() / mpp);
        };
        auto drag = [&](QPoint from, QPoint to, Qt::KeyboardModifiers modifiers = {}) {
            QTest::mousePress(window, Qt::LeftButton, modifiers, from);
            for (int i = 1; i <= 8; ++i)
                QTest::mouseMove(window, from + (to - from) * i / 8);
            QTest::mouseRelease(window, Qt::LeftButton, modifiers, to);
        };
        auto visibleText = [&](const QString &text) {
            for (QQuickItem *item : allItems(window->contentItem()))
                if (item->isVisible() && item->property("text").toString() == text)
                    return true;
            return false;
        };
        auto label = [&]() { return store->property("undoLabel").toString(); };

        // Ctrl+click adds the chicane to the straight; the panel shows what they share.
        QTest::mouseClick(window, Qt::LeftButton, {}, middle(QStringLiteral("e1")));
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, middle(QStringLiteral("e4")));
        QCOMPARE(selection(), QStringList({ QStringLiteral("e1"), QStringLiteral("e4") }));
        QVERIFY(visibleText(QStringLiteral("2 elements selected")));
        QQuickItem *width = findField(window, QStringLiteral("Track width"));
        QVERIFY(width);
        QVERIFY(!findField(window, QStringLiteral("Length")));
        QQuickItem *input = textBox(width);
        QTest::mouseClick(window, Qt::LeftButton, {}, input->mapToScene(QPointF(input->width() / 2, input->height() / 2)).toPoint());
        QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
        for (const char c : QByteArray("5 m"))
            QTest::keyClick(window, c);
        QTest::keyClick(window, Qt::Key_Return);
        QCOMPARE(prop(QStringLiteral("e1"), QStringLiteral("trackWidth")), 5.0);
        QCOMPARE(prop(QStringLiteral("e4"), QStringLiteral("trackWidth")), 5.0);
        QCOMPARE(label(), QStringLiteral("Change Track width (2 elements)"));
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(prop(QStringLiteral("e1"), QStringLiteral("trackWidth")), 4.0);

        // Different values show "mixed".
        QVariantMap wide{ { "id", "e1" }, { "key", "trackWidth" }, { "value", 6.0 } };
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("setProp")), Q_ARG(QVariant, wide));
        QTRY_VERIFY(findField(window, QStringLiteral("Track width"))->property("mixed").toBool());
        QCOMPARE(textBox(findField(window, QStringLiteral("Track width")))->property("text").toString(), QString());
        QMetaObject::invokeMethod(store, "undo");

        // Ctrl+click again takes it out.
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, middle(QStringLiteral("e4")));
        QCOMPARE(selection(), QStringList({ QStringLiteral("e1") }));

        // Ctrl+click on a target while elements are selected selects the target alone; Delete deletes only it.
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, middle(QStringLiteral("e4")));
        const QVariantMap origin = qvariant_cast<QJSValue>(store->property("track")).property("targets").property("origin").toVariant().toMap();
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, screen(origin.value("x").toDouble(), origin.value("y").toDouble()));
        QCOMPARE(selection(), QStringList({ QStringLiteral("origin") }));
        QTest::keyClick(window, Qt::Key_Delete);
        QCOMPARE(label(), QStringLiteral("Delete Origin"));
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QMetaObject::invokeMethod(store, "undo");

        // A Shift+drag box around the slalom's middle selects it.
        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QString()));
        const QPoint m2 = middle(QStringLiteral("e2"));
        drag(m2 - QPoint(12, 12), m2 + QPoint(12, 12), Qt::ShiftModifier);
        QCOMPARE(selection(), QStringList({ QStringLiteral("e2") }));

        // A group drag moves both, keeps their join, and breaks the joins to the rest.
        QTest::mouseClick(window, Qt::LeftButton, {}, middle(QStringLiteral("e1")));
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, middle(QStringLiteral("e2")));
        const QPoint from = middle(QStringLiteral("e1"));
        drag(from, from + QPoint(0, 150));
        QCOMPARE(label(), QStringLiteral("Move 2 elements"));
        QCOMPARE(joinedTo(QStringLiteral("e1"), QStringLiteral("B")), QStringLiteral("e2"));
        QVERIFY(element(QStringLiteral("e2")).value("joins").toMap().value("B").isNull());
        QVERIFY(element(QStringLiteral("e3")).value("joins").toMap().value("A").isNull());
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(joinedTo(QStringLiteral("e2"), QStringLiteral("B")), QStringLiteral("e3"));

        // A plain click on one of them, without dragging, selects only it.
        QTest::mouseClick(window, Qt::LeftButton, {}, middle(QStringLiteral("e1")));
        QCOMPARE(selection(), QStringList({ QStringLiteral("e1") }));

        // Ctrl+D copies both, keeping their join, and selects the copies; Delete removes them.
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, middle(QStringLiteral("e2")));
        QTest::keyClick(window, Qt::Key_D, Qt::ControlModifier);
        QCOMPARE(store->property("elementCount").toInt(), 6);
        QCOMPARE(selection(), QStringList({ QStringLiteral("e5"), QStringLiteral("e6") }));
        QCOMPARE(joinedTo(QStringLiteral("e5"), QStringLiteral("B")), QStringLiteral("e6"));
        QCOMPARE(label(), QStringLiteral("Duplicate 2 elements"));
        QTest::keyClick(window, Qt::Key_Delete);
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QCOMPARE(label(), QStringLiteral("Delete 2 elements"));
    }
```

- [ ] **Step 2: Run it to see it fail**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1 -R tst_qmlload -NoQml`
Expected: FAIL — `selection` is not a property; Ctrl+click replaces the selection.

- [ ] **Step 3: The selection in `TrackStore`**

In `app/qml/TrackStore.qml`, replace `property string selectedId: ""` and `readonly property var selectedElement: {...}` with:

```qml
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
```

In `setTrack`, replace the two lines that clear `selectedId` with:

```qml
        const kept = selection.filter(id => exists(id))
        if (kept.length !== selection.length)
            selection = kept
```

In `loadTrack`, replace `selectedId = ""` with `selection = []`.

Replace `select(id)` and add the others:

```qml
    function isSelected(id) {
        return selection.indexOf(id) >= 0
    }

    // Selects `id` alone ("" selects nothing).
    function select(id) {
        const next = id === "" ? [] : [id]
        if (JSON.stringify(next) === JSON.stringify(selection))
            return
        stack.seal()
        selection = next
    }

    // Adds an element to the selection or takes it out (Ctrl+click). A ruler or target selected before is dropped.
    function toggle(id) {
        stack.seal()
        const elementsOnly = selection.filter(s => element(s) !== null)
        selection = elementsOnly.indexOf(id) >= 0 ? elementsOnly.filter(s => s !== id) : elementsOnly.concat([id])
    }

    // Selects these elements, or adds them to the elements already selected.
    function selectMany(ids, add) {
        stack.seal()
        const start = add ? selection.filter(s => element(s) !== null) : []
        selection = start.concat(ids.filter(id => start.indexOf(id) < 0))
    }
```

`deleteSelected`, `duplicateSelected` and `reverseSelected` become:

```qml
    function deleteSelected() {
        if (selection.length === 0)
            return
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
        const ids = selectedElements.map(e => e.id)
        if (ids.length === 0)
            return
        run("duplicateMany", { ids: ids })
        stack.seal()
        selection = track.elements.slice(track.elements.length - ids.length).map(e => e.id)
    }

    function reverseSelected() {
        const ids = selectedElements.map(e => e.id)
        if (ids.length === 0)
            return
        run("reverse", { ids: ids })
        stack.seal()
    }
```

In `app/qml/Main.qml`, the Edit actions' `enabled`: Duplicate and Reverse direction `TrackStore.selectedElements.length > 0`; Delete `TrackStore.selection.length > 0`.

- [ ] **Step 4: Ctrl+click, the box and the group drag on the canvas**

In `app/qml/ElementView.qml`, add `property bool single: true` after `selected`, and change `handle` to `drawable && selected && single ? Elements.rotateHandle(element, 24 / zoom * mpp) : null`.

In `app/qml/CanvasView.qml`:
- add `import "logic/selection.mjs" as Selection`
- add `property var box: null          // the selection box being dragged, in screen pixels`
- the ElementView delegate's `selected: element !== null && TrackStore.selection.indexOf(element.id) >= 0` and `single: TrackStore.selection.length === 1`
- `pressAt` becomes:

```qml
    function pressAt(e) {
        canvas.forceActiveFocus()
        gestureKey = TrackStore.newGestureKey()
        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0
        const shift = (e.modifiers & Qt.ShiftModifier) !== 0
        press = { sx: e.x, sy: e.y, panX: panX, panY: panY, ctrl: ctrl }
        if (e.button === Qt.MiddleButton || (e.button === Qt.LeftButton && spaceHeld)) {
            mode = "pan"
            return
        }
        const hit = hitAt(e.x, e.y)
        if (e.button === Qt.RightButton) {
            if (hit && hit.kind === "element") {
                if (!TrackStore.isSelected(hit.id))
                    TrackStore.select(hit.id)
                elementMenu.popup()
            }
            return
        }
        if (e.button !== Qt.LeftButton)
            return
        if (!hit) {
            if (shift) {
                press.w = toWorld(e.x, e.y)
                press.add = ctrl
                mode = "box"
                return
            }
            TrackStore.select("")
            mode = "pan"
            return
        }
        const t = TrackStore.track
        if (hit.kind === "element" || hit.kind === "rotate") {
            if (hit.kind === "element" && ctrl) {
                const removing = TrackStore.isSelected(hit.id)
                TrackStore.toggle(hit.id)
                if (removing)
                    return            // a Ctrl+click that takes an element out starts no drag
            } else if (!TrackStore.isSelected(hit.id)) {
                TrackStore.select(hit.id)
            }
            press.el = TrackStore.element(hit.id)
            press.group = TrackStore.selectedElements.map(el => JSON.parse(JSON.stringify(el)))
            press.w = toWorld(e.x, e.y)
            mode = hit.kind === "rotate" ? "rotate" : press.group.length > 1 ? "moveGroup" : "move"
            return
        }
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
```

- in `moveTo`, add before `} else if (mode === "rotate") {`:

```qml
        } else if (mode === "moveGroup") {
            const ctrl = (e.modifiers & Qt.ControlModifier) !== 0
            const moved = press.group.map(g => Object.assign({}, g, { x: g.x + dx * mpp, y: g.y + dy * mpp }))
            let placed = moved
            let snap = null
            const found = ctrl ? null : Snapping.findGroupSnap(TrackStore.track.elements, moved, snapMetres())
            if (found) {
                placed = Snapping.groupToJoin(moved, found.ownId, found.ownEnd, TrackStore.element(found.targetId),
                                              found.targetEnd)
                snap = { ownId: found.ownId, ownEnd: found.ownEnd, id: found.targetId, end: found.targetEnd }
            }
            TrackStore.run("placeMany", { moves: placed.map(p => ({ id: p.id, x: p.x, y: p.y, rotation: p.rotation })),
                                          snap: snap, verb: "Move", mergeKey: gestureKey })
        } else if (mode === "box") {
            box = { x: Math.min(press.sx, e.x), y: Math.min(press.sy, e.y),
                    width: Math.abs(e.x - press.sx), height: Math.abs(e.y - press.sy) }
```

- `releaseAt` becomes:

```qml
    function releaseAt(e) {
        if (mode === "box" && press.dragging && mpp > 0) {
            const a = press.w
            const b = toWorld(e.x, e.y)
            TrackStore.selectMany(Selection.boxHits(TrackStore.track.elements, { x: a.x * mpp, y: a.y * mpp },
                                                    { x: b.x * mpp, y: b.y * mpp }), press.add)
        } else if (mode === "moveGroup" && !press.dragging && !press.ctrl) {
            TrackStore.select(press.el.id)       // a plain click on one of several selects only it
        }
        if (mode !== "" && mode !== "pan" && mode !== "box")
            TrackStore.seal()
        mode = ""
        press = null
        box = null
    }
```

- in `overlay`, add:

```qml
        Rectangle {
            objectName: "selectionBox"
            visible: canvas.box !== null
            x: canvas.box ? canvas.box.x : 0
            y: canvas.box ? canvas.box.y : 0
            width: canvas.box ? canvas.box.width : 0
            height: canvas.box ? canvas.box.height : 0
            color: Qt.rgba(0.18, 0.44, 0.84, 0.15)
            border.color: "#2f6fd6"
        }
```

- the MouseArea's `cursorShape` treats `moveGroup` like `move`: `canvas.mode === "move" || canvas.mode === "moveGroup" || canvas.mode === "target" ? Qt.SizeAllCursor`.

- [ ] **Step 5: The panel for several elements**

In `app/qml/PropField.qml`:
- add `property bool mixed: false   // several elements with different values: the field shows "mixed"` and `onMixedChanged: refresh()`
- `shown()` starts with `if (mixed) return ""`
- `step()` starts with `if (mixed) return`
- the TextField's `placeholderText: field.mixed ? qsTr("mixed") : field.emptyWhenZero ? qsTr("Type it here") : ""`
- the choice Button's `checked: !field.mixed && field.value === field.def.choices[index]`

In `app/qml/PropertyPanel.qml`:
- add `import "logic/selection.mjs" as Selection`
- after `readonly property var el`, add:

```qml
    readonly property var many: TrackStore.selectedElements.length > 1 ? TrackStore.selectedElements : []
    readonly property var shared: Selection.sharedProps(many)
    // Changes only when the selection or the set of shared settings changes, so fields are not rebuilt while typing.
    readonly property string sharedKey: many.map(e => e.id).join(",") + ":" + shared.map(s => s.def.key).join(",")
    property var sharedDefs: []
    onSharedKeyChanged: sharedDefs = shared.map(s => s.def)

    function sharedEntry(key) {
        return shared.find(s => s.def.key === key) || null
    }
```

- `kind` becomes `el ? "element" : many.length > 1 ? "many" : TrackStore.selectedId`
- the title Label's text gains a case after `"element"`: `: panel.kind === "many" ? qsTr("%1 elements selected").arg(panel.many.length)`
- after the element Repeater, add:

```qml
        Repeater {
            model: panel.sharedDefs
            PropField {
                required property var modelData
                readonly property var entry: panel.sharedEntry(modelData.key)
                def: modelData
                mixed: entry !== null && entry.mixed
                value: entry && !entry.mixed ? entry.value : (modelData.kind === "choice" ? "" : 0)
                onEdited: (v) => {
                    const choice = modelData.kind === "choice"   // read first: a choice can rebuild this field
                    TrackStore.run("setProps", { ids: panel.many.map(e => e.id), key: modelData.key, value: v })
                    if (choice)
                        TrackStore.seal()
                }
                onFinished: TrackStore.seal()
            }
        }
```

- [ ] **Step 6: Run every test**

Run: `powershell -NoProfile -File app\tests\build.ps1; powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`, `qml: … passed, 0 failed` (the part 1 window tests too: they select through `select`, which still selects one).

- [ ] **Step 7: Commit**

```bash
git add app/qml/TrackStore.qml app/qml/CanvasView.qml app/qml/ElementView.qml app/qml/PropertyPanel.qml app/qml/PropField.qml app/qml/Main.qml app/tests/tst_qmlload.cpp
git commit -m "Select several elements: Ctrl+click, Shift+drag box, shared settings, group drag, duplicate and delete" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: README, final checks, the owner's check, merge and push

**Files:**
- Modify: `README.md`

- [ ] **Step 1: README**

In `README.md`:
- the status note becomes:

```markdown
> **v1 in progress.** Parts 1 and 2 of 5 are done: the core canvas (metres underneath, zoom and pan, undo, units, cone
> preview) and setup and track files (a setup checklist, `.cone` files with the photo inside, direction arrows,
> Reverse direction, typed rotation, multi-select). A full guide comes with v1.0.0.
```

- after the first section, add:

````markdown
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
````

- in Layout, the `app/` line's last part becomes `` `services/` is a little C++ (settings, photos, track files). `` and add a line `- \`docs/cone-format.md\`, \`docs/cone-format.schema.json\`: the track file format for other apps.`

- [ ] **Step 2: Build from a clean clone without the map images**

```powershell
git add README.md
git commit -m "README: part 2 status, track files and the format for other apps" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
$clone = Join-Path $env:TEMP 'conestructor-part2-clean'
Remove-Item -Recurse -Force $clone -ErrorAction SilentlyContinue
git clone --branch part2-setup-files . $clone
Test-Path "$clone\app\assets\images\duckPondBirdeye.png"      # expect False
powershell -NoProfile -File "$clone\app\tests\build.ps1"
powershell -NoProfile -File "$clone\app\tests\run.ps1"
```

Expected: `False`, the build succeeds, `ctest: passed`, `qml: … passed, 0 failed`.

- [ ] **Step 3: Check what would be pushed**

```powershell
git diff --stat main...part2-setup-files
git diff main...part2-setup-files | Select-String -Pattern '([0-9]{1,3}\.){3}[0-9]{1,3}|https?://|secret|token|password|api[_-]?key|\.env'
```

Expected: only the schema's `https://json-schema.org/draft/2020-12/schema`, the README's existing links, and the commit attribution's `anthropic.com` (in log messages, not the diff). Anything else that looks like an address, key or personal detail: stop and ask the owner.

- [ ] **Step 4: Whole-branch review**

A fresh reviewer reads the spec, this plan and `git diff main...part2-setup-files`, and reports Critical / Important / Minor findings. Fix Critical and Important findings test-first; list Minor ones for the owner.

- [ ] **Step 5: The owner's check (about 15 minutes)**

Ask the owner to run the app (`app\build\tests\appConestructor.exe`) and:
1. Start a new track through the checklist with a real lot photo (photo, ruler on a parking space, Origin, Direction); the track tiles unlock.
2. Build a chain of all four elements; place one turn back to front, see its ⚠, Reverse it and see the ⚠ clear.
3. Type 90° on the first straight and watch the chain turn.
4. Ctrl+click three elements and set their track width; Shift+drag a box around two and drag them onto an open end.
5. Save, close (no question), reopen from File › Open Recent.
6. Edit, then try to close (the question appears; Cancel).
7. Edit, wait over two minutes, end the app from Task Manager, start it again and Restore the backup.
8. Drag a `.cone` and a photo onto the window.
9. Open the `.cone` in a text editor: the top reads sensibly and the photo is at the bottom.

- [ ] **Step 6: Merge and push**

After the owner's check passes:

```bash
git switch main
git merge --no-ff part2-setup-files -m "Merge part 2 (setup and track files): setup checklist, .cone files with the photo, arrows and driving order, Reverse, typed rotation, multi-select" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin main
```
