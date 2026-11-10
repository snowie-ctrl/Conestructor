#include <QQmlApplicationEngine>
#include <QJSValue>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QSettings>
#include <QTemporaryDir>
#include <QTest>
#include <QtMath>
#include <cmath>
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
        QCOMPARE(window->title(), QStringLiteral("Conestructor 0.2 \u2014 Untitled"));
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
};

QTEST_MAIN(TestQmlLoad)
#include "tst_qmlload.moc"
