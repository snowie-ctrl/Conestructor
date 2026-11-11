#include "TrackFile.h"

#include "PhotoStore.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLockFile>
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

TrackFile::TrackFile(QObject *parent) : QObject(parent) {}

TrackFile::~TrackFile() = default;

bool TrackFile::ownsBackup() const
{
    if (m_owns)
        return true;
    if (!m_lock) {
        QDir().mkpath(backupDir());
        m_lock = std::make_unique<QLockFile>(QDir(backupDir()).filePath(QStringLiteral("autosave.lock")));
        m_lock->setStaleLockTime(0);     // only a lock whose process has gone is stale, however old
    }
    m_owns = m_lock->tryLock(0);
    return m_owns;
}

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

QString TrackFile::absolutePath(const QString &path) const
{
    return path.isEmpty() ? QString() : QDir::toNativeSeparators(QFileInfo(path).absoluteFilePath());
}

QUrl TrackFile::folderUrl(const QString &path) const
{
    return QUrl::fromLocalFile(QFileInfo(path).absolutePath());
}

QUrl TrackFile::fileUrl(const QString &path) const
{
    return QUrl::fromLocalFile(QFileInfo(path).absoluteFilePath());
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
    if (!ownsBackup())
        return tr("Another Conestructor window is keeping the backup.");
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
    if (!ownsBackup() || !QFileInfo::exists(backupFile()))
        return {};
    const QSettings notes(backupNotes(), QSettings::IniFormat);
    return { { QStringLiteral("path"), backupFile() },
             { QStringLiteral("trackPath"), notes.value(QStringLiteral("trackPath")).toString() },
             { QStringLiteral("name"), notes.value(QStringLiteral("name"), tr("Untitled")).toString() },
             { QStringLiteral("time"), notes.value(QStringLiteral("time")).toString() } };
}

void TrackFile::deleteBackup()
{
    if (!ownsBackup())
        return;
    QFile::remove(backupFile());
    QFile::remove(backupNotes());
}

PhotoStore *TrackFile::photos() const
{
    QQmlEngine *engine = qmlEngine(this);
    return engine ? engine->singletonInstance<PhotoStore *>("Conestructor", "PhotoStore") : nullptr;
}
