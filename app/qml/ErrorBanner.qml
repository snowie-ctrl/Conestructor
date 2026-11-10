import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A problem over the canvas, with "Show me" when there is something to pan to.
Rectangle {
    id: banner

    property string text: ""
    property var target: null
    signal showMe(var target)

    function show(message, target) {
        banner.text = message
        banner.target = target || null
    }
    function hide() {
        banner.text = ""
        banner.target = null
    }

    visible: text !== ""
    width: Math.min(parent ? parent.width - 32 : 640, row.implicitWidth + 24)
    height: row.implicitHeight + 16
    radius: 6
    color: "#8c1d18"
    border.color: "#ff8a80"

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 8
        spacing: 12

        Label {
            Layout.fillWidth: true
            text: banner.text
            color: "#ffffff"
            wrapMode: Text.WordWrap
        }
        Button {
            text: qsTr("Show me")
            visible: banner.target !== null
            onClicked: banner.showMe(banner.target)
        }
        ToolButton {
            text: "✕"
            onClicked: banner.hide()
        }
    }
}
