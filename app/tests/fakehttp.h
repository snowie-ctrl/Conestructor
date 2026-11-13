#pragma once
// A small HTTP/1.1 server for the tests (this Qt has no Qt HttpServer): it answers canned replies by method and path,
// records every request it was sent (method, path, headers in lower case, body), and can stay silent to look like a
// server that never answers. One request per connection: every answer says "Connection: close".
#include <QByteArray>
#include <QHash>
#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonObject>
#include <QList>
#include <QObject>
#include <QString>
#include <QTcpServer>
#include <QTcpSocket>
#include <QUrl>

struct FakeRequest
{
    QByteArray method;
    QByteArray path;
    QHash<QByteArray, QByteArray> headers;
    QByteArray body;
};

struct FakeReply
{
    int status = 200;
    QByteArray type = "application/json";
    QByteArray body;
};

class FakeHttp : public QObject
{
public:
    explicit FakeHttp(QObject *parent = nullptr) : QObject(parent)
    {
        connect(&m_server, &QTcpServer::newConnection, this, [this]() {
            while (QTcpSocket *socket = m_server.nextPendingConnection()) {
                connect(socket, &QTcpSocket::readyRead, this, [this, socket]() { read(socket); });
                connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
            }
        });
        m_server.listen(QHostAddress::LocalHost);
    }

    QUrl base() const { return QUrl(QStringLiteral("http://127.0.0.1:%1").arg(m_server.serverPort())); }

    void reply(const QByteArray &method, const QByteArray &path, const FakeReply &answer)
    {
        m_replies.insert(method + ' ' + path, answer);
    }
    void replyJson(const QByteArray &method, const QByteArray &path, int status, const QByteArray &json)
    {
        reply(method, path, FakeReply{ status, "application/json", json });
    }

    // How many requests asked for `path`.
    int count(const QByteArray &path) const
    {
        int n = 0;
        for (const FakeRequest &r : requests)
            n += r.path == path ? 1 : 0;
        return n;
    }

    // An address nothing listens on: connecting there is refused.
    static QUrl closedPort()
    {
        QTcpServer probe;
        probe.listen(QHostAddress::LocalHost);
        const quint16 port = probe.serverPort();
        probe.close();
        return QUrl(QStringLiteral("http://127.0.0.1:%1").arg(port));
    }

    QList<FakeRequest> requests;
    bool silent = false;    // read requests but never answer

private:
    void read(QTcpSocket *socket)
    {
        m_buffers[socket] += socket->readAll();
        const QByteArray buffer = m_buffers.value(socket);
        const int end = int(buffer.indexOf("\r\n\r\n"));
        if (end < 0)
            return;
        FakeRequest request;
        const QList<QByteArray> lines = buffer.left(end).split('\n');
        const QList<QByteArray> first = lines.value(0).trimmed().split(' ');
        request.method = first.value(0);
        request.path = first.value(1);
        for (int i = 1; i < lines.size(); ++i) {
            const int colon = int(lines[i].indexOf(':'));
            if (colon > 0)
                request.headers.insert(lines[i].left(colon).trimmed().toLower(), lines[i].mid(colon + 1).trimmed());
        }
        const int length = request.headers.value("content-length").toInt();
        if (buffer.size() < end + 4 + length)
            return;                                   // the body is still coming
        request.body = buffer.mid(end + 4, length);
        m_buffers.remove(socket);
        requests << request;
        if (silent)
            return;
        const FakeReply answer = m_replies.value(request.method + ' ' + request.path,
                                                 FakeReply{ 404, "application/json",
                                                            R"({"status": "error", "message": "no such route"})" });
        socket->write("HTTP/1.1 " + QByteArray::number(answer.status) + " Fake\r\nContent-Type: " + answer.type
                      + "\r\nContent-Length: " + QByteArray::number(answer.body.size())
                      + "\r\nConnection: close\r\n\r\n" + answer.body);
        socket->disconnectFromHost();
    }

    QTcpServer m_server;
    QHash<QTcpSocket *, QByteArray> m_buffers;
    QHash<QByteArray, FakeReply> m_replies;
};

// A team code as the server makes it (server/coneRules.py teamCode): CONE1. and base64url JSON without padding. An
// invalid URL leaves that address out.
inline QString teamCodeFor(const QString &team, const QUrl &lan, const QUrl &publicUrl,
                           const QString &key = QStringLiteral("test-key"))
{
    QJsonObject fields{ { QStringLiteral("v"), 1 }, { QStringLiteral("team"), team }, { QStringLiteral("key"), key } };
    if (lan.isValid())
        fields.insert(QStringLiteral("lan"), lan.toString());
    if (publicUrl.isValid())
        fields.insert(QStringLiteral("public"), publicUrl.toString());
    return QStringLiteral("CONE1.")
           + QString::fromLatin1(QJsonDocument(fields).toJson(QJsonDocument::Compact)
                                     .toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}
