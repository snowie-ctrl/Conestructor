// exportmanager.cpp
#include "exportmanager.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QProcess>
#include <QFile>
#include <QDir>
#include <QStandardPaths>


namespace {
const QString kApiBaseUrl = "http://192.168.50.250/api/cone";
const QString kScpUser = "snowie";
const QString kScpHost = "192.168.50.250";
const QString kRemoteTrackRoot = "/pool/appFiles/conestructor/tracks";
}


QString ExportManager::tempImagePath() {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    QDir().mkpath(dir);   // ensure it exists
    return dir + "/canvas_export.png";
}





void ExportManager::exportJson(const QVariantList &cones, const QString &outputPath) {
    QJsonArray arr;
    for (const QVariant &v : cones) {
        QVariantMap m = v.toMap();
        QJsonObject obj;
        obj["index"] = m["index"].toInt();
        obj["coneType"] = m["coneType"].toString();
        obj["x"] = m["x"].toDouble();
        obj["y"] = m["y"].toDouble();
        obj["heading"] = m["heading"].toDouble();
        arr.append(obj);
    }

    QFile file(outputPath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(arr).toJson());
        file.close();
        emit exportFinished(true, "JSON saved to " + outputPath);
    } else {
        emit exportFinished(false, "Could not write JSON file");
    }
}

void ExportManager::exportPng(const QString &imagePath) {
    QString destPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + "/track_canvas.png";
    if (QFile::copy(imagePath, destPath)) {
        emit exportFinished(true, "PNG saved to " + destPath);
    } else {
        emit exportFinished(false, "Could not save PNG");
    }
}

void ExportManager::uploadToDatabase(const QVariantMap &metadata, const QVariantList &cones, const QString &imagePath) {
    // Step 1: write cone data to a local temp JSON file
    QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/conestructor_upload";
    QDir().mkpath(tempDir);

    QString localJsonPath = tempDir + "/data.json";

    QJsonArray arr;
    for (const QVariant &v : cones) {
        QVariantMap m = v.toMap();
        QJsonObject obj;
        obj["index"] = m.value("index").toInt();
        obj["coneType"] = m.value("coneType").toString();
        obj["x"] = m.value("x").toDouble();
        obj["y"] = m.value("y").toDouble();
        obj["heading"] = m.value("heading").toDouble();
        arr.append(obj);
    }

    QFile jsonFile(localJsonPath);
    if (!jsonFile.open(QIODevice::WriteOnly)) {
        emit exportFinished(false, "Could not write local cone data");
        return;
    }
    jsonFile.write(QJsonDocument(arr).toJson());
    jsonFile.close();

    // Step 2: reserve a unique directory name on the server
    auto *manager = new QNetworkAccessManager(this);
    QNetworkRequest reserveRequest(QUrl(kApiBaseUrl + "/tracks/reserve"));
    reserveRequest.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QJsonObject reservePayload;
    reservePayload["location"] = metadata.value("location").toString();
    reservePayload["processingType"] = metadata.value("processingType").toString();

    QNetworkReply *reserveReply = manager->post(reserveRequest, QJsonDocument(reservePayload).toJson());

    connect(reserveReply, &QNetworkReply::finished, this, [=]() {
        reserveReply->deleteLater();

        if (reserveReply->error() != QNetworkReply::NoError) {
            emit exportFinished(false, "Reserve failed: " + reserveReply->errorString());
            return;
        }

        QJsonObject reserveResponse = QJsonDocument::fromJson(reserveReply->readAll()).object();
        QString dirName = reserveResponse.value("dirName").toString();

        if (dirName.isEmpty()) {
            emit exportFinished(false, "Server did not return a directory name");
            return;
        }

        // Step 3: scp both files into the reserved remote directory
        QString remoteDir = QString("%1@%2:%3/%4/").arg(kScpUser, kScpHost, kRemoteTrackRoot, dirName);

        auto *scpJson = new QProcess(this);
        scpJson->start("scp", { localJsonPath, remoteDir });

        connect(scpJson, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [=](int jsonExitCode, QProcess::ExitStatus) {
                scpJson->deleteLater();

                if (jsonExitCode != 0) {
                    emit exportFinished(false, "SCP upload of data.json failed");
                    return;
                }

                QString localImagePath = imagePath;
                QString remoteImageTarget = QString("%1thumb.png").arg(remoteDir);

                auto *scpImage = new QProcess(this);
                scpImage->start("scp", { localImagePath, remoteImageTarget });

                connect(scpImage, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                    this, [=](int imageExitCode, QProcess::ExitStatus) {
                        scpImage->deleteLater();

                        if (imageExitCode != 0) {
                            emit exportFinished(false, "SCP upload of thumb.png failed");
                            return;
                        }

                        // Step 4: finalize — POST metadata with relative paths
                        QNetworkRequest createRequest(QUrl(kApiBaseUrl + "/tracks/upload"));
                        createRequest.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

                        QJsonObject createPayload;
                        createPayload["location"] = metadata.value("location").toString();
                        createPayload["numCones"] = metadata.value("numCones").toInt();
                        createPayload["processingType"] = metadata.value("processingType").toString();
                        createPayload["thumbnailPath"] = dirName + "/thumb.png";
                        createPayload["filePath"] = dirName + "/data.json";

                        QNetworkReply *createReply = manager->post(createRequest, QJsonDocument(createPayload).toJson());

                        connect(createReply, &QNetworkReply::finished, this, [=]() {
                            createReply->deleteLater();

                            if (createReply->error() != QNetworkReply::NoError) {
                                emit exportFinished(false, "Database insert failed: " + createReply->errorString());
                                return;
                            }

                            // Clean up local temp files now that everything succeeded
                            QFile::remove(localJsonPath);
                            QFile::remove(localImagePath);
                            QDir(tempDir).rmdir(tempDir);   // only removes if now empty

                            emit exportFinished(true, "Track uploaded successfully");
                        });
                    });
            });
    });
}
