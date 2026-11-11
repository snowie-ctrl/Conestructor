#include <QDir>
#include <QFile>
#include <QSettings>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include "services/Settings.h"

class TestSettings : public QObject
{
    Q_OBJECT

    QTemporaryDir dir;

    static QSettings ini()
    {
        return QSettings(QSettings::IniFormat, QSettings::UserScope, QStringLiteral("Conestructor"),
                         QStringLiteral("Conestructor"));
    }

private slots:
    void initTestCase()
    {
        // Before any Settings exists, so the owner's real ini is never read or written.
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, dir.path());
    }

    void init()
    {
        QSettings settings = ini();
        settings.clear();
        settings.sync();
    }

    void defaultsToFeetAndInches()
    {
        Settings s;
        QCOMPARE(s.units(), QStringLiteral("ftin"));
        QCOMPARE(Settings::unitChoices(), QStringList({ "ftin", "ft", "m" }));
    }

    void unitsSurviveARestart()
    {
        {
            Settings s;
            QSignalSpy changed(&s, &Settings::unitsChanged);
            s.setUnits(QStringLiteral("m"));
            QCOMPARE(changed.count(), 1);
        }
        Settings again;
        QCOMPARE(again.units(), QStringLiteral("m"));
        QCOMPARE(ini().value("units").toString(), QStringLiteral("m"));
    }

    void theFileIsConestructorIni()
    {
        Settings s;
        s.setUnits(QStringLiteral("ft"));
        QVERIFY(QFile::exists(dir.path() + QStringLiteral("/Conestructor/Conestructor.ini")));
    }

    void unknownUnitsAreIgnored()
    {
        Settings s;
        QSignalSpy changed(&s, &Settings::unitsChanged);
        s.setUnits(QStringLiteral("furlongs"));
        QCOMPARE(changed.count(), 0);
        QCOMPARE(s.units(), QStringLiteral("ftin"));
    }

    void settingTheSameUnitsSaysNothing()
    {
        Settings s;
        QSignalSpy changed(&s, &Settings::unitsChanged);
        s.setUnits(QStringLiteral("ftin"));
        QCOMPARE(changed.count(), 0);
    }

    void aBadValueInTheFileFallsBackToTheDefault()
    {
        {
            QSettings file = ini();
            file.setValue("units", "cubits");
            file.sync();
        }
        Settings s;
        QCOMPARE(s.units(), QStringLiteral("ftin"));
    }

    void aFailedSaveIsReportedAndTheValueKept()
    {
        // A file where the Conestructor folder should be, so the ini cannot be written.
        QTemporaryDir blocked;
        QFile blocker(blocked.path() + QStringLiteral("/Conestructor"));
        QVERIFY(blocker.open(QIODevice::WriteOnly));
        blocker.close();
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, blocked.path());

        Settings s;
        QSignalSpy failed(&s, &Settings::saveFailed);
        s.setUnits(QStringLiteral("m"));
        QCOMPARE(failed.count(), 1);
        QVERIFY(!failed.first().first().toString().isEmpty());
        QCOMPARE(s.units(), QStringLiteral("m"));

        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, dir.path());
    }
    void recentFilesAreNewestFirstAndAtMostEight()
    {
        Settings s;
        QSignalSpy changed(&s, &Settings::recentFilesChanged);
        for (int i = 1; i <= 10; ++i)
            s.addRecentFile(QStringLiteral("C:/tracks/t%1.cone").arg(i));
        QCOMPARE(s.recentFiles().size(), 8);
        QCOMPARE(s.recentFiles().first(), QDir::toNativeSeparators(QStringLiteral("C:/tracks/t10.cone")));
        QCOMPARE(s.recentFiles().last(), QDir::toNativeSeparators(QStringLiteral("C:/tracks/t3.cone")));
        QCOMPARE(changed.count(), 10);
    }

    void aFileOpenedAgainMovesToTheTop()
    {
        Settings s;
        s.addRecentFile(QStringLiteral("C:/tracks/a.cone"));
        s.addRecentFile(QStringLiteral("C:/tracks/b.cone"));
        s.addRecentFile(QStringLiteral("c:\\TRACKS\\a.cone"));     // the same file on Windows
        QCOMPARE(s.recentFiles(), QStringList({ QStringLiteral("c:\\TRACKS\\a.cone"),
                                                QDir::toNativeSeparators(QStringLiteral("C:/tracks/b.cone")) }));
    }

    void recentFilesCanBeRemovedAndCleared()
    {
        Settings s;
        s.addRecentFile(QStringLiteral("C:/tracks/a.cone"));
        s.addRecentFile(QStringLiteral("C:/tracks/b.cone"));
        s.removeRecentFile(QStringLiteral("C:/tracks/a.cone"));
        QCOMPARE(s.recentFiles().size(), 1);
        s.clearRecentFiles();
        QVERIFY(s.recentFiles().isEmpty());
    }

    void recentFilesSurviveARestart()
    {
        {
            Settings s;
            s.addRecentFile(QStringLiteral("C:/tracks/a.cone"));
            s.setUnits(QStringLiteral("m"));
        }
        Settings again;
        QCOMPARE(again.recentFiles(), QStringList({ QDir::toNativeSeparators(QStringLiteral("C:/tracks/a.cone")) }));
        QCOMPARE(again.units(), QStringLiteral("m"));
    }
};

QTEST_GUILESS_MAIN(TestSettings)
#include "tst_settings.moc"
