import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts


Rectangle {
    id: root


    property Item selectedElement:
        null


    property var properties:
        ({ })


    property var editedProperties:
        ({ })


    color:
        "#303030"


    function loadProperties(
        newProperties
    ) {


        root.properties =
            newProperties


        root.editedProperties =
            Object.assign(
                {},
                newProperties
            )
    }


    ColumnLayout {

        anchors.fill:
            parent


        anchors.margins:
            12


        spacing:
            10


        Label {

            Layout.fillWidth:
                true


            text:
                root.selectedElement
                ? root.selectedElement.shapeName
                : "No Element Selected"


            font.bold:
                true


            font.pixelSize:
                18
        }


        ScrollView {

            Layout.fillWidth:
                true


            Layout.fillHeight:
                true


            clip:
                true


            ColumnLayout {

                width:
                    parent.width


                spacing:
                    8


                Repeater {

                    model:
                        Object.keys(
                            root.editedProperties
                        )


                    delegate:
                        RowLayout {


                        Layout.fillWidth:
                            true


                        spacing:
                            8


                        Label {

                            Layout.preferredWidth:
                                110


                            text:
                                modelData
                        }


                        TextField {

                            Layout.fillWidth:
                                true


                            text:
                                root.editedProperties[
                                    modelData
                                ]


                            selectByMouse:
                                true


                            onTextChanged: {


                                var updated =
                                    Object.assign(
                                        {},
                                        root.editedProperties
                                    )


                                updated[
                                    modelData
                                ] =
                                    text


                                root.editedProperties =
                                    updated
                            }
                        }
                    }
                }
            }
        }


        RowLayout {

            Layout.fillWidth:
                true


            Button {

                Layout.fillWidth:
                    true


                text:
                    "Apply"


                onClicked: {


                    if (
                        !root.selectedElement
                    ) {

                        return
                    }


                    root.selectedElement.applyProperties(
                        root.editedProperties
                    )
                }
            }


            Button {

                Layout.fillWidth:
                    true


                text:
                    "Delete"
            }
        }
    }
}
