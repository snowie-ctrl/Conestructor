#include "PhotoStore.h"

#include <QBuffer>
#include <QFile>
#include <QImage>
#include <QImageReader>
#include <QMutexLocker>
#include <QQmlEngine>
#include <QUrl>

namespace {

QString couldNotOpen()
{
    return PhotoStore::tr("Could not open that photo. The background is unchanged.");
}

// Decodes bytes as a picture; a null image when they are not one.
QImage decode(const QByteArray &bytes, QByteArray *format)
{
    QByteArray copy = bytes;
    QBuffer buffer(&copy);
    buffer.open(QIODevice::ReadOnly);
    QImageReader reader(&buffer);
    reader.setAutoTransform(true);
    if (format)
        *format = reader.format().toLower();
    return reader.read();
}

} // namespace

PhotoStore::PhotoStore(QObject *parent) : QObject(parent), m_shelf(std::make_shared<Shelf>()) {}

PhotoStore *PhotoStore::create(QQmlEngine *engine, QJSEngine *)
{
    auto *store = new PhotoStore(nullptr);
    engine->addImageProvider(QStringLiteral("photo"), new PhotoProvider(store->shelf()));
    return store;
}

QVariantMap PhotoStore::load(const QString &pathOrUrl)
{
    QString path = pathOrUrl;
    const QUrl url(pathOrUrl);
    if (url.scheme() == QLatin1String("qrc"))
        path = QLatin1Char(':') + url.path();
    else if (url.isLocalFile())
        path = url.toLocalFile();
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return { { QStringLiteral("error"), couldNotOpen() } };
    const int ref = add(file.readAll());
    if (ref < 0)
        return { { QStringLiteral("error"), couldNotOpen() } };
    const QSize s = size(ref);
    return { { QStringLiteral("ref"), ref }, { QStringLiteral("width"), s.width() },
             { QStringLiteral("height"), s.height() } };
}

QString PhotoStore::url(int ref) const
{
    return QStringLiteral("image://photo/%1").arg(ref);
}

void PhotoStore::clear(int keep)
{
    QMutexLocker lock(&m_shelf->mutex);
    const bool had = m_shelf->photos.contains(keep);
    const Photo kept = m_shelf->photos.value(keep);
    m_shelf->photos.clear();
    if (had)
        m_shelf->photos.insert(keep, kept);
}

void PhotoStore::remove(int ref)
{
    QMutexLocker lock(&m_shelf->mutex);
    m_shelf->photos.remove(ref);
}

int PhotoStore::add(const QByteArray &bytes)
{
    QByteArray format;
    const QImage image = decode(bytes, &format);
    QString mediaType;
    if (format == "png")
        mediaType = QStringLiteral("image/png");
    else if (format == "jpeg" || format == "jpg")
        mediaType = QStringLiteral("image/jpeg");
    if (image.isNull() || mediaType.isEmpty())
        return -1;
    QMutexLocker lock(&m_shelf->mutex);
    const int ref = m_shelf->next++;
    m_shelf->photos.insert(ref, { bytes, mediaType, image.size() });
    return ref;
}

bool PhotoStore::has(int ref) const
{
    QMutexLocker lock(&m_shelf->mutex);
    return m_shelf->photos.contains(ref);
}

QByteArray PhotoStore::bytes(int ref) const
{
    QMutexLocker lock(&m_shelf->mutex);
    return m_shelf->photos.value(ref).bytes;
}

QString PhotoStore::mediaType(int ref) const
{
    QMutexLocker lock(&m_shelf->mutex);
    return m_shelf->photos.value(ref).mediaType;
}

QSize PhotoStore::size(int ref) const
{
    QMutexLocker lock(&m_shelf->mutex);
    return m_shelf->photos.value(ref).size;
}

PhotoProvider::PhotoProvider(std::shared_ptr<PhotoStore::Shelf> shelf)
    : QQuickImageProvider(QQuickImageProvider::Image), m_shelf(std::move(shelf))
{
}

QImage PhotoProvider::requestImage(const QString &id, QSize *size, const QSize &)
{
    QByteArray bytes;
    {
        QMutexLocker lock(&m_shelf->mutex);
        bytes = m_shelf->photos.value(id.toInt()).bytes;
    }
    const QImage image = bytes.isEmpty() ? QImage() : decode(bytes, nullptr);
    if (size)
        *size = image.size();
    return image;
}
