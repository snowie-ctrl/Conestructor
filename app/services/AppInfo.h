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
