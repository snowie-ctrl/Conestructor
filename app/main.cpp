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

    // Dev affordance for screenshots: open on the example track ("track"), with its cones placed ("cones").
    // Does nothing unless set.
    const QString demo = qEnvironmentVariable("CONESTRUCTOR_DEMO");
    if (!demo.isEmpty())
        QMetaObject::invokeMethod(root, "loadDemo", Q_ARG(QVariant, QVariant(demo == QStringLiteral("cones"))));

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
