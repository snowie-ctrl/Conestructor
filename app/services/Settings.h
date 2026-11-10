#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// The owner's preferences, saved as Conestructor.ini under %APPDATA%\Conestructor (one file to find, read, back up or
// delete). Part 1 has one: the units lengths are shown and typed in. Files always hold metres whatever this says.
class Settings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString units READ units WRITE setUnits NOTIFY unitsChanged)

public:
    explicit Settings(QObject *parent = nullptr);

    QString units() const { return m_units; }
    // Ignores anything that is not one of unitChoices().
    void setUnits(const QString &units);

    static QStringList unitChoices();   // ftin (feet and inches), ft (decimal feet), m (metres)
    static QString defaultUnits();      // ftin

signals:
    void unitsChanged();
    // The ini could not be written; the value still applies for this session.
    void saveFailed(const QString &message);

private:
    void save();

    QString m_units;
};
