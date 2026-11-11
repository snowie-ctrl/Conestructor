#include <QColor>
#include <QFile>
#include <QImage>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>

#include "services/PhotoStore.h"

class TestPhotoStore : public QObject
{
    Q_OBJECT

    QTemporaryDir dir;

    QString picture(const QString &name, const char *format, QSize size)
    {
        QImage image(size, QImage::Format_RGB32);
        image.fill(QColor(200, 40, 40));
        const QString path = dir.filePath(name);
        image.save(path, format);
        return path;
    }

    static QByteArray bytesOf(const QString &path)
    {
        QFile file(path);
        file.open(QIODevice::ReadOnly);
        return file.readAll();
    }

private slots:
    void aPngLoadsWithItsBytesAndSize()
    {
        const QString path = picture(QStringLiteral("lot.png"), "PNG", QSize(40, 30));
        PhotoStore store;
        const QVariantMap r = store.load(path);
        QVERIFY2(!r.contains(QStringLiteral("error")), qPrintable(r.value(QStringLiteral("error")).toString()));
        const int ref = r.value(QStringLiteral("ref")).toInt();
        QVERIFY(ref > 0);
        QCOMPARE(r.value(QStringLiteral("width")).toInt(), 40);
        QCOMPARE(r.value(QStringLiteral("height")).toInt(), 30);
        QCOMPARE(store.bytes(ref), bytesOf(path));
        QCOMPARE(store.mediaType(ref), QStringLiteral("image/png"));
        QCOMPARE(store.size(ref), QSize(40, 30));
        QCOMPARE(store.url(ref), QStringLiteral("image://photo/%1").arg(ref));
    }

    void aJpegLoadsFromAFileUrl()
    {
        const QString path = picture(QStringLiteral("lot.jpg"), "JPEG", QSize(32, 24));
        PhotoStore store;
        const QVariantMap r = store.load(QUrl::fromLocalFile(path).toString());
        const int ref = r.value(QStringLiteral("ref")).toInt();
        QVERIFY(ref > 0);
        QCOMPARE(store.mediaType(ref), QStringLiteral("image/jpeg"));
        QCOMPARE(store.bytes(ref), bytesOf(path));
    }

    void theProviderServesThePicture()
    {
        PhotoStore store;
        const int ref = store.add(bytesOf(picture(QStringLiteral("p.png"), "PNG", QSize(16, 8))));
        PhotoProvider provider(store.shelf());
        QSize size;
        const QImage image = provider.requestImage(QString::number(ref), &size, QSize());
        QCOMPARE(size, QSize(16, 8));
        QCOMPARE(image.pixelColor(3, 3), QColor(200, 40, 40));
        QVERIFY(provider.requestImage(QStringLiteral("999"), &size, QSize()).isNull());
    }

    void somethingElseIsRefused()
    {
        PhotoStore store;
        QCOMPARE(store.add(QByteArray("not a picture")), -1);
        QFile notes(dir.filePath(QStringLiteral("notes.png")));
        QVERIFY(notes.open(QIODevice::WriteOnly));
        notes.write("hello");
        notes.close();
        QCOMPARE(store.load(notes.fileName()).value(QStringLiteral("error")).toString(),
                 QStringLiteral("Could not open that photo. The background is unchanged."));
        QVERIFY(store.load(dir.filePath(QStringLiteral("missing.png"))).contains(QStringLiteral("error")));
    }

    void refsAreNeverReusedAndClearKeepsOne()
    {
        PhotoStore store;
        const QByteArray png = bytesOf(picture(QStringLiteral("c.png"), "PNG", QSize(4, 4)));
        const int a = store.add(png);
        const int b = store.add(png);
        QVERIFY(b > a);
        store.clear(b);
        QVERIFY(!store.has(a));
        QVERIFY(store.has(b));
        store.remove(b);
        QVERIFY(!store.has(b));
        QVERIFY(store.add(png) > b);
        store.clear(-1);
        QVERIFY(!store.has(b + 1));
    }
};

QTEST_MAIN(TestPhotoStore)
#include "tst_photostore.moc"
