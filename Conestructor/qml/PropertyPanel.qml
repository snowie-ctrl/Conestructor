import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

import Conestructor


Rectangle {
    id: root
    color: AppState.backgroundColor

    Component.onCompleted: AppState.propertyPanel = root

    property var propertyNames: []        // stable field list, only changes on new selection
    property var currentProperties: ({})  // live values, may update frequently during drag

    Connections {
        target: AppState
        function onSelectionChanged(element) {
            root.refreshProperties()
        }
    }

    Connections {
        target: AppState.selectedElement
        enabled: AppState.selectedElement !== null
        function onPropertiesChanged(properties) {
            root.currentProperties = properties
            root.updateFieldsFromCurrentProperties(false)
        }
    }

    function refreshProperties() {
        var element = AppState.selectedElement
        if (!element) {
            root.propertyNames = []
            root.currentProperties = {}
            return
        }
        var props = element.getEditableProperties()
        root.currentProperties = props
        root.propertyNames = Object.keys(props)
        root.updateFieldsFromCurrentProperties(true)   // force overwrite, ignore focus
    }

    function updateFieldsFromCurrentProperties(forceOverwrite) {
        for (var i = 0; i < propertyRepeater.count; i++) {
            var item = propertyRepeater.itemAt(i)
            if (!item) continue
            if (!forceOverwrite && item.fieldHasFocus) continue
            var newValue = root.currentProperties[item.propertyName]
            if (newValue !== undefined) {
                item.fieldText = String(newValue)
            }
        }
    }

    function applyChanges() {
        var element = AppState.selectedElement
        if (!element) return

        var newValues = {}
        for (var i = 0; i < propertyRepeater.count; i++) {
            var item = propertyRepeater.itemAt(i)
            var rawValue = item.fieldText
            newValues[item.propertyName] = (rawValue !== "" && !isNaN(rawValue))
                ? Number(rawValue)
                : rawValue
        }
        element.applyProperties(newValues)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Label {
            text: AppState.selectedElement ? AppState.selectedElement.shapeName : ""
            font.bold: true
            font.pointSize: 14
            color: "#FFFFFF"
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                id: propertyRepeater

                model: root.propertyNames

                delegate: ColumnLayout {
                    id: fieldContainer

                    property string propertyName: modelData
                    property alias fieldText: valueField.text
                    property bool fieldHasFocus: valueField.activeFocus

                    Layout.fillWidth: true

                    spacing: 6


                    RowLayout {
                        Layout.fillWidth: true

                        spacing: 8

                        Label {
                            text: fieldContainer.propertyName

                            color: "#FFFFFF"

                            Layout.preferredWidth: 110
                        }

                        TextField {
                            id: valueField

                            Layout.fillWidth: true

                            Component.onCompleted: {
                                var initial =
                                    root.currentProperties[
                                        fieldContainer.propertyName
                                    ]

                                text =
                                    initial !== undefined
                                    ? String(initial)
                                    : ""
                            }
                        }
                    }

                    Item {
                        visible: index === 2

                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Button {
            text: "Apply"
            contentItem: Text {
                text: parent.text
                color: "#000000"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Layout.fillWidth: true
            onClicked: root.applyChanges()
        }
    }
}
