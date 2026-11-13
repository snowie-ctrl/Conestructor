import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor

// File › Open from team: the team's tracks, newest first, each with its thumbnail, name, cone count and upload time.
// Open (or a double-click) downloads the chosen one; Main opens it with no file. Closing the dialog stops a download.
Dialog {
    id: dialog
    objectName: "teamTracksDialog"
    title: qsTr("Team tracks: %1").arg(TeamServer.teamName)
    modal: true
    focus: true
    implicitWidth: 560      // fixed: Fusion's Dialog sizing loops with a custom button box
    anchors.centerIn: Overlay.overlay

    // A downloaded track (TeamServer.downloaded's `read`) to open under its name.
    signal openTrack(var read, string name)

    property string statusText: ""      // "Connecting…", an error, the empty-team line, or "" once listed
    property bool downloading: false
    property string downloadName: ""
    property var thumbs: ({})           // track id → thumbnail URL, for this session

    ListModel { id: tracksModel }

    function openList() {
        open()
        refresh()
    }

    function refresh() {
        tracksModel.clear()
        list.currentIndex = -1
        statusText = qsTr("Connecting…")
        TeamServer.listTracks()
    }

    function openChosen() {
        if (downloading || list.currentIndex < 0)
            return
        const chosen = tracksModel.get(list.currentIndex)
        downloadName = chosen.name
        downloading = true
        progress.value = 0
        statusText = ""
        TeamServer.download(chosen.trackId)
    }

    onClosed: {
        if (downloading) {
            downloading = false
            TeamServer.cancel()
        }
    }

    Connections {
        target: TeamServer
        function onTracksListed(ok, tracks, error) {
            if (!dialog.visible)
                return
            tracksModel.clear()
            if (!ok) {
                dialog.statusText = error
                return
            }
            for (const t of tracks) {
                tracksModel.append({ trackId: t.id, name: t.name, cones: t.cones, uploadedText: t.uploadedText })
                if (dialog.thumbs[t.id] === undefined)
                    TeamServer.fetchThumbnail(t.id)
            }
            dialog.statusText = tracks.length === 0
                ? qsTr("No tracks on the team yet. File › Upload to team shares the open track.") : ""
            list.currentIndex = tracks.length > 0 ? 0 : -1
        }
        function onThumbnailReady(id, url) {
            const next = Object.assign({}, dialog.thumbs)
            next[id] = url.toString()
            dialog.thumbs = next
        }
        function onDownloadProgress(received, total) {
            progress.value = total > 0 ? received / total : 0
        }
        function onDownloaded(ok, read, error) {
            if (!dialog.downloading)
                return                  // closed meanwhile: nothing opens
            dialog.downloading = false
            if (!ok) {
                dialog.statusText = error
                return
            }
            dialog.close()
            dialog.openTrack(read, dialog.downloadName)
        }
    }

    ColumnLayout {
        width: dialog.availableWidth
        spacing: 8

        Label {
            objectName: "teamTracksStatus"
            visible: text !== ""
            text: dialog.statusText
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: "#e0e0e0"
        }

        ListView {
            id: list
            objectName: "teamTrackList"
            Layout.fillWidth: true
            Layout.preferredHeight: 380
            clip: true
            model: tracksModel
            delegate: ItemDelegate {
                id: row
                required property int index
                required property int trackId
                required property string name
                required property int cones
                required property string uploadedText
                width: ListView.view.width
                height: 76
                highlighted: ListView.isCurrentItem
                onClicked: list.currentIndex = index
                onDoubleClicked: {
                    list.currentIndex = index
                    dialog.openChosen()
                }
                contentItem: RowLayout {
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 64
                        color: "#1b1b1b"
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            source: dialog.thumbs[row.trackId] || ""
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: row.name
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: qsTr("%1 cones · %2").arg(row.cones).arg(row.uploadedText)
                            color: "#b0b0b0"
                        }
                    }
                }
            }
        }

        RowLayout {
            visible: dialog.downloading
            Layout.fillWidth: true
            Label { text: qsTr("Downloading %1").arg(dialog.downloadName) }
            ProgressBar {
                id: progress
                objectName: "teamDownloadProgress"
                Layout.fillWidth: true
            }
        }
    }

    footer: DialogButtonBox {
        Button {
            objectName: "teamRefreshButton"
            text: qsTr("Refresh")
            enabled: !dialog.downloading
            DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            onClicked: dialog.refresh()
        }
        Button {
            objectName: "teamOpenButton"
            text: qsTr("Open")
            enabled: list.currentIndex >= 0 && !dialog.downloading
            DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            onClicked: dialog.openChosen()
        }
        Button {
            text: qsTr("Cancel")
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
    }
}
