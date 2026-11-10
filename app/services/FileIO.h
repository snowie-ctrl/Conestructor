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
