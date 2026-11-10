// exportmanager.h
#pragma once
#include <QObject>
#include <QVariantMap>
#include <QVariantList>

class ExportManager : public QObject {
    Q_OBJECT
public:
    explicit ExportManager(QObject *parent = nullptr) : QObject(parent) {}

    //Q_INVOKABLE void exportXlsx(const QVariantMap &metadata, const QVariantList &cones, const QString &imagePath, const QString &outputPath);
    Q_INVOKABLE void exportJson(const QVariantList &cones, const QString &outputPath);
    Q_INVOKABLE void exportPng(const QString &outputPath);   // optional now, per note above
    Q_INVOKABLE void uploadToDatabase(const QVariantMap &metadata, const QVariantList &cones, const QString &imagePath);

    Q_INVOKABLE QString tempImagePath();

signals:
    void exportFinished(bool success, QString message);

private:
    void scpUpload(const QString &localPath, int trackId);
};
