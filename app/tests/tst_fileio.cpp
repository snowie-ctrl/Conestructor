#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>

#include "services/FileIO.h"

class TestFileIO : public QObject
{
    Q_OBJECT

    QTemporaryDir dir;

private slots:
    void theExportHoldsMetresInTheExportFrame()
    {
        QVariantList cones;
        cones << QVariantMap{ { "index", 0 }, { "type", "standing" }, { "x", 1.23456 }, { "y", -4.0 }, { "heading", 90.123 } }
              << QVariantMap{ { "index", 1 }, { "type", "leaning" }, { "x", 2.0 }, { "y", -0.00001 }, { "heading", -45.0 } };
        const QString path = dir.filePath(QStringLiteral("cones.json"));

        FileIO io;
        QCOMPARE(io.writeConeExport(path, 41.2, cones), QString());

        QFile file(path);
        QVERIFY(file.open(QIODevice::ReadOnly));
        const QJsonObject doc = QJsonDocument::fromJson(file.readAll()).object();
        QCOMPARE(doc.value("units").toString(), QStringLiteral("m"));
        QCOMPARE(doc.value("axes").toString(),
                 QStringLiteral("x toward Direction target, y to the left, heading degrees counter-clockwise from +x"));
        QCOMPARE(doc.value("targetDistance").toDouble(), 41.2);
        const QJsonArray list = doc.value("cones").toArray();
        QCOMPARE(list.size(), 2);
        const QJsonObject first = list.at(0).toObject();
        QCOMPARE(first.value("index").toInt(), 0);
        QCOMPARE(first.value("type").toString(), QStringLiteral("standing"));
        QCOMPARE(first.value("x").toDouble(), 1.235);
        QCOMPARE(first.value("y").toDouble(), -4.0);
        QCOMPARE(first.value("heading").toDouble(), 90.12);
        const QJsonObject second = list.at(1).toObject();
        QCOMPARE(second.value("type").toString(), QStringLiteral("leaning"));
        QCOMPARE(second.value("y").toDouble(), 0.0);
        QVERIFY(!QJsonDocument(doc).toJson().contains("-0"));
    }

    void anUnwritablePathSaysWhy()
    {
        FileIO io;
        const QString message = io.writeConeExport(dir.filePath(QStringLiteral("missing/folder/cones.json")), 1.0, {});
        QVERIFY(!message.isEmpty());
        QVERIFY(message.contains(QStringLiteral("cones.json")));
    }

    void localPaths()
    {
        FileIO io;
        QCOMPARE(io.toLocalPath(QUrl::fromLocalFile(QStringLiteral("C:/lots/lot.png"))), QStringLiteral("C:/lots/lot.png"));
    }
};

QTEST_GUILESS_MAIN(TestFileIO)
#include "tst_fileio.moc"
