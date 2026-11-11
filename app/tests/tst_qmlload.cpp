#include <QQmlApplicationEngine>
#include <QFile>
#include <QJSValue>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QSettings>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>
#include <QtMath>
#include <cmath>
#include <QtQml/QQmlExtensionPlugin>

Q_IMPORT_QML_PLUGIN(ConestructorPlugin)

// Loads the real window offscreen. Any warning from QML (a broken binding, a missing property) fails the run.
class TestQmlLoad : public QObject
{
    Q_OBJECT

    QTemporaryDir dir;

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

private slots:
    void initTestCase()
    {
        // Before anything reads settings, so the owner's real ini is never read or written.
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, dir.path());
        QQuickStyle::setStyle(QStringLiteral("Fusion"));
    }

    // Per test function: a failOnWarning set in initTestCase does not reach the test functions.
    void init()
    {
        QTest::failOnWarning(QRegularExpression(QStringLiteral("\\.qml|\\.mjs|QML")));
    }

    void mainOpensWithTheTitle()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        QCOMPARE(engine.rootObjects().size(), 1);
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(window);
        QCOMPARE(window->title(), QStringLiteral("Conestructor 0.3 \u2014 Untitled"));
    }

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
    // Drags with real mouse events: placing Origin and the ruler from the palette's functions, then dragging Origin
    // and one ruler end. Each drag must undo as one step, named in the Edit menu.
    void draggingTargetsAndTheRulerUndoesAsOneStep()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        QVERIFY(canvas);
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QVERIFY(store);
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);

        auto drag = [&](QPointF from, QPointF to) {
            const QPoint a = canvas->mapToScene(from).toPoint();
            const QPoint b = canvas->mapToScene(to).toPoint();
            QTest::mousePress(window, Qt::LeftButton, {}, a);
            for (int i = 1; i <= 5; ++i)
                QTest::mouseMove(window, a + (b - a) * i / 5);
            QTest::mouseRelease(window, Qt::LeftButton, {}, b);
        };

        QMetaObject::invokeMethod(canvas, "beginPlacing", Q_ARG(QVariant, QStringLiteral("origin")));
        QMetaObject::invokeMethod(canvas, "finishPlacing", Q_ARG(QVariant, 400.0), Q_ARG(QVariant, 300.0));
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Place Origin"));
        drag({ 400, 300 }, { 460, 330 });
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Move Origin"));

        QMetaObject::invokeMethod(canvas, "beginPlacing", Q_ARG(QVariant, QStringLiteral("ruler")));
        QMetaObject::invokeMethod(canvas, "finishPlacing", Q_ARG(QVariant, 700.0), Q_ARG(QVariant, 500.0));
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Set ruler"));
        drag({ 620, 500 }, { 600, 540 });     // the ruler's first end sits 80 screen pixels left of where it landed

        QMetaObject::invokeMethod(store, "undo");   // the end drag
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Set ruler"));
        QMetaObject::invokeMethod(store, "undo");   // placing the ruler
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Move Origin"));
        QMetaObject::invokeMethod(store, "undo");   // the Origin drag
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Place Origin"));
    }
    // Editing the example track with real mouse and key events: select, drag away (unjoins), drag back (snaps and
    // joins), rotate with the handle, pan from on top of an element, duplicate, delete and undo.
    void editingElementsWithTheMouse()
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
        auto joined = [&](const QString &id, const QString &end) {
            return !element(id).value(QStringLiteral("joins")).toMap().value(end).isNull();
        };
        const double mpp = store->property("mpp").toDouble();
        // An element's middle on screen, in canvas coordinates.
        auto middle = [&](const QString &id) {
            const QVariantMap e = element(id);
            QVariant v;
            QMetaObject::invokeMethod(canvas, "toScreen", Q_RETURN_ARG(QVariant, v),
                                      Q_ARG(QVariant, e.value("x").toDouble() / mpp),
                                      Q_ARG(QVariant, e.value("y").toDouble() / mpp));
            const QVariantMap p = qvariant_cast<QJSValue>(v).toVariant().toMap();
            return QPointF(p.value("x").toDouble(), p.value("y").toDouble());
        };
        auto scene = [&](QPointF p) { return canvas->mapToScene(p).toPoint(); };
        auto drag = [&](QPointF from, QPointF to, Qt::MouseButton button = Qt::LeftButton) {
            const QPoint a = scene(from);
            const QPoint b = scene(to);
            QTest::mousePress(window, button, {}, a);
            for (int i = 1; i <= 8; ++i)
                QTest::mouseMove(window, a + (b - a) * i / 8);
            QTest::mouseRelease(window, button, {}, b);
        };
        auto label = [&]() { return store->property("undoLabel").toString(); };

        // Select the Straight (e1, joined at B to the Slalom), then click empty canvas.
        const QPointF straight = middle("e1");
        QTest::mouseClick(window, Qt::LeftButton, {}, scene(straight));
        QCOMPARE(store->property("selectedId").toString(), QStringLiteral("e1"));
        QTest::mouseClick(window, Qt::LeftButton, {}, scene(QPointF(30, 30)));
        QCOMPARE(store->property("selectedId").toString(), QString());

        // Drag it well away: it unjoins, and so does its neighbour.
        drag(straight, straight + QPointF(0, 150));
        QCOMPARE(label(), QStringLiteral("Move Straight"));
        QVERIFY(!joined("e1", "B"));
        QVERIFY(!joined("e2", "A"));
        // Drag it back: it snaps and joins again.
        drag(straight + QPointF(0, 150), straight + QPointF(6, 4));
        QVERIFY(joined("e1", "B"));
        QCOMPARE(element("e2").value("joins").toMap().value("A").toMap().value("id").toString(), QStringLiteral("e1"));

        // The rotate handle sits above the selected Straight; dragging it a quarter turn about the middle turns it
        // by about 90 degrees, as one step.
        const double zoom = canvas->property("zoom").toDouble();
        const QPointF centre = middle("e1");
        const double reach = (2.0 / mpp) * zoom + 24.0;       // half the 4 m track width, plus 24 screen pixels
        const QPointF handle = centre - QPointF(0, reach);
        QPointF last = handle;
        QTest::mousePress(window, Qt::LeftButton, {}, scene(handle));
        for (int i = 1; i <= 9; ++i) {
            const double a = -M_PI / 2 + (M_PI / 2) * i / 9;
            last = centre + QPointF(std::cos(a) * reach, std::sin(a) * reach);
            QTest::mouseMove(window, scene(last));
        }
        QTest::mouseRelease(window, Qt::LeftButton, {}, scene(last));
        QCOMPARE(label(), QStringLiteral("Rotate Straight"));
        QVERIFY2(std::abs(element("e1").value("rotation").toDouble() - 90) < 3,
                 qPrintable(QString::number(element("e1").value("rotation").toDouble())));
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(element("e1").value("rotation").toDouble(), 0.0);

        // A middle-button drag that starts on an element pans and leaves the element where it is.
        const double panX = canvas->property("panX").toDouble();
        const QString before = label();
        drag(middle("e1"), middle("e1") + QPointF(40, 0), Qt::MiddleButton);
        QCOMPARE(canvas->property("panX").toDouble(), panX + 40);
        QCOMPARE(label(), before);

        // Ctrl+D duplicates the selection and selects the copy; Delete removes it; undo brings it back.
        QTest::mouseClick(window, Qt::LeftButton, {}, scene(middle("e1")));
        QTest::keyClick(window, Qt::Key_D, Qt::ControlModifier);
        QCOMPARE(store->property("elementCount").toInt(), 5);
        QCOMPARE(store->property("selectedId").toString(), QStringLiteral("e5"));
        QCOMPARE(label(), QStringLiteral("Duplicate Straight"));
        QTest::keyClick(window, Qt::Key_Delete);
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QCOMPARE(label(), QStringLiteral("Delete Straight"));
        QTest::keyClick(window, Qt::Key_Z, Qt::ControlModifier);
        QCOMPARE(store->property("elementCount").toInt(), 5);

        // Resizing the window changes what is visible, never the zoom.
        const double zoomBefore = canvas->property("zoom").toDouble();
        window->resize(1200, 800);
        QTRY_COMPARE(canvas->width() < 1200, true);
        QCOMPARE(canvas->property("zoom").toDouble(), zoomBefore);
    }

    // The property panel with real clicks and typing.
    void thePropertyPanelEditsTheSelection()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        window->requestActivate();
        QVERIFY(QTest::qWaitForWindowActive(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QObject *settings = engine.singletonInstance<QObject *>("Conestructor", "Settings");
        QVERIFY(canvas && store && settings);
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
        auto joined = [&](const QString &id, const QString &end) {
            return !element(id).value(QStringLiteral("joins")).toMap().value(end).isNull();
        };
        // The visible setting with this label, and its text box.
        auto field = [&](const QString &label) -> QQuickItem * {
            for (QQuickItem *item : allItems(window->contentItem())) {
                const QVariant def = item->property("def");
                if (def.isValid() && item->isVisible()
                    && def.toMap().value(QStringLiteral("label")).toString() == label)
                    return item;
            }
            return nullptr;
        };
        auto box = [&](QQuickItem *f) -> QQuickItem * {
            for (QQuickItem *item : allItems(f))
                if (QByteArray(item->metaObject()->className()).contains("TextField"))
                    return item;
            return nullptr;
        };
        auto click = [&](QQuickItem *item) {
            QTest::mouseClick(window, Qt::LeftButton, {},
                              item->mapToScene(QPointF(item->width() / 2, item->height() / 2)).toPoint());
        };
        // QTest::keyClicks takes only widgets; this types into the window one character at a time.
        auto typeText = [&](const QString &text) {
            for (const QChar c : text)
                QTest::keyClick(window, c.toLatin1());
        };
        auto retype = [&](QQuickItem *input, const QString &text) {
            click(input);
            QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
            typeText(text);
        };
        auto label = [&]() { return store->property("undoLabel").toString(); };

        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QStringLiteral("e3")));      // the Turn
        QQuickItem *width = field(QStringLiteral("Track width"));
        QVERIFY(width);
        QVERIFY(field(QStringLiteral("Turn angle")));
        QVERIFY(!field(QStringLiteral("Exit radius")));
        QQuickItem *input = box(width);
        QVERIFY(input);
        QCOMPARE(input->property("text").toString(), QStringLiteral("13' 1\""));

        // Typing applies as you go, keeps the chain joined, and is one undo step.
        retype(input, QStringLiteral("12' 6\""));
        QVERIFY(std::abs(prop("e3", "trackWidth") - 3.81) < 1e-9);
        QVERIFY(joined("e2", "B") && joined("e4", "A"));
        // Not a value: red, element unchanged; Esc puts the old text back.
        QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
        typeText(QStringLiteral("abc"));
        QVERIFY(width->property("bad").toBool());
        QVERIFY(std::abs(prop("e3", "trackWidth") - 3.81) < 1e-9);
        QTest::keyClick(window, Qt::Key_Escape);
        QVERIFY(!width->property("bad").toBool());
        QCOMPARE(input->property("text").toString(), QStringLiteral("12' 6\""));
        // Editing keys stay in the field: Backspace and Delete do not delete the element, F does not fit.
        const double zoom = canvas->property("zoom").toDouble();
        QTest::keyClick(window, Qt::Key_End);
        QTest::keyClick(window, Qt::Key_Backspace);
        QTest::keyClick(window, Qt::Key_Delete);
        typeText(QStringLiteral("f"));
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QCOMPARE(canvas->property("zoom").toDouble(), zoom);
        QTest::keyClick(window, Qt::Key_Escape);
        // The up arrow steps one inch; Enter ends the bout, and one undo takes it all back.
        QTest::keyClick(window, Qt::Key_Up);
        QVERIFY(std::abs(prop("e3", "trackWidth") - (3.81 + 0.0254)) < 1e-9);
        QTest::keyClick(window, Qt::Key_Return);
        QCOMPARE(label(), QStringLiteral("Change Track width"));
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(prop("e3", "trackWidth"), 4.0);
        // Out of limits: kept within them, with a note.
        retype(input, QStringLiteral("50 m"));
        QCOMPARE(prop("e3", "trackWidth"), 20.0);
        QCOMPARE(width->property("note").toString(), QStringLiteral("Kept within 3' 3\" to 65' 7\""));
        QTest::keyClick(window, Qt::Key_Return);

        // A changing radius shows Exit radius.
        QQuickItem *changing = nullptr;
        for (QQuickItem *item : allItems(window->contentItem()))
            if (item->isVisible() && item->property("text").toString() == QStringLiteral("Changing")
                && QByteArray(item->metaObject()->className()).contains("Button"))
                changing = item;
        QVERIFY(changing);
        click(changing);
        QCOMPARE(element("e3").value("props").toMap().value("radiusType").toString(), QStringLiteral("changing"));
        QTRY_VERIFY(field(QStringLiteral("Exit radius")));

        // The ruler's real length: elements keep their photo spots and sizes, chains stay joined; undo restores.
        const double mppBefore = store->property("mpp").toDouble();
        const double e1Pixels = element("e1").value("x").toDouble() / mppBefore;
        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QStringLiteral("ruler")));
        QQuickItem *length = field(QStringLiteral("Real length"));
        QVERIFY(length);
        retype(box(length), QStringLiteral("30 m"));
        QTest::keyClick(window, Qt::Key_Return);
        const double mppAfter = store->property("mpp").toDouble();
        QVERIFY(std::abs(mppAfter - mppBefore * 1.5) < 1e-12);
        QVERIFY(std::abs(element("e1").value("x").toDouble() / mppAfter - e1Pixels) < 1e-6);
        QCOMPARE(prop("e1", "length"), 20.0);
        QVERIFY(joined("e1", "B") && joined("e2", "B") && joined("e3", "B"));
        QCOMPARE(label(), QStringLiteral("Set ruler"));
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(store->property("mpp").toDouble(), mppBefore);

        // Units: switching to metres changes the fields at once.
        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QStringLiteral("e1")));
        QCOMPARE(box(field(QStringLiteral("Length")))->property("text").toString(), QStringLiteral("65' 7\""));
        settings->setProperty("units", QStringLiteral("m"));
        QCOMPARE(box(field(QStringLiteral("Length")))->property("text").toString(), QStringLiteral("20 m"));
        settings->setProperty("units", QStringLiteral("ftin"));
    }

    // Placing cones draws them; the toggles, Clear preview, the banners for what is missing, and the export file.
    void thePreviewAndTheExport()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QVERIFY(canvas && store);
        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(true)));
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);

        // Cone pictures on the canvas, and where the first one sits.
        auto cones = [&]() {
            QList<QQuickItem *> out;
            for (QQuickItem *item : allItems(canvas))
                if (item->isVisible() && item->property("source").toString().endsWith(QStringLiteral("-cone.png")))
                    out << item;
            return out;
        };
        auto placed = [&]() {
            QVariant n;
            QMetaObject::invokeMethod(window, "conesPlaced", Q_RETURN_ARG(QVariant, n));
            return n.toInt();
        };
        auto banner = [&]() -> QQuickItem * {
            for (QQuickItem *item : allItems(window->contentItem()))
                if (QByteArray(item->metaObject()->className()).startsWith("ErrorBanner"))
                    return item;
            return nullptr;
        };

        QVERIFY(placed() > 40);
        QCOMPARE(cones().size(), placed());
        QVERIFY(store->property("message").toString().startsWith(QStringLiteral("Placed ")));

        // Show cones off hides them; on brings them back.
        store->setProperty("showCones", false);
        QCOMPARE(cones().size(), 0);
        store->setProperty("showCones", true);
        QCOMPARE(cones().size(), placed());

        // Moving an element while the preview is on moves its cones.
        const double before = cones().first()->x();
        QVariantMap args{ { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } };
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("place")), Q_ARG(QVariant, args));
        QTRY_VERIFY(std::abs(cones().first()->x() - before) > 1);

        // The export: metres, the axes sentence, the target distance, every cone.
        QTemporaryDir out;
        const QString path = out.filePath(QStringLiteral("cones.json"));
        QMetaObject::invokeMethod(window, "exportCones");
        QMetaObject::invokeMethod(window, "writeExport", Q_ARG(QVariant, QUrl::fromLocalFile(path)));
        QFile file(path);
        QVERIFY(file.open(QIODevice::ReadOnly));
        const QJsonObject doc = QJsonDocument::fromJson(file.readAll()).object();
        QCOMPARE(doc.value("units").toString(), QStringLiteral("m"));
        QVERIFY(doc.value("axes").toString().contains(QStringLiteral("y to the left")));
        QCOMPARE(doc.value("targetDistance").toDouble(), 100.0);
        QCOMPARE(doc.value("cones").toArray().size(), placed());
        QVERIFY(store->property("message").toString().startsWith(QStringLiteral("Exported ")));

        // Clear preview removes the overlay.
        QMetaObject::invokeMethod(store, "clearPreview");
        QCOMPARE(cones().size(), 0);

        // A new track has no ruler; a ruler without a length gets "Show me", which selects it.
        QMetaObject::invokeMethod(window, "newTrack");
        QMetaObject::invokeMethod(store, "placeCones");
        QVERIFY(banner()->isVisible());
        QCOMPARE(banner()->property("text").toString(),
                 QStringLiteral("Place the ruler on something of known length, then set its real length"));
        QVariantMap ruler{ { "a", QVariantMap{ { "x", 100 }, { "y", 100 } } },
                           { "b", QVariantMap{ { "x", 300 }, { "y", 100 } } }, { "realLength", 0 } };
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("setRuler")), Q_ARG(QVariant, ruler));
        QMetaObject::invokeMethod(store, "placeCones");
        QCOMPARE(banner()->property("text").toString(), QStringLiteral("Set the ruler's real length"));
        QMetaObject::invokeMethod(canvas, "showTarget", Q_ARG(QVariant, banner()->property("target")));
        QCOMPARE(store->property("selectedId").toString(), QStringLiteral("ruler"));
    }

    // A click whose pointer wobbles a pixel only selects: it moves nothing, keeps the chain joined, records no step.
    void aClickWithAWobbleOnlySelects()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
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
        const double mpp = store->property("mpp").toDouble();
        const QVariantMap slalom = element(QStringLiteral("e2"));
        QVariant v;
        QMetaObject::invokeMethod(canvas, "toScreen", Q_RETURN_ARG(QVariant, v),
                                  Q_ARG(QVariant, slalom.value("x").toDouble() / mpp),
                                  Q_ARG(QVariant, slalom.value("y").toDouble() / mpp));
        const QVariantMap p = qvariant_cast<QJSValue>(v).toVariant().toMap();
        const QPoint middle = canvas->mapToScene(QPointF(p.value("x").toDouble(), p.value("y").toDouble())).toPoint();

        QTest::mousePress(window, Qt::LeftButton, {}, middle);
        QTest::mouseMove(window, middle + QPoint(1, 0));
        QTest::mouseMove(window, middle + QPoint(1, 1));
        QTest::mouseRelease(window, Qt::LeftButton, {}, middle + QPoint(1, 1));

        QCOMPARE(store->property("selectedId").toString(), QStringLiteral("e2"));
        QVERIFY(!store->property("canUndo").toBool());
        const QVariantMap joins = element(QStringLiteral("e2")).value("joins").toMap();
        QVERIFY(!joins.value("A").isNull());
        QVERIFY(!joins.value("B").isNull());
    }
};

QTEST_MAIN(TestQmlLoad)
#include "tst_qmlload.moc"
