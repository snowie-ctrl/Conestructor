#include <QBuffer>
#include <QColor>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QImage>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSettings>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>
#include <memory>

#include "services/PhotoStore.h"
#include "services/TrackFile.h"

class TestTrackFile : public QObject
{
    Q_OBJECT

    QTemporaryDir dir;

    static QByteArray encoded(const QImage &image, const char *format)
    {
        QByteArray bytes;
        QBuffer buffer(&bytes);
        buffer.open(QIODevice::WriteOnly);
        image.save(&buffer, format);
        return bytes;
    }

    static QByteArray png(QSize size)
    {
        QImage image(size, QImage::Format_RGB32);
        image.fill(QColor(30, 120, 200));
        return encoded(image, "PNG");
    }

    static QByteArray read(const QString &path)
    {
        QFile file(path);
        file.open(QIODevice::ReadOnly);
        return file.readAll();
    }

    static void write(const QString &path, const QByteArray &bytes)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(bytes);
    }

    // What conefile.mjs would hand over: a JSON object without the photo.
    static QString document()
    {
        return QStringLiteral("{\n  \"format\": \"conestructor-track\",\n  \"version\": 1,\n  \"name\": \"Lot\",\n"
                              "  \"design\": {\n    \"nextId\": 3\n  }\n}");
    }

private slots:
    void initTestCase()
    {
        // The backup lives beside Conestructor.ini; keep it away from the owner's.
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, dir.path());
    }

    void saveThenOpenKeepsEverything()
    {
        PhotoStore photos(nullptr);
        const QByteArray picture = png(QSize(64, 48));
        const int ref = photos.add(picture);
        const QString path = dir.filePath(QStringLiteral("Lot.cone"));
        QCOMPARE(TrackFile::saveTo(path, document(), &photos, ref), QString());

        const QByteArray raw = read(path);
        QVERIFY(raw.startsWith("{\n  \"format\": \"conestructor-track\""));
        QVERIFY(raw.indexOf("\"photo\"") > raw.indexOf("\"design\""));
        QVERIFY(raw.endsWith("\"\n  }\n}\n"));
        const QJsonObject json = QJsonDocument::fromJson(raw).object();
        const QJsonObject photo = json.value(QStringLiteral("photo")).toObject();
        QCOMPARE(photo.value(QStringLiteral("mediaType")).toString(), QStringLiteral("image/png"));
        QCOMPARE(photo.value(QStringLiteral("width")).toInt(), 64);
        QCOMPARE(photo.value(QStringLiteral("height")).toInt(), 48);
        QCOMPARE(QByteArray::fromBase64(photo.value(QStringLiteral("data")).toString().toLatin1()), picture);

        PhotoStore other(nullptr);
        const QVariantMap opened = TrackFile::openFrom(path, &other);
        QVERIFY(!opened.contains(QStringLiteral("error")));
        const int newRef = opened.value(QStringLiteral("photoRef")).toInt();
        QVERIFY(newRef > 0);
        QCOMPARE(other.bytes(newRef), picture);
        QVERIFY(!opened.value(QStringLiteral("photoError")).toBool());
        const QJsonObject text = QJsonDocument::fromJson(opened.value(QStringLiteral("text")).toString().toUtf8()).object();
        QCOMPARE(text.value(QStringLiteral("name")).toString(), QStringLiteral("Lot"));
        QCOMPARE(text.value(QStringLiteral("design")).toObject().value(QStringLiteral("nextId")).toInt(), 3);
        QVERIFY(!text.contains(QStringLiteral("photo")));
    }

    void withoutAPhotoTheFieldIsNull()
    {
        const QString path = dir.filePath(QStringLiteral("Blueprint.cone"));
        QCOMPARE(TrackFile::saveTo(path, document(), nullptr, -1), QString());
        QVERIFY(QJsonDocument::fromJson(read(path)).object().value(QStringLiteral("photo")).isNull());
        const QVariantMap opened = TrackFile::openFrom(path, nullptr);
        QCOMPARE(opened.value(QStringLiteral("photoRef")).toInt(), -1);
        QVERIFY(!opened.value(QStringLiteral("photoError")).toBool());
    }

    // Part 5: an upload sends exactly what Save writes, and a download opens as a file from disk does.
    void theFilesBytesAreWhatSaveWrites()
    {
        PhotoStore photos(nullptr);
        const int ref = photos.add(png(QSize(32, 24)));
        const QString path = dir.filePath(QStringLiteral("Bytes.cone"));
        QCOMPARE(TrackFile::saveTo(path, document(), &photos, ref), QString());
        QCOMPARE(TrackFile::documentBytes(document(), &photos, ref), read(path));
        QCOMPARE(TrackFile::saveTo(path, document(), nullptr, -1), QString());
        QCOMPARE(TrackFile::documentBytes(document(), nullptr, -1), read(path));
        QVERIFY(TrackFile::documentBytes(QStringLiteral("not an object"), &photos, ref).isEmpty());
    }

    void bytesOpenAsAFileDoes()
    {
        PhotoStore source(nullptr);
        const QByteArray picture = png(QSize(32, 24));
        const QByteArray bytes = TrackFile::documentBytes(document(), &source, source.add(picture));
        PhotoStore photos(nullptr);
        const QVariantMap opened = TrackFile::openBytes(bytes, &photos);
        QVERIFY(!opened.contains(QStringLiteral("error")));
        QCOMPARE(photos.bytes(opened.value(QStringLiteral("photoRef")).toInt()), picture);
        const QJsonObject text = QJsonDocument::fromJson(opened.value(QStringLiteral("text")).toString().toUtf8()).object();
        QCOMPARE(text.value(QStringLiteral("name")).toString(), QStringLiteral("Lot"));
        QVERIFY(!text.contains(QStringLiteral("photo")));
        QCOMPARE(TrackFile::openBytes("hello", &photos).value(QStringLiteral("error")).toString(), QStringLiteral("notJson"));
    }

    void notJsonIsRefused()
    {
        const QString path = dir.filePath(QStringLiteral("notes.cone"));
        write(path, "hello");
        QCOMPARE(TrackFile::openFrom(path, nullptr).value(QStringLiteral("error")).toString(), QStringLiteral("notJson"));
    }

    void aMissingFileSaysSo()
    {
        const QVariantMap r = TrackFile::openFrom(dir.filePath(QStringLiteral("gone.cone")), nullptr);
        QCOMPARE(r.value(QStringLiteral("error")).toString(), QStringLiteral("missing"));
        QVERIFY(r.value(QStringLiteral("message")).toString().contains(QStringLiteral("gone.cone")));
    }

    void aBrokenPhotoOpensWithoutIt()
    {
        const QString path = dir.filePath(QStringLiteral("broken.cone"));
        write(path, "{\"format\": \"conestructor-track\", \"version\": 1, \"photo\": {\"mediaType\": \"image/png\", "
                    "\"width\": 1, \"height\": 1, \"data\": \"bm90IGFuIGltYWdl\"}}");
        PhotoStore photos(nullptr);
        const QVariantMap r = TrackFile::openFrom(path, &photos);
        QVERIFY(!r.contains(QStringLiteral("error")));
        QCOMPARE(r.value(QStringLiteral("photoRef")).toInt(), -1);
        QVERIFY(r.value(QStringLiteral("photoError")).toBool());
    }

    void aSaveThatCannotWriteSaysWhy()
    {
        const QString path = dir.filePath(QStringLiteral("no such folder/x.cone"));
        QVERIFY(TrackFile::saveTo(path, document(), nullptr, -1).startsWith(QStringLiteral("Could not write")));
    }

    void aPathWithAccentsAndSpacesWorks()
    {
        QVERIFY(QDir(dir.path()).mkpath(QStringLiteral("Team tracks")));
        const QString path = dir.filePath(QStringLiteral("Team tracks/Piste d'\u00e9t\u00e9.cone"));
        TrackFile files;
        QCOMPARE(TrackFile::saveTo(path, document(), nullptr, -1), QString());
        QVERIFY(files.exists(path));
        QCOMPARE(files.baseName(path), QStringLiteral("Piste d'\u00e9t\u00e9"));
        QVERIFY(!TrackFile::openFrom(path, nullptr).contains(QStringLiteral("error")));
        QCOMPARE(files.toLocalPath(QUrl::fromLocalFile(path)), path);
    }

    // A full-size phone photo (4000 x 3000, noisy so it does not compress away) survives and does not crawl.
    void aBigPhotoRoundTrips()
    {
        QImage image(4000, 3000, QImage::Format_RGB32);
        quint32 seed = 12345;
        for (int y = 0; y < image.height(); ++y) {
            auto *line = reinterpret_cast<quint32 *>(image.scanLine(y));
            for (int x = 0; x < image.width(); ++x) {
                seed = seed * 1664525u + 1013904223u;
                line[x] = 0xff000000u | (seed >> 8);
            }
        }
        const QByteArray jpeg = encoded(image, "JPEG");
        PhotoStore photos(nullptr);
        const int ref = photos.add(jpeg);
        QVERIFY(ref > 0);
        const QString path = dir.filePath(QStringLiteral("Big.cone"));
        QElapsedTimer timer;
        timer.start();
        QCOMPARE(TrackFile::saveTo(path, document(), &photos, ref), QString());
        PhotoStore other(nullptr);
        const QVariantMap opened = TrackFile::openFrom(path, &other);
        const qint64 ms = timer.elapsed();
        QCOMPARE(other.bytes(opened.value(QStringLiteral("photoRef")).toInt()), jpeg);
        QVERIFY2(ms < 10000, qPrintable(QStringLiteral("%1 ms").arg(ms)));
    }

    void theBackupIsFoundAndDeleted()
    {
        TrackFile files;
        files.deleteBackup();
        QVERIFY(files.findBackup().isEmpty());
        QCOMPARE(files.writeBackup(document(), -1, QStringLiteral("C:/tracks/Lot.cone"), QStringLiteral("Lot")), QString());
        const QVariantMap b = files.findBackup();
        QCOMPARE(b.value(QStringLiteral("name")).toString(), QStringLiteral("Lot"));
        QCOMPARE(b.value(QStringLiteral("trackPath")).toString(), QStringLiteral("C:/tracks/Lot.cone"));
        QVERIFY(QRegularExpression(QStringLiteral("^\\d\\d:\\d\\d$")).match(b.value(QStringLiteral("time")).toString()).hasMatch());
        QVERIFY(QFile::exists(b.value(QStringLiteral("path")).toString()));
        QVERIFY(QDir::cleanPath(b.value(QStringLiteral("path")).toString()).startsWith(QDir::cleanPath(dir.path())));
        files.deleteBackup();
        QVERIFY(files.findBackup().isEmpty());
    }

    // A second window running at the same time neither offers, overwrites nor deletes the first window's backup;
    // once the first has gone, its backup is the second's to offer.
    void aSecondWindowLeavesTheFirstWindowsBackupAlone()
    {
        auto first = std::make_unique<TrackFile>();
        first->deleteBackup();
        QCOMPARE(first->writeBackup(document(), -1, QStringLiteral("C:/tracks/A.cone"), QStringLiteral("A")), QString());
        {
            TrackFile second;
            QVERIFY(second.findBackup().isEmpty());
            QVERIFY(!second.writeBackup(document(), -1, QString(), QStringLiteral("B")).isEmpty());
            second.deleteBackup();
        }
        QCOMPARE(first->findBackup().value(QStringLiteral("name")).toString(), QStringLiteral("A"));
        first.reset();
        TrackFile later;
        QCOMPARE(later.findBackup().value(QStringLiteral("name")).toString(), QStringLiteral("A"));
        later.deleteBackup();
        QVERIFY(later.findBackup().isEmpty());
    }

    // Minor 3 and 6: a path from the command line is made absolute; Save As starts beside the open track.
    void pathsForTheCommandLineAndSaveAs()
    {
        TrackFile files;
        const QString old = QDir::currentPath();
        QDir::setCurrent(dir.path());
        QCOMPARE(files.absolutePath(QStringLiteral("Relative.cone")),
                 QDir::toNativeSeparators(QDir(dir.path()).filePath(QStringLiteral("Relative.cone"))));
        QCOMPARE(files.absolutePath(QString()), QString());
        QDir::setCurrent(old);
        const QString path = QDir(dir.path()).filePath(QStringLiteral("Duck pond.cone"));
        QCOMPARE(files.folderUrl(path), QUrl::fromLocalFile(dir.path()));
        QCOMPARE(files.fileUrl(path), QUrl::fromLocalFile(path));
    }
};

QTEST_MAIN(TestTrackFile)
#include "tst_trackfile.moc"
