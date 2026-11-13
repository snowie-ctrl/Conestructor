#include "TeamServer.h"

#include "PhotoStore.h"
#include "TrackFile.h"

#include <QBuffer>
#include <QDateTime>
#include <QFile>
#include <QHttpMultiPart>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPainter>
#include <QPolygonF>
#include <QQmlEngine>
#include <algorithm>

namespace {

const QString codePrefix = QStringLiteral("CONE1.");

// An address from a team code: http or https with a host, or an empty URL.
QUrl address(const QJsonValue &value)
{
    if (!value.isString())
        return {};
    const QUrl url(value.toString(), QUrl::StrictMode);
    if (!url.isValid() || url.host().isEmpty()
        || (url.scheme() != QLatin1String("http") && url.scheme() != QLatin1String("https")))
        return {};
    return url;
}

int statusOf(QNetworkReply *reply)
{
    return reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
}

QHttpPart filePart(const QByteArray &field, const QByteArray &filename, const QByteArray &type, const QByteArray &body)
{
    QHttpPart part;
    part.setHeader(QNetworkRequest::ContentDispositionHeader,
                   QByteArray("form-data; name=\"" + field + "\"; filename=\"" + filename + "\""));
    part.setHeader(QNetworkRequest::ContentTypeHeader, type);
    part.setBody(body);
    return part;
}

} // namespace

TeamServer::TeamServer(QObject *parent) : QObject(parent), m_net(new QNetworkAccessManager(this)) {}

TeamServer::~TeamServer() = default;

TeamServer::Code TeamServer::parseCode(const QString &text)
{
    Code code;
    const QString trimmed = text.trimmed();
    if (!trimmed.startsWith(codePrefix))
        return code;
    QByteArray body = trimmed.mid(codePrefix.size()).toLatin1();
    while (body.size() % 4 != 0)
        body.append('=');
    const auto decoded = QByteArray::fromBase64Encoding(
        body, QByteArray::Base64UrlEncoding | QByteArray::AbortOnBase64DecodingErrors);
    if (!decoded)
        return code;
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(*decoded, &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject())
        return code;
    const QJsonObject fields = doc.object();
    if (fields.value(QStringLiteral("v")).toInt(-1) != 1)
        return code;
    code.team = fields.value(QStringLiteral("team")).toString();
    code.key = fields.value(QStringLiteral("key")).toString();
    code.lan = address(fields.value(QStringLiteral("lan")));
    code.publicUrl = address(fields.value(QStringLiteral("public")));
    code.valid = !code.key.isEmpty() && (code.lan.isValid() || code.publicUrl.isValid());
    return code;
}

void TeamServer::setCode(const QString &code)
{
    const QString trimmed = code.trimmed();
    if (trimmed == m_code)
        return;
    m_code = trimmed;
    m_parsed = parseCode(trimmed);
    m_base = QUrl();
    ++m_generation;
    m_thumbs.clear();
    emit codeChanged();
}

PhotoStore *TeamServer::photos() const
{
    if (m_photos)
        return m_photos;
    QQmlEngine *engine = qmlEngine(this);
    return engine ? engine->singletonInstance<PhotoStore *>("Conestructor", "PhotoStore") : nullptr;
}

// ---- The thumbnail ----

QImage TeamServer::drawThumbnail(const QImage &photo, double mpp, const QVariantList &cones)
{
    const double pixelsPerMetre = mpp > 0 ? 1.0 / mpp : 1.0;
    struct Dot
    {
        QPointF at;     // photo pixels
        bool leaning;
    };
    QList<Dot> dots;
    double minX = 0, minY = 0, maxX = 0, maxY = 0;
    for (const QVariant &value : cones) {
        const QVariantMap cone = value.toMap();
        const QPointF p(cone.value(QStringLiteral("x")).toDouble() * pixelsPerMetre,
                        cone.value(QStringLiteral("y")).toDouble() * pixelsPerMetre);
        if (dots.isEmpty()) {
            minX = maxX = p.x();
            minY = maxY = p.y();
        }
        minX = std::min(minX, p.x());
        maxX = std::max(maxX, p.x());
        minY = std::min(minY, p.y());
        maxY = std::max(maxY, p.y());
        dots.append({ p, cone.value(QStringLiteral("type")).toString() == QLatin1String("leaning") });
    }

    // The cones' extent plus 10% on each side, at least 20 m across; with no cones, the whole photo.
    const double least = 20 * pixelsPerMetre;
    QRectF area;
    if (dots.isEmpty()) {
        area = photo.isNull() ? QRectF(0, 0, least, least) : QRectF(photo.rect());
    } else {
        const double w = std::max((maxX - minX) * 1.2, least);
        const double h = std::max((maxY - minY) * 1.2, least);
        area = QRectF((minX + maxX - w) / 2, (minY + maxY - h) / 2, w, h);
    }
    const double scale = thumbnailSide / std::max(area.width(), area.height());
    QImage out(std::max(1, qRound(area.width() * scale)), std::max(1, qRound(area.height() * scale)),
               QImage::Format_RGB32);
    out.fill(QColor(0x1b, 0x1b, 0x1b));

    QPainter painter(&out);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    const auto toThumb = [&](QPointF p) { return QPointF((p.x() - area.x()) * scale, (p.y() - area.y()) * scale); };
    if (!photo.isNull()) {
        const QRectF inside = area.intersected(QRectF(photo.rect()));
        if (!inside.isEmpty())
            painter.drawImage(QRectF(toThumb(inside.topLeft()), toThumb(inside.bottomRight())), photo, inside);
    }
    if (dots.size() > 1) {
        QPolygonF route;
        for (const Dot &dot : std::as_const(dots))
            route << toThumb(dot.at);
        painter.setPen(QPen(QColor(255, 255, 255, 204), 1.5));
        painter.setBrush(Qt::NoBrush);
        painter.drawPolyline(route);
    }
    painter.setPen(Qt::NoPen);
    for (const Dot &dot : std::as_const(dots)) {
        painter.setBrush(dot.leaning ? QColor(0xff, 0xd4, 0x00) : QColor(0xff, 0x8c, 0x1a));
        painter.drawEllipse(toThumb(dot.at), 3.0, 3.0);
    }
    painter.end();
    return out;
}

QByteArray TeamServer::jpeg(const QImage &image)
{
    QByteArray bytes;
    for (int quality = 85; quality >= 15; quality -= 10) {
        bytes.clear();
        QBuffer buffer(&bytes);
        buffer.open(QIODevice::WriteOnly);
        if (!image.save(&buffer, "JPG", quality))
            return {};
        if (bytes.size() <= maxThumbnail)
            return bytes;
    }
    return {};
}

QString TeamServer::saveFile(const QString &name, const QByteArray &bytes)
{
    if (!m_files.isValid())
        return {};
    const QString path = m_files.filePath(name);
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly) || file.write(bytes) != bytes.size())
        return {};
    return path;
}

QUrl TeamServer::makeThumbnail(int photoRef, double mpp, const QVariantList &cones)
{
    QImage photo;
    PhotoStore *store = photos();
    if (store && photoRef >= 0 && store->has(photoRef)) {
        QByteArray bytes = store->bytes(photoRef);
        QBuffer buffer(&bytes);
        QImageReader reader(&buffer);
        reader.setAutoTransform(true);     // as PhotoStore shows it
        photo = reader.read();
    }
    const QByteArray bytes = jpeg(drawThumbnail(photo, mpp, cones));
    if (bytes.isEmpty())
        return {};
    const QString path = saveFile(QStringLiteral("upload-%1.jpg").arg(++m_serial), bytes);
    return path.isEmpty() ? QUrl() : QUrl::fromLocalFile(path);
}

// ---- Talking to the server ----

QNetworkRequest TeamServer::request(const QUrl &base, const QString &route, int timeout, bool withKey) const
{
    QUrl url = base;
    QString path = url.path();
    while (path.endsWith(QLatin1Char('/')))
        path.chop(1);
    url.setPath(path + QStringLiteral("/api/cone") + route);
    QNetworkRequest r(url);
    if (withKey)
        r.setRawHeader("X-Team-Key", m_parsed.key.toUtf8());
    r.setHeader(QNetworkRequest::UserAgentHeader, QByteArrayLiteral("Conestructor/" CONESTRUCTOR_VERSION));
    r.setTransferTimeout(timeout);
    return r;
}

void TeamServer::withServer(const std::function<void(const QUrl &)> &then)
{
    if (m_base.isValid()) {
        then(m_base);
        return;
    }
    if (!m_parsed.lan.isValid()) {
        m_base = m_parsed.publicUrl;
        then(m_base);
        return;
    }
    QNetworkReply *reply = m_net->get(request(m_parsed.lan, QStringLiteral("/ping"), probeTimeout, false));
    const int generation = m_generation;
    connect(reply, &QNetworkReply::finished, this, [this, reply, then, generation]() {
        reply->deleteLater();
        if (generation != m_generation) {
            then(QUrl());
            return;
        }
        const bool ours = statusOf(reply) == 200
                          && QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("status")).toString()
                                 == QLatin1String("ok");
        m_base = ours ? m_parsed.lan : m_parsed.publicUrl;     // empty when the code has no public address
        then(m_base);
    });
}

QString TeamServer::unreachable() const
{
    if (m_parsed.lan.isValid() && m_parsed.publicUrl.isValid())
        return tr("Can't reach the team server (tried the LAN and the internet).");
    if (m_parsed.lan.isValid())
        return tr("Can't reach the team server (tried the LAN).");
    return tr("Can't reach the team server (tried the internet).");
}

QString TeamServer::tooLarge() const
{
    return tr("Too large to upload (over 40 MB).");
}

QString TeamServer::failure(QNetworkReply *reply)
{
    const int status = statusOf(reply);
    if (status == 0) {                  // nothing came back: refused, timed out, no route, TLS...
        m_base = QUrl();
        return unreachable();
    }
    if (status >= 200 && status < 300)
        return {};
    if (forgetForeignLan(reply, m_base))
        return tr("The server had a problem. Try again later.");
    if (status == 401)
        return tr("The team code was not accepted. Check it in Preferences \xE2\x80\xBA Team.");
    if (status == 413)
        return tooLarge();
    if (status == 400) {
        const QString message =
            QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("message")).toString();
        return tr("The server refused the track: %1.").arg(message.isEmpty() ? tr("no reason given") : message);
    }
    return tr("The server had a problem. Try again later.");
}

bool TeamServer::forgetForeignLan(QNetworkReply *reply, const QUrl &base)
{
    if (!base.isValid() || base != m_parsed.lan)
        return false;
    const QJsonObject answer = QJsonDocument::fromJson(reply->peek(reply->bytesAvailable())).object();
    if (answer.value(QStringLiteral("status")).isString())
        return false;                   // the server's own error answer
    m_base = QUrl();
    return true;
}

void TeamServer::setBusy(bool busy)
{
    if (busy == m_busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void TeamServer::check()
{
    if (!m_parsed.valid) {
        emit checked(false, tr("Not a team code"));
        return;
    }
    withServer([this](const QUrl &base) {
        if (!base.isValid()) {
            emit checked(false, tr("Can't reach the team server"));
            return;
        }
        QNetworkReply *reply = m_net->get(request(base, QStringLiteral("/team"), requestTimeout));
        connect(reply, &QNetworkReply::finished, this, [this, reply, base]() {
            reply->deleteLater();
            const int status = statusOf(reply);
            if (status == 0) {
                m_base = QUrl();
                emit checked(false, tr("Can't reach the team server"));
            } else if (status != 200 && forgetForeignLan(reply, base)) {
                emit checked(false, tr("The server had a problem. Try again later."));
            } else if (status == 401) {
                emit checked(false, tr("The server doesn't know this code"));
            } else if (status != 200) {
                emit checked(false, tr("The server had a problem. Try again later."));
            } else {
                const QString name =
                    QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("name")).toString();
                emit checked(true, (base == m_parsed.lan ? tr("Connected to %1 (on the LAN)")
                                                         : tr("Connected to %1 (over the internet)")).arg(name));
            }
        });
    });
}

void TeamServer::listTracks()
{
    if (!m_parsed.valid) {
        emit tracksListed(false, {}, tr("Not a team code"));
        return;
    }
    withServer([this](const QUrl &base) {
        if (!base.isValid()) {
            emit tracksListed(false, {}, unreachable());
            return;
        }
        QNetworkReply *reply = m_net->get(request(base, QStringLiteral("/tracks"), requestTimeout));
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            reply->deleteLater();
            const QString error = failure(reply);
            if (!error.isEmpty()) {
                emit tracksListed(false, {}, error);
                return;
            }
            QVariantList tracks;
            const QJsonArray list =
                QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("tracks")).toArray();
            for (const QJsonValue value : list) {
                const QJsonObject t = value.toObject();
                const QString uploaded = t.value(QStringLiteral("uploaded")).toString();
                tracks << QVariantMap{
                    { QStringLiteral("id"), t.value(QStringLiteral("id")).toInt() },
                    { QStringLiteral("name"), t.value(QStringLiteral("name")).toString() },
                    { QStringLiteral("cones"), t.value(QStringLiteral("cones")).toInt() },
                    { QStringLiteral("uploaded"), uploaded },
                    { QStringLiteral("uploadedText"), QDateTime::fromString(uploaded, Qt::ISODate).toLocalTime()
                                                          .toString(QStringLiteral("d MMM yyyy HH:mm")) },
                    { QStringLiteral("bytes"), t.value(QStringLiteral("bytes")).toDouble() } };
            }
            emit tracksListed(true, tracks, QString());
        });
    });
}

void TeamServer::fetchThumbnail(int id)
{
    if (m_thumbs.contains(id)) {
        emit thumbnailReady(id, m_thumbs.value(id));
        return;
    }
    if (!m_parsed.valid)
        return;
    const int generation = m_generation;
    withServer([this, id, generation](const QUrl &base) {
        if (!base.isValid() || generation != m_generation)
            return;
        QNetworkReply *reply =
            m_net->get(request(base, QStringLiteral("/tracks/%1/thumbnail").arg(id), requestTimeout));
        connect(reply, &QNetworkReply::finished, this, [this, reply, id, generation]() {
            reply->deleteLater();
            if (generation != m_generation || !failure(reply).isEmpty())
                return;
            const QString path = saveFile(QStringLiteral("thumb-%1.jpg").arg(id), reply->readAll());
            if (path.isEmpty())
                return;
            m_thumbs.insert(id, QUrl::fromLocalFile(path));
            emit thumbnailReady(id, m_thumbs.value(id));
        });
    });
}

void TeamServer::download(int id)
{
    if (m_busy)
        return;
    if (!m_parsed.valid) {
        emit downloaded(false, {}, tr("Not a team code"));
        return;
    }
    setBusy(true);
    m_cancelled = false;
    withServer([this, id](const QUrl &base) {
        if (m_cancelled || !base.isValid()) {
            setBusy(false);
            emit downloaded(false, {}, m_cancelled ? QString() : unreachable());
            return;
        }
        QNetworkReply *reply = m_net->get(request(base, QStringLiteral("/tracks/%1/file").arg(id), transferTimeout));
        m_transfer = reply;
        connect(reply, &QNetworkReply::downloadProgress, this, &TeamServer::downloadProgress);
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            reply->deleteLater();
            m_transfer = nullptr;
            setBusy(false);
            if (m_cancelled) {
                emit downloaded(false, {}, QString());
                return;
            }
            if (statusOf(reply) == 404) {
                emit downloaded(false, {}, tr("That track is no longer on the team."));
                return;
            }
            const QString error = failure(reply);
            if (!error.isEmpty()) {
                emit downloaded(false, {}, error);
                return;
            }
            emit downloaded(true, TrackFile::openBytes(reply->readAll(), photos()), QString());
        });
    });
}

void TeamServer::upload(const QString &documentText, int photoRef, const QUrl &thumbnail)
{
    if (m_busy)
        return;
    if (!m_parsed.valid) {
        emit uploaded(false, tr("Not a team code"));
        return;
    }
    const QByteArray file = TrackFile::documentBytes(documentText, photos(), photoRef);
    if (file.isEmpty()) {
        emit uploaded(false, tr("The track could not be written out."));
        return;
    }
    if (file.size() > maxFile) {
        emit uploaded(false, tooLarge());
        return;
    }
    QFile picture(thumbnail.toLocalFile());
    if (!picture.open(QIODevice::ReadOnly)) {
        emit uploaded(false, tr("The thumbnail could not be read."));
        return;
    }
    const QByteArray thumbnailBytes = picture.readAll();
    setBusy(true);
    m_cancelled = false;
    withServer([this, file, thumbnailBytes](const QUrl &base) {
        if (m_cancelled || !base.isValid()) {
            setBusy(false);
            emit uploaded(false, m_cancelled ? QString() : unreachable());
            return;
        }
        auto *form = new QHttpMultiPart(QHttpMultiPart::FormDataType);
        form->append(filePart("file", "track.cone", "application/json", file));
        form->append(filePart("thumbnail", "thumbnail.jpg", "image/jpeg", thumbnailBytes));
        QNetworkReply *reply = m_net->post(request(base, QStringLiteral("/tracks"), transferTimeout), form);
        form->setParent(reply);
        m_transfer = reply;
        connect(reply, &QNetworkReply::uploadProgress, this, &TeamServer::uploadProgress);
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            reply->deleteLater();
            m_transfer = nullptr;
            setBusy(false);
            if (m_cancelled) {
                emit uploaded(false, QString());
                return;
            }
            const QString error = failure(reply);
            emit uploaded(error.isEmpty(), error);
        });
    });
}

void TeamServer::cancel()
{
    m_cancelled = true;
    if (m_transfer)
        m_transfer->abort();
}
