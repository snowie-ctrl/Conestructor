import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Conestructor
import "logic/units.mjs" as Units

// Edit > Preferences: Units, Cones (the cones the team owns), Car (the outline's size and picture) and Team (the team code), in one scrolling column.
Dialog {
    id: dialog
    objectName: "preferencesDialog"
    title: qsTr("Preferences")
    modal: true
    standardButtons: Dialog.Close
    anchors.centerIn: parent

    // Whether the car picture's file is there: checked when the dialog opens and when the picture changes.
    property bool imageFound: false
    // Shown above the Team section when File › Open from team or Upload to team opened the dialog without a code.
    property string teamHint: ""
    property bool badCode: false
    property bool checking: false
    property string checkResult: ""
    property bool checkOk: false
    onAboutToShow: {
        imageFound = Settings.carImageFound()
        codeField.text = Settings.teamCode
        badCode = false
        checkResult = ""
    }
    onClosed: teamHint = ""

    // Opens at the Team section with `hint` above it.
    function openAtTeam(hint) {
        teamHint = hint
        open()
        Qt.callLater(() => {
            const flick = scroll.contentItem
            flick.contentY = Math.max(0, Math.min(teamHeader.y, column.height - flick.height))
        })
    }

    // A code is saved only when it is one; a blank field saves nothing (Clear removes the code).
    function codeTyped(text) {
        checkResult = ""
        if (text.trim() === "") {
            badCode = false
            return
        }
        badCode = !TeamServer.isCode(text)
        if (!badCode)
            Settings.teamCode = text.trim()
    }

    function clearCode() {
        codeField.text = ""
        badCode = false
        checkResult = ""
        Settings.teamCode = ""
    }

    function checkCode() {
        checking = true
        checkOk = false
        checkResult = qsTr("Checking…")
        TeamServer.check()
    }

    Connections {
        target: TeamServer
        function onChecked(ok, message) {
            dialog.checking = false
            dialog.checkOk = ok
            dialog.checkResult = message
        }
    }
    Connections {
        target: Settings
        function onCarImageChanged() { dialog.imageFound = Settings.carImageFound() }
    }

    ScrollView {
        id: scroll
        implicitWidth: 360
        implicitHeight: Math.min(column.implicitHeight, 560)
        contentWidth: availableWidth

        ColumnLayout {
            id: column
            width: scroll.availableWidth
            spacing: 6

            Label {
                text: qsTr("Units")
                font.bold: true
            }
            Label {
                text: qsTr("How lengths are shown and typed. Files always store metres.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: "#b0b0b0"
            }
            ButtonGroup { id: unitGroup }
            Repeater {
                model: Units.UNITS
                RadioButton {
                    required property string modelData
                    text: Units.LABELS[modelData]
                    ButtonGroup.group: unitGroup
                    checked: Settings.units === modelData
                    onToggled: if (checked) Settings.units = modelData
                }
            }

            Label {
                Layout.topMargin: 12
                text: qsTr("Cones")
                font.bold: true
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("Cones we own")
                    color: "#e0e0e0"
                    Layout.preferredWidth: 104
                }
                TextField {
                    objectName: "conesOwnedField"
                    Layout.fillWidth: true
                    validator: IntValidator { bottom: 0; top: 9999 }
                    placeholderText: qsTr("No budget")
                    text: Settings.conesOwned > 0 ? String(Settings.conesOwned) : ""
                    onTextEdited: Settings.conesOwned = text === "" ? 0 : Number(text)
                }
            }
            Label {
                text: qsTr("The status bar shows the track's cones against this, in red when it needs more.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: "#b0b0b0"
            }

            Label {
                Layout.topMargin: 12
                text: qsTr("Car")
                font.bold: true
            }
            Label {
                text: qsTr("Tools › Car outline shows a car this size on the canvas.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: "#b0b0b0"
            }
            PropField {
                def: ({ key: "carLength", label: qsTr("Length"), kind: "length", min: 0.5, max: 10 })
                value: Settings.carLength
                onEdited: (v) => Settings.carLength = v
            }
            PropField {
                def: ({ key: "carWidth", label: qsTr("Width"), kind: "length", min: 0.5, max: 10 })
                value: Settings.carWidth
                onEdited: (v) => Settings.carWidth = v
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("Top-down image")
                    color: "#e0e0e0"
                    Layout.preferredWidth: 104
                }
                Label {
                    objectName: "carImageName"
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: Settings.carImage === "" ? qsTr("None")
                          : !dialog.imageFound ? qsTr("Image not found")
                          : Settings.carImage.split(/[\\/]/).pop()
                    color: Settings.carImage !== "" && !dialog.imageFound ? "#ffb74d" : "#e0e0e0"
                }
            }
            RowLayout {
                Button {
                    text: qsTr("Choose…")
                    onClicked: carImageDialog.open()
                }
                Button {
                    text: qsTr("Clear")
                    enabled: Settings.carImage !== ""
                    onClicked: Settings.carImage = ""
                }
            }
            Label {
                id: teamHeader
                Layout.topMargin: 12
                text: qsTr("Team")
                font.bold: true
            }
            Label {
                objectName: "teamHint"
                visible: dialog.teamHint !== ""
                text: dialog.teamHint
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: "#ffb74d"
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("Team code")
                    color: "#e0e0e0"
                    Layout.preferredWidth: 104
                }
                TextField {
                    id: codeField
                    objectName: "teamCodeField"
                    Layout.fillWidth: true
                    echoMode: showCode.checked ? TextInput.Normal : TextInput.Password
                    placeholderText: qsTr("Paste the team code")
                    onTextEdited: dialog.codeTyped(text)
                }
            }
            Label {
                objectName: "teamCodeNote"
                visible: dialog.badCode
                text: qsTr("Not a team code")
                color: "#ff6b6b"
            }
            RowLayout {
                CheckBox {
                    id: showCode
                    objectName: "teamShowCode"
                    text: qsTr("Show")
                }
                Button {
                    objectName: "teamCheckButton"
                    text: qsTr("Check")
                    enabled: TeamServer.hasCode && !dialog.checking
                    onClicked: dialog.checkCode()
                }
                Button {
                    objectName: "teamClearButton"
                    text: qsTr("Clear")
                    enabled: Settings.teamCode !== "" || codeField.text !== ""
                    onClicked: dialog.clearCode()
                }
            }
            Label {
                objectName: "teamCheckResult"
                visible: text !== ""
                text: dialog.checkResult
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: dialog.checkOk ? "#81c784" : "#ffb74d"
            }
            Label {
                text: qsTr("Treat the team code like a password: it opens your team's tracks.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: "#b0b0b0"
            }
        }
    }

    FileDialog {
        id: carImageDialog
        title: qsTr("Top-down car image")
        nameFilters: [qsTr("Photos (*.png *.jpg *.jpeg)")]
        onAccepted: Settings.carImage = TrackFile.toLocalPath(selectedFile)
    }
}
