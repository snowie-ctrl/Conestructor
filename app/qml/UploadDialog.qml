import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor

// File › Upload to team: shows the thumbnail and asks. The name starts as the track's (blank for an Untitled one) and
// changes only the uploaded copy. Upload shows progress; Cancel stops it; an error shows here and the dialog stays open.
Dialog {
    id: dialog
    objectName: "uploadDialog"
    title: qsTr("Upload to team")
    modal: true
    focus: true
    implicitWidth: 460      // fixed: Fusion's Dialog sizing loops with a custom button box
    anchors.centerIn: Overlay.overlay

    // Uploaded under this name.
    signal sent(string name)

    property url thumbnail: ""
    property int coneCount: 0
    property bool sending: false
    property string errorText: ""

    // `uploadResult`: the cones the upload carries (TrackStore.uploadResult).
    function ask(uploadResult) {
        coneCount = uploadResult.cones.length
        thumbnail = TeamServer.makeThumbnail(TrackStore.photoRef(), TrackStore.mpp, uploadResult.canvasCones)
        nameField.text = TrackStore.filePath === "" && !TrackStore.fromTeam ? "" : TrackStore.name
        errorText = ""
        progress.value = 0
        open()
        nameField.forceActiveFocus()
    }

    function send() {
        const name = nameField.text.trim()
        if (name === "" || sending)
            return
        sending = true
        errorText = ""
        TeamServer.upload(TrackStore.documentText(name), TrackStore.photoRef(), thumbnail)
    }

    onClosed: {
        if (sending) {
            sending = false
            TeamServer.cancel()
        }
    }

    Connections {
        target: TeamServer
        function onUploadProgress(done, total) {
            progress.value = total > 0 ? done / total : 0
        }
        function onUploaded(ok, error) {
            if (!dialog.sending)
                return
            dialog.sending = false
            if (ok) {
                const name = nameField.text.trim()
                dialog.close()
                dialog.sent(name)
            } else {
                dialog.errorText = error
            }
        }
    }

    ColumnLayout {
        width: dialog.availableWidth
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            color: "#1b1b1b"
            Image {
                objectName: "uploadThumbnail"
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                cache: false
                source: dialog.thumbnail
            }
        }
        TextField {
            id: nameField
            objectName: "uploadName"
            Layout.fillWidth: true
            placeholderText: qsTr("Name this track")
            enabled: !dialog.sending
            onAccepted: dialog.send()
        }
        Label {
            objectName: "uploadQuestion"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Upload %1 (%2 cones) to %3? Teammates will be able to open it.")
                  .arg(nameField.text.trim() !== "" ? nameField.text.trim() : qsTr("this track"))
                  .arg(dialog.coneCount).arg(TeamServer.teamName)
        }
        ProgressBar {
            id: progress
            objectName: "uploadProgress"
            visible: dialog.sending
            Layout.fillWidth: true
        }
        Label {
            objectName: "uploadError"
            visible: text !== ""
            text: dialog.errorText
            color: "#ff6b6b"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    footer: DialogButtonBox {
        Button {
            objectName: "uploadButton"
            text: qsTr("Upload")
            enabled: nameField.text.trim() !== "" && !dialog.sending
            DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            onClicked: dialog.send()
        }
        Button {
            text: qsTr("Cancel")
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
    }
}
