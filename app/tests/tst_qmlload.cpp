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
};

QTEST_MAIN(TestQmlLoad)
#include "tst_qmlload.moc"
