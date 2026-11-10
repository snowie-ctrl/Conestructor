#include <QQmlApplicationEngine>
#include <QQuickItem>
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
};

QTEST_MAIN(TestQmlLoad)
#include "tst_qmlload.moc"
