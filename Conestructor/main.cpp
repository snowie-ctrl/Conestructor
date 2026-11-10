#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "exportmanager.h"


int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("Conestructor", "Main");

    ExportManager exportManager;
    engine.rootContext()->setContextProperty("exportManager", &exportManager);

    return app.exec();
}
