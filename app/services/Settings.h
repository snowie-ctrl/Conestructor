#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// The owner's preferences, saved as Conestructor.ini under %APPDATA%\Conestructor (one file to find, read, back up or
// delete). Part 1 has the units lengths are shown and typed in; part 2 adds the recent files. Files always hold metres
// whatever this says.
class Settings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString units READ units WRITE setUnits NOTIFY unitsChanged)
    Q_PROPERTY(QStringList recentFiles READ recentFiles NOTIFY recentFilesChanged)

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

    static QStringList unitChoices();   // ftin (feet and inches), ft (decimal feet), m (metres)
    static QString defaultUnits();      // ftin

signals:
    void unitsChanged();
    void recentFilesChanged();
    // The ini could not be written; the value still applies for this session.
    void saveFailed(const QString &message);

private:
    void save();
    void setRecent(const QStringList &list);

    QString m_units;
    QStringList m_recent;
};
