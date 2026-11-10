import QtQuick
import QtQuick.Controls
import Conestructor

ApplicationWindow {
    id: window
    width: 1600
    height: 960
    visible: true
    title: "Conestructor " + AppInfo.shortVersion + " — Untitled"
    color: "#1f1f1f"

    Label {
        anchors.centerIn: parent
        text: qsTr("The new canvas arrives in the next tasks.")
        color: "#d0d0d0"
    }
}
