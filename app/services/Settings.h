#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// The owner's preferences, saved as Conestructor.ini under %APPDATA%\Conestructor (one file to find, read, back up or
// delete). Part 1 has the units lengths are shown and typed in; part 2 adds the recent files; part 4 adds the cones the
// team owns and the car outline's size and picture; part 5 adds the team code. Files always hold metres
// whatever this says.
class Settings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString units READ units WRITE setUnits NOTIFY unitsChanged)
    Q_PROPERTY(QStringList recentFiles READ recentFiles NOTIFY recentFilesChanged)
    Q_PROPERTY(int conesOwned READ conesOwned WRITE setConesOwned NOTIFY conesOwnedChanged)
    Q_PROPERTY(double carLength READ carLength WRITE setCarLength NOTIFY carLengthChanged)
    Q_PROPERTY(double carWidth READ carWidth WRITE setCarWidth NOTIFY carWidthChanged)
    Q_PROPERTY(QString carImage READ carImage WRITE setCarImage NOTIFY carImageChanged)
    Q_PROPERTY(QString teamCode READ teamCode WRITE setTeamCode NOTIFY teamCodeChanged)

public:
    explicit Settings(QObject *parent = nullptr);

    QString units() const { return m_units; }
    // Ignores anything that is not one of unitChoices().
    void setUnits(const QString &units);

    // Tracks opened or saved lately, newest first, at most eight, with native separators. Paths are compared
    // ignoring case (Windows paths).
    QStringList recentFiles() const { return m_recent; }
    Q_INVOKABLE void addRecentFile(const QString &path);
    Q_INVOKABLE void removeRecentFile(const QString &path);
    Q_INVOKABLE void clearRecentFiles();

    // How many cones the team owns: the status bar shows the track's count against it. 0 means no budget; kept within
    // 0 to maxConesOwned.
    int conesOwned() const { return m_conesOwned; }
    void setConesOwned(int count);

    // The true-size car outline (Tools > Car outline), in metres, kept within minCarSize to maxCarSize.
    double carLength() const { return m_carLength; }
    void setCarLength(double metres);
    double carWidth() const { return m_carWidth; }
    void setCarWidth(double metres);

    // A top-down picture of the car drawn inside the outline (its top is the car's front); "" for none.
    QString carImage() const { return m_carImage; }
    void setCarImage(const QString &path);
    // Whether carImage names a file that is there.
    Q_INVOKABLE bool carImageFound() const;

    // The team code (Preferences › Team): the team server's addresses and the team's key, as the team's admin gave it;
    // "" for none. Kept without the spaces around it; TeamServer reads it.
    QString teamCode() const { return m_teamCode; }
    void setTeamCode(const QString &code);

    static constexpr int maxConesOwned = 9999;
    static constexpr double minCarSize = 0.5;
    static constexpr double maxCarSize = 10;
    static constexpr double defaultCarLength = 2.9;
    static constexpr double defaultCarWidth = 1.4;

    static QStringList unitChoices();   // ftin (feet and inches), ft (decimal feet), m (metres)
    static QString defaultUnits();      // ftin

signals:
    void unitsChanged();
    void recentFilesChanged();
    void conesOwnedChanged();
    void carLengthChanged();
    void carWidthChanged();
    void carImageChanged();
    void teamCodeChanged();
    // The ini could not be written; the value still applies for this session.
    void saveFailed(const QString &message);

private:
    void save();
    void setRecent(const QStringList &list);

    QString m_units;
    QStringList m_recent;
    int m_conesOwned = 0;
    double m_carLength = defaultCarLength;
    double m_carWidth = defaultCarWidth;
    QString m_carImage;
    QString m_teamCode;
};
