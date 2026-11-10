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
};

QTEST_GUILESS_MAIN(TestSettings)
#include "tst_settings.moc"
