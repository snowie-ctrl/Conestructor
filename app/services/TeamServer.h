#pragma once
#include <QByteArray>
#include <QHash>
#include <QImage>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QTemporaryDir>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>
#include <functional>

class PhotoStore;
class QNetworkAccessManager;
class QNetworkReply;
class QNetworkRequest;

// The team server (server/ in the repo) as the app sees it: the team code from Preferences › Team, which address
// answers (the LAN first, then the public one, remembered for the session), the team's track list and thumbnails, an
// upload of the open track with a thumbnail drawn here, and a download for TrackStore to open. Every answer comes back
// as a signal; errors are sentences to show as they are. One upload or download at a time.
class TeamServer : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString code READ code WRITE setCode NOTIFY codeChanged)
    Q_PROPERTY(bool hasCode READ hasCode NOTIFY codeChanged)
    Q_PROPERTY(QString teamName READ teamName NOTIFY codeChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    // What a team code carries (server/coneRules.py makes them). `valid` is false for anything that is not a code.
    struct Code
    {
        QString team;
        QUrl lan;
        QUrl publicUrl;
        QString key;
        bool valid = false;
    };
    static Code parseCode(const QString &text);

    static constexpr qint64 maxFile = 40LL * 1024 * 1024;
    static constexpr int maxThumbnail = 200 * 1024;
    static constexpr int thumbnailSide = 400;
    static constexpr int probeTimeout = 1500;        // ms for the LAN to answer a ping
    static constexpr int requestTimeout = 15000;     // ms for check, list and thumbnails
    static constexpr int transferTimeout = 30000;    // ms without progress before an upload or download is abandoned

    explicit TeamServer(QObject *parent = nullptr);
    ~TeamServer() override;

    QString code() const { return m_code; }
    // Takes a new code (spaces around it dropped); forgets which address answered and the session's thumbnails.
    void setCode(const QString &code);
    bool hasCode() const { return m_parsed.valid; }
    QString teamName() const { return m_parsed.team; }
    bool busy() const { return m_busy; }

    Q_INVOKABLE bool isCode(const QString &text) const { return parseCode(text).valid; }

    // The upload's thumbnail: the lot photo (photoRef, or -1 for none) cropped to the cones (canvas metres, in driving
    // order, { x, y, type }) with the route through them, as a JPEG file kept for the session; an empty URL when it
    // could not be written.
    Q_INVOKABLE QUrl makeThumbnail(int photoRef, double mpp, const QVariantList &cones);
    static QImage drawThumbnail(const QImage &photo, double mpp, const QVariantList &cones);
    // JPEG bytes no larger than maxThumbnail (the quality is lowered until they fit); empty when they cannot be made.
    static QByteArray jpeg(const QImage &image);

    // Answers with checked(): "Connected to <team> (on the LAN)" or "(over the internet)", or why not.
    Q_INVOKABLE void check();
    // Answers with tracksListed(): [{ id, name, cones, uploaded, uploadedText, bytes }], newest first.
    Q_INVOKABLE void listTracks();
    // Answers with thumbnailReady() once it is here (a failure says nothing); kept for the session.
    Q_INVOKABLE void fetchThumbnail(int id);
    // Answers with downloaded(): `read` as TrackFile.open gives it ({ text, photoRef, photoError } or { error }).
    Q_INVOKABLE void download(int id);
    // The document without its photo (TrackStore.documentText), the photo to add, and the thumbnail's file URL from
    // makeThumbnail. Answers with uploaded().
    Q_INVOKABLE void upload(const QString &documentText, int photoRef, const QUrl &thumbnail);
    // Stops the upload or download under way; it answers with ok false and an empty error.
    Q_INVOKABLE void cancel();

    // Tests hand in their own store; the app uses the QML engine's.
    void setPhotos(PhotoStore *photos) { m_photos = photos; }

signals:
    void codeChanged();
    void busyChanged();
    void checked(bool ok, const QString &message);
    void tracksListed(bool ok, const QVariantList &tracks, const QString &error);
    void thumbnailReady(int id, const QUrl &url);
    void downloadProgress(qint64 received, qint64 total);
    void downloaded(bool ok, const QVariantMap &read, const QString &error);
    void uploadProgress(qint64 sent, qint64 total);
    void uploaded(bool ok, const QString &error);

private:
    PhotoStore *photos() const;
    QNetworkRequest request(const QUrl &base, const QString &route, int timeout) const;
    // Runs `then` with the address to use: the one that answered before, else the LAN when its ping answers like the
    // server within probeTimeout, else the public one. An empty URL when there is none to try.
    void withServer(const std::function<void(const QUrl &)> &then);
    // "" for a success; otherwise the sentence to show. Nothing coming back forgets the address that answered, so the
    // next request finds the server again.
    QString failure(QNetworkReply *reply);
    QString unreachable() const;
    QString tooLarge() const;
    void setBusy(bool busy);
    // Writes a file in the session's folder: its path, or "" when it could not be written.
    QString saveFile(const QString &name, const QByteArray &bytes);

    QNetworkAccessManager *m_net;
    QString m_code;
    Code m_parsed;
    QUrl m_base;
    int m_generation = 0;
    bool m_busy = false;
    bool m_cancelled = false;
    QPointer<QNetworkReply> m_transfer;
    PhotoStore *m_photos = nullptr;
    QTemporaryDir m_files;
    QHash<int, QUrl> m_thumbs;
    int m_serial = 0;
};
