#include "Settings.h"

#include <QDir>
#include <QSettings>

namespace {

QSettings openIni()
{
    return QSettings(QSettings::IniFormat, QSettings::UserScope, QStringLiteral("Conestructor"),
                     QStringLiteral("Conestructor"));
}

} // namespace

Settings::Settings(QObject *parent) : QObject(parent), m_units(defaultUnits())
{
    QSettings ini = openIni();
    const QString stored = ini.value(QStringLiteral("units")).toString();
    if (unitChoices().contains(stored))
        m_units = stored;
}

QStringList Settings::unitChoices()
{
    return { QStringLiteral("ftin"), QStringLiteral("ft"), QStringLiteral("m") };
}

QString Settings::defaultUnits()
{
    return QStringLiteral("ftin");
}

void Settings::setUnits(const QString &units)
{
    if (!unitChoices().contains(units) || units == m_units)
        return;
    m_units = units;
    emit unitsChanged();
    save();
}

void Settings::save()
{
    QSettings ini = openIni();
    ini.setValue(QStringLiteral("units"), m_units);
    ini.sync();
    if (ini.status() != QSettings::NoError)
        emit saveFailed(tr("Could not save your preferences to %1. They apply until Conestructor closes.")
                            .arg(QDir::toNativeSeparators(ini.fileName())));
}
