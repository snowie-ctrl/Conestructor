#pragma once
#include <QByteArray>
#include <QHash>
#include <QMutex>
#include <QObject>
#include <QQuickImageProvider>
#include <QSize>
#include <QString>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>
#include <memory>

class QJSEngine;
class QQmlEngine;

// Lot photos for this session, each under a small id ("ref") that is never reused. The track holds only the ref, so
// undo snapshots stay light; the bytes are the original file's, kept unchanged for saving into .cone files. QML shows
// a photo as image://photo/<ref>.
class PhotoStore : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    struct Photo
    {
        QByteArray bytes;
        QString mediaType;
        QSize size;
    };
    // Shared with the image provider, which may run on a loader thread and may outlive the store.
    struct Shelf
    {
        QMutex mutex;
        QHash<int, Photo> photos;
        int next = 1;
    };

    explicit PhotoStore(QObject *parent = nullptr);
    // QML creates the store through this, which also registers image://photo/ with that engine.
    static PhotoStore *create(QQmlEngine *engine, QJSEngine *);

    // Reads a PNG or JPEG from a path, a file: URL or a qrc: URL. Returns { ref, width, height } or { error }.
    Q_INVOKABLE QVariantMap load(const QString &pathOrUrl);
    // "image://photo/<ref>".
    Q_INVOKABLE QString url(int ref) const;
    // Forgets every photo but `keep` (-1 keeps none).
    Q_INVOKABLE void clear(int keep);
    Q_INVOKABLE void remove(int ref);

    // A photo from a file's bytes; its ref, or -1 when the bytes are not a PNG or JPEG picture.
    int add(const QByteArray &bytes);
    bool has(int ref) const;
    QByteArray bytes(int ref) const;
    QString mediaType(int ref) const;   // "image/png" or "image/jpeg"
    QSize size(int ref) const;          // as shown (after the photo's own orientation tag)

    std::shared_ptr<Shelf> shelf() const { return m_shelf; }

private:
    std::shared_ptr<Shelf> m_shelf;
};

// Serves image://photo/<ref> from a store's shelf.
class PhotoProvider : public QQuickImageProvider
{
public:
    explicit PhotoProvider(std::shared_ptr<PhotoStore::Shelf> shelf);
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    std::shared_ptr<PhotoStore::Shelf> m_shelf;
};
