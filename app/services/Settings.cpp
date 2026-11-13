#include "Settings.h"

#include <QDir>
#include <QFileInfo>
#include <QSettings>
#include <cmath>
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

double carSize(double metres)
{
    return qBound(Settings::minCarSize, metres, Settings::maxCarSize);
}

// A finite number from the ini, or `fallback` when the stored text is not one (or is nan or infinite).
double storedNumber(const QSettings &ini, const QString &key, double fallback)
{
    bool ok = false;
    const double value = ini.value(key).toDouble(&ok);
    return ok && std::isfinite(value) ? value : fallback;
}

} // namespace

Settings::Settings(QObject *parent) : QObject(parent), m_units(defaultUnits())
{
    QSettings ini = openIni();
    const QString stored = ini.value(QStringLiteral("units")).toString();
    if (unitChoices().contains(stored))
        m_units = stored;
    m_recent = ini.value(QStringLiteral("recentFiles")).toStringList();
    m_conesOwned = int(qBound(0.0, storedNumber(ini, QStringLiteral("conesOwned"), 0), double(maxConesOwned)));
    m_carLength = carSize(storedNumber(ini, QStringLiteral("carLength"), defaultCarLength));
    m_carWidth = carSize(storedNumber(ini, QStringLiteral("carWidth"), defaultCarWidth));
    m_carImage = ini.value(QStringLiteral("carImage")).toString();
    m_teamCode = ini.value(QStringLiteral("teamCode")).toString().trimmed();
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

void Settings::setConesOwned(int count)
{
    count = qBound(0, count, maxConesOwned);
    if (count == m_conesOwned)
        return;
    m_conesOwned = count;
    emit conesOwnedChanged();
    save();
}

void Settings::setCarLength(double metres)
{
    metres = carSize(metres);
    if (qFuzzyCompare(metres, m_carLength))
        return;
    m_carLength = metres;
    emit carLengthChanged();
    save();
}

void Settings::setCarWidth(double metres)
{
    metres = carSize(metres);
    if (qFuzzyCompare(metres, m_carWidth))
        return;
    m_carWidth = metres;
    emit carWidthChanged();
    save();
}

void Settings::setCarImage(const QString &path)
{
    const QString native = QDir::toNativeSeparators(path);
    if (native == m_carImage)
        return;
    m_carImage = native;
    emit carImageChanged();
    save();
}

bool Settings::carImageFound() const
{
    return !m_carImage.isEmpty() && QFileInfo(m_carImage).isFile();
}

void Settings::setTeamCode(const QString &code)
{
    const QString trimmed = code.trimmed();
    if (trimmed == m_teamCode)
        return;
    m_teamCode = trimmed;
    emit teamCodeChanged();
    save();
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
    ini.setValue(QStringLiteral("conesOwned"), m_conesOwned);
    ini.setValue(QStringLiteral("carLength"), m_carLength);
    ini.setValue(QStringLiteral("carWidth"), m_carWidth);
    ini.setValue(QStringLiteral("carImage"), m_carImage);
    ini.setValue(QStringLiteral("teamCode"), m_teamCode);
    ini.sync();
    if (ini.status() != QSettings::NoError)
        emit saveFailed(tr("Could not save your preferences to %1. They apply until Conestructor closes.")
                            .arg(QDir::toNativeSeparators(ini.fileName())));
}
