#include "FileIO.h"

#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <cmath>

namespace {

// Rounded to `places` decimals; adding 0.0 turns -0 into 0 so the file never says "-0".
double rounded(double value, int places)
{
    const double factor = std::pow(10.0, places);
    return std::round(value * factor) / factor + 0.0;
}

} // namespace

QString FileIO::toLocalPath(const QUrl &url) const
{
    return url.isLocalFile() ? url.toLocalFile() : url.toString();
}

QString FileIO::axesText()
{
    return QStringLiteral("x toward Direction target, y to the left, heading degrees counter-clockwise from +x");
}

QByteArray FileIO::coneExportJson(double targetDistance, const QVariantList &cones)
{
    QJsonArray list;
    for (const QVariant &value : cones) {
        const QVariantMap cone = value.toMap();
        QJsonObject item;
        item.insert(QStringLiteral("index"), cone.value(QStringLiteral("index")).toInt());
        item.insert(QStringLiteral("type"), cone.value(QStringLiteral("type")).toString());
        item.insert(QStringLiteral("x"), rounded(cone.value(QStringLiteral("x")).toDouble(), 3));
        item.insert(QStringLiteral("y"), rounded(cone.value(QStringLiteral("y")).toDouble(), 3));
        item.insert(QStringLiteral("heading"), rounded(cone.value(QStringLiteral("heading")).toDouble(), 2));
        list.append(item);
    }
    QJsonObject document;
    document.insert(QStringLiteral("units"), QStringLiteral("m"));
    document.insert(QStringLiteral("axes"), axesText());
    document.insert(QStringLiteral("targetDistance"), rounded(targetDistance, 3));
    document.insert(QStringLiteral("cones"), list);
    return QJsonDocument(document).toJson(QJsonDocument::Indented);
}

QString FileIO::writeConeExport(const QString &path, double targetDistance, const QVariantList &cones) const
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return tr("Could not write %1: %2").arg(QDir::toNativeSeparators(path), file.errorString());
    file.write(coneExportJson(targetDistance, cones));
    if (!file.commit())
        return tr("Could not write %1: %2").arg(QDir::toNativeSeparators(path), file.errorString());
    return {};
}
