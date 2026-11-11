#include "Settings.h"

#include <QDir>
#include <QSettings>
#include <utility>

namespace {

QSettings openIni()
{
    return QSettings(QSettings::IniFormat, QSettings::UserScope, QStringLiteral("Conestructor"),
                     QStringLiteral("Conestructor"));
}

bool samePath(const QString &a, const QString &b)
{
    return QDir::cleanPath(QDir::fromNativeSeparators(a)).compare(QDir::cleanPath(QDir::fromNativeSeparators(b)),
                                                                 Qt::CaseInsensitive) == 0;
}

} // namespace

Settings::Settings(QObject *parent) : QObject(parent), m_units(defaultUnits())
{
    QSettings ini = openIni();
    const QString stored = ini.value(QStringLiteral("units")).toString();
    if (unitChoices().contains(stored))
        m_units = stored;
    m_recent = ini.value(QStringLiteral("recentFiles")).toStringList();
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

void Settings::addRecentFile(const QString &path)
{
    QStringList list{ QDir::toNativeSeparators(path) };
    for (const QString &p : std::as_const(m_recent))
        if (!samePath(p, path) && list.size() < 8)
            list << p;
    setRecent(list);
}

void Settings::removeRecentFile(const QString &path)
{
    QStringList list;
    for (const QString &p : std::as_const(m_recent))
        if (!samePath(p, path))
            list << p;
    setRecent(list);
}

void Settings::clearRecentFiles()
{
    setRecent({});
}

void Settings::setRecent(const QStringList &list)
{
    if (list == m_recent)
        return;
    m_recent = list;
    emit recentFilesChanged();
    save();
}

void Settings::save()
{
    QSettings ini = openIni();
    ini.setValue(QStringLiteral("units"), m_units);
    ini.setValue(QStringLiteral("recentFiles"), m_recent);
    ini.sync();
    if (ini.status() != QSettings::NoError)
        emit saveFailed(tr("Could not save your preferences to %1. They apply until Conestructor closes.")
                            .arg(QDir::toNativeSeparators(ini.fileName())));
}
