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
