#include <QBuffer>
#include <QColor>
#include <QDateTime>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QRandomGenerator>
#include <QSignalSpy>
#include <QTest>
#include <memory>

#include "fakehttp.h"
#include "services/PhotoStore.h"
#include "services/TeamServer.h"
#include "services/TrackFile.h"

// The format both sides agree on: server/tests/test_rules.py checks coneRules.teamCode makes exactly this.
static const QString fixedCode = QStringLiteral(
    "CONE1.eyJ2IjoxLCJ0ZWFtIjoiT3VyIHRlYW0iLCJsYW4iOiJodHRwOi8vbGFuLmV4YW1wbGU6NTAwMCIsInB1YmxpYyI6Imh0dHBzOi8v"
    "cHVibGljLmV4YW1wbGUiLCJrZXkiOiJra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2trIn0");
// {"v":1,"team":"Équipe","public":"https://public.example","key":"abc"}
static const QString publicOnlyCode =
    QStringLiteral("CONE1.eyJ2IjoxLCJ0ZWFtIjoiw4lxdWlwZSIsInB1YmxpYyI6Imh0dHBzOi8vcHVibGljLmV4YW1wbGUiLCJrZXkiOiJhYmMifQ");
// A refused connection on Windows can take a couple of seconds, and the Silent power plan stretches everything.
static constexpr int slow = 20000;

class TestTeamServer : public QObject
{
    Q_OBJECT

    static QByteArray png(QSize size)
    {
        QImage image(size, QImage::Format_RGB32);
        image.fill(QColor(30, 160, 60));
        QByteArray bytes;
        QBuffer buffer(&bytes);
        buffer.open(QIODevice::WriteOnly);
        image.save(&buffer, "PNG");
        return bytes;
    }

    static QString document()
    {
        return QStringLiteral("{\n  \"format\": \"conestructor-track\",\n  \"version\": 1,\n  \"name\": \"Lot\",\n"
                              "  \"cones\": []\n}");
    }

    static QVariantList twoCones()
    {
        return { QVariantMap{ { "x", 10.0 }, { "y", 10.0 }, { "type", "standing" } },
                 QVariantMap{ { "x", 30.0 }, { "y", 20.0 }, { "type", "leaning" } } };
    }

    static QByteArray fileBytes(const QString &path)
    {
        QFile file(path);
        file.open(QIODevice::ReadOnly);
        return file.readAll();
    }

private slots:
    // ---- The team code ----

    void codesAreRead_data()
    {
        QTest::addColumn<QString>("text");
        QTest::addColumn<QString>("team");
        QTest::addColumn<QUrl>("lan");
        QTest::addColumn<QUrl>("publicUrl");
        QTest::addColumn<QString>("key");
        QTest::newRow("both addresses") << fixedCode << QStringLiteral("Our team")
                                        << QUrl(QStringLiteral("http://lan.example:5000"))
                                        << QUrl(QStringLiteral("https://public.example")) << QString(43, QLatin1Char('k'));
        // Review focus 1: pasted from a chat app with spaces and line breaks around it.
        QTest::newRow("padded") << QStringLiteral("  \n") + fixedCode + QStringLiteral("\r\n ") << QStringLiteral("Our team")
                                << QUrl(QStringLiteral("http://lan.example:5000"))
                                << QUrl(QStringLiteral("https://public.example")) << QString(43, QLatin1Char('k'));
        QTest::newRow("public only") << publicOnlyCode << QStringLiteral("Équipe") << QUrl()
                                     << QUrl(QStringLiteral("https://public.example")) << QStringLiteral("abc");
    }

    void codesAreRead()
    {
        QFETCH(QString, text);
        const TeamServer::Code code = TeamServer::parseCode(text);
        QVERIFY(code.valid);
        QTEST(code.team, "team");
        QTEST(code.lan, "lan");
        QTEST(code.publicUrl, "publicUrl");
        QTEST(code.key, "key");
        TeamServer team;
        QVERIFY(team.isCode(text));
    }

    void notCodes_data()
    {
        QTest::addColumn<QString>("text");
        QTest::newRow("empty") << QString();
        QTest::newRow("other prefix") << QStringLiteral("CONE2.e30");
        QTest::newRow("not base64") << QStringLiteral("CONE1.!!!");
        QTest::newRow("empty object") << QStringLiteral("CONE1.e30");
        QTest::newRow("a list") << QStringLiteral("CONE1.W10");
        QTest::newRow("no address") << QStringLiteral("CONE1.eyJ2IjoxLCJrZXkiOiJhIn0");
        QTest::newRow("version 2") << QStringLiteral("CONE1.eyJ2IjoyLCJwdWJsaWMiOiJ4Iiwia2V5IjoiYSJ9");
        QTest::newRow("ftp only") << teamCodeFor(QStringLiteral("x"), QUrl(QStringLiteral("ftp://lan.example")), QUrl());
        QTest::newRow("empty key") << teamCodeFor(QStringLiteral("x"), QUrl(),
                                                  QUrl(QStringLiteral("https://public.example")), QString());
        QTest::newRow("cut short") << fixedCode.left(fixedCode.size() - 5);
    }

    void notCodes()
    {
        QFETCH(QString, text);
        QVERIFY(!TeamServer::parseCode(text).valid);
    }

    void aCodeIsTakenWithoutItsSpaces()
    {
        TeamServer team;
        QSignalSpy changed(&team, &TeamServer::codeChanged);
        team.setCode(QStringLiteral("  ") + fixedCode + QStringLiteral("\n"));
        QCOMPARE(team.code(), fixedCode);
        QVERIFY(team.hasCode());
        QCOMPARE(team.teamName(), QStringLiteral("Our team"));
        team.setCode(fixedCode);
        QCOMPARE(changed.count(), 1);
        team.setCode(QStringLiteral("nonsense"));
        QVERIFY(!team.hasCode());
    }

    // ---- The thumbnail ----

    void theThumbnailShowsTheConesOnThePhoto()
    {
        QImage photo(1000, 800, QImage::Format_RGB32);
        photo.fill(QColor(30, 160, 60));
        // 20 photo pixels a metre: the cones at (200, 200) and (600, 400) px span 400 × 200 px; with 10% each side and
        // at least 20 m (400 px) across, the area is 480 × 400 px from (160, 100), shown at 400 / 480.
        const QImage thumb = TeamServer::drawThumbnail(photo, 0.05, twoCones());
        QCOMPARE(thumb.size(), QSize(400, 333));
        const QColor standing(thumb.pixel(33, 83));
        const QColor leaning(thumb.pixel(366, 250));
        const QColor corner(thumb.pixel(3, 3));
        QVERIFY2(standing.red() > 200 && standing.green() > 100 && standing.green() < 180 && standing.blue() < 80,
                 qPrintable(standing.name()));
        QVERIFY2(leaning.red() > 200 && leaning.green() > 190 && leaning.blue() < 80, qPrintable(leaning.name()));
        QVERIFY2(corner.green() > 140 && corner.red() < 60, qPrintable(corner.name()));

        const QImage dark = TeamServer::drawThumbnail(QImage(), 0.05, twoCones());
        QCOMPARE(QColor(dark.pixel(3, 3)), QColor(0x1b, 0x1b, 0x1b));
    }

    void aSmallCourseIsShownAtLeastTwentyMetresAcross()
    {
        const QImage thumb = TeamServer::drawThumbnail(
            QImage(), 0.05, { QVariantMap{ { "x", 5.0 }, { "y", 5.0 }, { "type", "standing" } } });
        QCOMPARE(thumb.size(), QSize(400, 400));
        QVERIFY(QColor(thumb.pixel(200, 200)).red() > 200);
    }

    void theJpegFits()
    {
        QImage noise(400, 400, QImage::Format_RGB32);
        for (int y = 0; y < noise.height(); ++y)
            for (int x = 0; x < noise.width(); ++x)
                noise.setPixel(x, y, QRandomGenerator::global()->generate() | 0xff000000u);
        const QByteArray bytes = TeamServer::jpeg(noise);
        QVERIFY(!bytes.isEmpty());
        QVERIFY(bytes.size() <= TeamServer::maxThumbnail);
        QVERIFY(bytes.startsWith("\xff\xd8"));
    }

    void makeThumbnailWritesAJpegFile()
    {
        PhotoStore photos(nullptr);
        TeamServer team;
        team.setPhotos(&photos);
        const QUrl url = team.makeThumbnail(photos.add(png(QSize(1000, 800))), 0.05, twoCones());
        QVERIFY(url.isLocalFile());
        const QImage written(url.toLocalFile());
        QCOMPARE(written.size(), QSize(400, 333));
        QVERIFY(QFileInfo(url.toLocalFile()).size() <= TeamServer::maxThumbnail);
        QVERIFY(team.makeThumbnail(-1, 0.05, twoCones()) != url);       // a new file each time
    }

    // ---- Finding the server ----

    void theLanIsUsedWhenItAnswers()
    {
        FakeHttp lan, pub;
        lan.replyJson("GET", "/api/cone/ping", 200, R"({"status": "ok"})");
        lan.replyJson("GET", "/api/cone/team", 200, R"({"status": "ok", "name": "Our team"})");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), lan.base(), pub.base()));
        QSignalSpy checked(&team, &TeamServer::checked);
        team.check();
        QTRY_COMPARE(checked.count(), 1);
        QCOMPARE(checked.at(0).at(0).toBool(), true);
        QCOMPARE(checked.at(0).at(1).toString(), QStringLiteral("Connected to Our team (on the LAN)"));
        QCOMPARE(pub.requests.size(), 0);
        QCOMPARE(lan.requests.last().headers.value("x-team-key"), QByteArray("test-key"));
        QCOMPARE(lan.requests.first().path, QByteArray("/api/cone/ping"));
        QVERIFY(!lan.requests.first().headers.contains("x-team-key"));      // the ping carries no key
        QVERIFY(lan.requests.last().headers.value("user-agent").startsWith("Conestructor/"));
    }

    void thePublicAddressIsUsedWhenTheLanIsRefused()
    {
        FakeHttp pub;
        pub.replyJson("GET", "/api/cone/team", 200, R"({"status": "ok", "name": "Our team"})");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), FakeHttp::closedPort(), pub.base()));
        QSignalSpy checked(&team, &TeamServer::checked);
        team.check();
        QTRY_COMPARE_WITH_TIMEOUT(checked.count(), 1, slow);
        QCOMPARE(checked.at(0).at(1).toString(), QStringLiteral("Connected to Our team (over the internet)"));
    }

    void thePublicAddressIsUsedWhenTheLanIsSilent()
    {
        FakeHttp lan, pub;
        lan.silent = true;
        pub.replyJson("GET", "/api/cone/team", 200, R"({"status": "ok", "name": "Our team"})");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), lan.base(), pub.base()));
        QSignalSpy checked(&team, &TeamServer::checked);
        QElapsedTimer clock;
        clock.start();
        team.check();
        QTRY_COMPARE_WITH_TIMEOUT(checked.count(), 1, slow);
        QVERIFY(clock.elapsed() >= TeamServer::probeTimeout - 100);
        QCOMPARE(checked.at(0).at(1).toString(), QStringLiteral("Connected to Our team (over the internet)"));
    }

    // Review focus 2: something else answering at the LAN address is not the team server.
    void theLanMustAnswerLikeTheServer()
    {
        FakeHttp pub;
        pub.replyJson("GET", "/api/cone/team", 200, R"({"status": "ok", "name": "Our team"})");
        const QList<FakeReply> others{ FakeReply{ 404, "text/html", "<html>not here</html>" },
                                       FakeReply{ 200, "text/html", "<html>a router's page</html>" } };
        for (const FakeReply &other : others) {
            FakeHttp lan;
            lan.reply("GET", "/api/cone/ping", other);
            TeamServer team;
            team.setCode(teamCodeFor(QStringLiteral("Our team"), lan.base(), pub.base()));
            QSignalSpy checked(&team, &TeamServer::checked);
            team.check();
            QTRY_COMPARE_WITH_TIMEOUT(checked.count(), 1, slow);
            QCOMPARE(checked.at(0).at(1).toString(), QStringLiteral("Connected to Our team (over the internet)"));
            for (const FakeRequest &r : std::as_const(lan.requests))
                QVERIFY(!r.headers.contains("x-team-key"));           // the key never went to it
        }
    }

    // Final review, Important 1: a LAN address remembered from home that later answers like something else (another
    // network, after the laptop slept) is forgotten, so the next request probes again and uses the public address.
    void aRememberedLanThatAnswersLikeSomethingElseIsForgotten()
    {
        FakeHttp lan, pub;
        lan.replyJson("GET", "/api/cone/ping", 200, R"({"status": "ok"})");
        lan.replyJson("GET", "/api/cone/tracks", 200, R"({"status": "ok", "tracks": []})");
        pub.replyJson("GET", "/api/cone/tracks", 200, R"({"status": "ok", "tracks": []})");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), lan.base(), pub.base()));
        QSignalSpy listed(&team, &TeamServer::tracksListed);
        team.listTracks();
        QTRY_COMPARE(listed.count(), 1);
        const FakeReply other{ 403, "text/html", "<html>forbidden</html>" };
        lan.reply("GET", "/api/cone/ping", other);
        lan.reply("GET", "/api/cone/tracks", other);
        team.listTracks();
        QTRY_COMPARE(listed.count(), 2);
        QCOMPARE(listed.at(1).at(0).toBool(), false);
        team.listTracks();
        QTRY_COMPARE_WITH_TIMEOUT(listed.count(), 3, slow);
        QCOMPARE(listed.at(2).at(0).toBool(), true);
        QCOMPARE(lan.count("/api/cone/ping"), 2);
        QCOMPARE(pub.count("/api/cone/tracks"), 1);
    }

    void theAnswerIsRemembered()
    {
        FakeHttp lan;
        lan.replyJson("GET", "/api/cone/ping", 200, R"({"status": "ok"})");
        lan.replyJson("GET", "/api/cone/tracks", 200, R"({"status": "ok", "tracks": []})");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), lan.base(), QUrl()));
        QSignalSpy listed(&team, &TeamServer::tracksListed);
        team.listTracks();
        QTRY_COMPARE(listed.count(), 1);
        team.listTracks();
        QTRY_COMPARE(listed.count(), 2);
        QCOMPARE(lan.count("/api/cone/ping"), 1);
        QCOMPARE(lan.count("/api/cone/tracks"), 2);
    }

    void aLostConnectionFindsTheServerAgain()
    {
        auto lan = std::make_unique<FakeHttp>();
        lan->replyJson("GET", "/api/cone/ping", 200, R"({"status": "ok"})");
        lan->replyJson("GET", "/api/cone/tracks", 200, R"({"status": "ok", "tracks": []})");
        FakeHttp pub;
        pub.replyJson("GET", "/api/cone/tracks", 200, R"({"status": "ok", "tracks": []})");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), lan->base(), pub.base()));
        QSignalSpy listed(&team, &TeamServer::tracksListed);
        team.listTracks();
        QTRY_COMPARE(listed.count(), 1);
        lan.reset();                                          // left home: the LAN is gone
        team.listTracks();
        QTRY_COMPARE_WITH_TIMEOUT(listed.count(), 2, slow);
        QCOMPARE(listed.at(1).at(0).toBool(), false);
        QCOMPARE(listed.at(1).at(2).toString(),
                 QStringLiteral("Can't reach the team server (tried the LAN and the internet)."));
        team.listTracks();                                    // probes again and finds the public address
        QTRY_COMPARE_WITH_TIMEOUT(listed.count(), 3, slow);
        QCOMPARE(listed.at(2).at(0).toBool(), true);
        QCOMPARE(pub.count("/api/cone/tracks"), 1);
    }

    // ---- What the requests say ----

    void theErrorSentences()
    {
        FakeHttp pub;
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        QSignalSpy listed(&team, &TeamServer::tracksListed);
        const auto listError = [&]() {
            listed.clear();
            team.listTracks();
            if (!QTest::qWaitFor([&]() { return listed.count() == 1; }, slow))
                return QStringLiteral("(no answer)");
            return listed.at(0).at(2).toString();
        };
        pub.replyJson("GET", "/api/cone/tracks", 401, R"({"status": "error", "message": "unauthorized"})");
        QCOMPARE(listError(), QStringLiteral("The team code was not accepted. Check it in Preferences › Team."));
        pub.replyJson("GET", "/api/cone/tracks", 500, R"({"status": "error", "message": "database error"})");
        QCOMPARE(listError(), QStringLiteral("The server had a problem. Try again later."));
        pub.reply("GET", "/api/cone/tracks", FakeReply{ 502, "text/html", "<html>bad gateway</html>" });
        QCOMPARE(listError(), QStringLiteral("The server had a problem. Try again later."));

        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), FakeHttp::closedPort()));
        QCOMPARE(listError(), QStringLiteral("Can't reach the team server (tried the internet)."));
        team.setCode(teamCodeFor(QStringLiteral("Our team"), FakeHttp::closedPort(), FakeHttp::closedPort()));
        QCOMPARE(listError(), QStringLiteral("Can't reach the team server (tried the LAN and the internet)."));
        team.setCode(teamCodeFor(QStringLiteral("Our team"), FakeHttp::closedPort(), QUrl()));
        QCOMPARE(listError(), QStringLiteral("Can't reach the team server (tried the LAN)."));
    }

    void checkSaysWhatIsWrong()
    {
        FakeHttp pub;
        pub.replyJson("GET", "/api/cone/team", 401, R"({"status": "error", "message": "unauthorized"})");
        TeamServer team;
        QSignalSpy checked(&team, &TeamServer::checked);
        team.check();
        QCOMPARE(checked.count(), 1);
        QCOMPARE(checked.at(0).at(1).toString(), QStringLiteral("Not a team code"));
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        team.check();
        QTRY_COMPARE(checked.count(), 2);
        QCOMPARE(checked.at(1).at(1).toString(), QStringLiteral("The server doesn't know this code"));
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), FakeHttp::closedPort()));
        team.check();
        QTRY_COMPARE_WITH_TIMEOUT(checked.count(), 3, slow);
        QCOMPARE(checked.at(2).at(1).toString(), QStringLiteral("Can't reach the team server"));
    }

    // Review focus 3: any name comes back as it was uploaded.
    void theListIsRead()
    {
        FakeHttp pub;
        // Not a raw string: moc misreads a raw string holding \" and then finds no class in this file.
        pub.replyJson("GET", "/api/cone/tracks", 200,
                      "{\"status\": \"ok\", \"tracks\": [{\"id\": 12, \"name\": \"Duck \\\"pond\\\" / wet é 🏁\", "
                      "\"cones\": 132, \"uploaded\": \"2026-11-12T14:02:00Z\", \"bytes\": 3000}]}");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        QSignalSpy listed(&team, &TeamServer::tracksListed);
        team.listTracks();
        QTRY_COMPARE(listed.count(), 1);
        QVERIFY(listed.at(0).at(0).toBool());
        const QVariantMap track = listed.at(0).at(1).toList().value(0).toMap();
        QCOMPARE(track.value("id").toInt(), 12);
        QCOMPARE(track.value("name").toString(), QStringLiteral("Duck \"pond\" / wet é \U0001F3C1"));
        QCOMPARE(track.value("cones").toInt(), 132);
        QCOMPARE(track.value("uploaded").toString(), QStringLiteral("2026-11-12T14:02:00Z"));
        QCOMPARE(track.value("uploadedText").toString(),
                 QDateTime::fromString(QStringLiteral("2026-11-12T14:02:00Z"), Qt::ISODate).toLocalTime()
                     .toString(QStringLiteral("d MMM yyyy HH:mm")));
        QCOMPARE(track.value("bytes").toDouble(), 3000.0);
    }

    void thumbnailsAreFetchedOnce()
    {
        FakeHttp pub;
        QImage small(40, 30, QImage::Format_RGB32);
        small.fill(Qt::gray);
        const QByteArray picture = TeamServer::jpeg(small);
        pub.reply("GET", "/api/cone/tracks/12/thumbnail", FakeReply{ 200, "image/jpeg", picture });
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        QSignalSpy ready(&team, &TeamServer::thumbnailReady);
        team.fetchThumbnail(12);
        QTRY_COMPARE(ready.count(), 1);
        const QUrl url = ready.at(0).at(1).toUrl();
        QCOMPARE(fileBytes(url.toLocalFile()), picture);
        team.fetchThumbnail(12);
        QCOMPARE(ready.count(), 2);
        QCOMPARE(ready.at(1).at(1).toUrl(), url);
        QCOMPARE(pub.count("/api/cone/tracks/12/thumbnail"), 1);
    }

    void anUploadSendsTheFileAndTheThumbnail()
    {
        FakeHttp pub;
        pub.replyJson("POST", "/api/cone/tracks", 201, R"({"status": "ok", "id": 12})");
        PhotoStore photos(nullptr);
        TeamServer team;
        team.setPhotos(&photos);
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        const int ref = photos.add(png(QSize(64, 48)));
        const QUrl thumbnail = team.makeThumbnail(ref, 0.05, twoCones());
        QSignalSpy uploaded(&team, &TeamServer::uploaded);
        team.upload(document(), ref, thumbnail);
        QVERIFY(team.busy());
        QTRY_COMPARE(uploaded.count(), 1);
        QCOMPARE(uploaded.at(0).at(0).toBool(), true);
        QCOMPARE(uploaded.at(0).at(1).toString(), QString());
        QVERIFY(!team.busy());
        const FakeRequest sent = pub.requests.last();
        QCOMPARE(sent.method, QByteArray("POST"));
        QCOMPARE(sent.path, QByteArray("/api/cone/tracks"));
        QVERIFY(sent.headers.value("content-type").startsWith("multipart/form-data; boundary="));
        QVERIFY(sent.body.contains("name=\"file\"; filename=\"track.cone\""));
        QVERIFY(sent.body.contains(TrackFile::documentBytes(document(), &photos, ref)));
        QVERIFY(sent.body.contains("name=\"thumbnail\"; filename=\"thumbnail.jpg\""));
        QVERIFY(sent.body.contains(fileBytes(thumbnail.toLocalFile())));
    }

    void refusalsAndSizes()
    {
        FakeHttp pub;
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        const QUrl thumbnail = team.makeThumbnail(-1, 0.05, twoCones());
        QSignalSpy uploaded(&team, &TeamServer::uploaded);

        pub.replyJson("POST", "/api/cone/tracks", 400, R"({"status": "error", "message": "not a track file"})");
        team.upload(document(), -1, thumbnail);
        QTRY_COMPARE(uploaded.count(), 1);
        QCOMPARE(uploaded.at(0).at(1).toString(), QStringLiteral("The server refused the track: not a track file."));

        pub.replyJson("POST", "/api/cone/tracks", 413, R"({"status": "error", "message": "too large"})");
        team.upload(document(), -1, thumbnail);
        QTRY_COMPARE(uploaded.count(), 2);
        QCOMPARE(uploaded.at(1).at(1).toString(), QStringLiteral("Too large to upload (over 40 MB)."));

        const int asked = int(pub.requests.size());
        const QString huge = QStringLiteral("{\"pad\": \"") + QString(int(TeamServer::maxFile), QLatin1Char('x'))
                             + QStringLiteral("\"}");
        team.upload(huge, -1, thumbnail);                     // refused before anything is sent
        QCOMPARE(uploaded.count(), 3);
        QCOMPARE(uploaded.at(2).at(1).toString(), QStringLiteral("Too large to upload (over 40 MB)."));
        QTest::qWait(100);
        QCOMPARE(int(pub.requests.size()), asked);
    }

    // Review focus 5: a second upload, or a download, while one is under way does nothing; Cancel stops it.
    void oneTransferAtATime()
    {
        FakeHttp pub;
        pub.silent = true;
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        const QUrl thumbnail = team.makeThumbnail(-1, 0.05, twoCones());
        QSignalSpy uploaded(&team, &TeamServer::uploaded);
        QSignalSpy downloaded(&team, &TeamServer::downloaded);
        team.upload(document(), -1, thumbnail);
        team.upload(document(), -1, thumbnail);
        team.download(12);
        QTRY_COMPARE(pub.requests.size(), 1);
        QTest::qWait(200);
        QCOMPARE(pub.requests.size(), 1);
        QCOMPARE(downloaded.count(), 0);
        QVERIFY(team.busy());
        team.cancel();
        QTRY_COMPARE(uploaded.count(), 1);
        QCOMPARE(uploaded.at(0).at(0).toBool(), false);
        QCOMPARE(uploaded.at(0).at(1).toString(), QString());
        QVERIFY(!team.busy());
    }

    void aDownloadOpensThroughTrackFile()
    {
        FakeHttp pub;
        PhotoStore source(nullptr);
        const QByteArray picture = png(QSize(16, 12));
        pub.reply("GET", "/api/cone/tracks/12/file",
                  FakeReply{ 200, "application/json", TrackFile::documentBytes(document(), &source, source.add(picture)) });
        PhotoStore photos(nullptr);
        TeamServer team;
        team.setPhotos(&photos);
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        QSignalSpy downloaded(&team, &TeamServer::downloaded);
        team.download(12);
        QTRY_COMPARE(downloaded.count(), 1);
        QVERIFY(downloaded.at(0).at(0).toBool());
        const QVariantMap read = downloaded.at(0).at(1).toMap();
        QCOMPARE(photos.bytes(read.value("photoRef").toInt()), picture);
        QVERIFY(read.value("text").toString().contains(QStringLiteral("\"name\":\"Lot\"")));

        team.download(13);                                    // not on the team any more
        QTRY_COMPARE(downloaded.count(), 2);
        QCOMPARE(downloaded.at(1).at(2).toString(), QStringLiteral("That track is no longer on the team."));
    }
};

QTEST_MAIN(TestTeamServer)
#include "tst_teamserver.moc"
