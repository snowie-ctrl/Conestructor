import QtQuick 2.15
import QtQuick.Controls


Rectangle {
    id: root


    property Component shapeComponent: null


    property Item canvasRef: null


    property int defaultAngle: 15


    property Item currentInstance: null


    color:
        "#303030"


    Item {
        id: shapeHolder


        anchors.left:
            parent.left


        anchors.right:
            parent.right


        anchors.top:
            parent.top


        anchors.bottom:
            spawnerLabel.top


        clip:
            true


        Item {
            id: shapeCenter


            anchors.centerIn:
                parent


            width:
                1


            height:
                1
        }
    }


    Label {
        id: spawnerLabel


        anchors.left:
            parent.left


        anchors.right:
            parent.right


        anchors.bottom:
            parent.bottom


        height:
            50


        text:
            root.currentInstance
            ? root.currentInstance.shapeName
            : ""
    }


    Component.onCompleted: {


        root.trySpawn()
    }


    function trySpawn() {


        if (
            !root.shapeComponent
        ) {


            console.warn(
                "ElementSpawner: no shapeComponent"
            )


            return
        }


        if (
            root.shapeComponent.status ===
            Component.Error
        ) {


            console.warn(
                "ElementSpawner:",
                root.shapeComponent.errorString()
            )


            return
        }


        if (
            root.shapeComponent.status !==
            Component.Ready
        ) {


            return
        }


        root.spawnShape()
    }


    function spawnShape() {


        if (
            !root.shapeComponent ||
            root.currentInstance
        ) {

            return
        }


        var instance =
            root.shapeComponent.createObject(
                shapeCenter,
                {
                    "canvasRef":
                        root.canvasRef,

                    "placed":
                        false
                }
            )


        if (!instance) {


            console.warn(
                "ElementSpawner: failed to create shape"
            )


            return
        }


        instance.rotation =
            root.defaultAngle


        root.currentInstance =
            instance


        root.fitPreview(
            instance
        )


        instance.dragStarted.connect(
            function() {


                if (
                    root.currentInstance !==
                    instance
                ) {

                    return
                }


                root.currentInstance =
                    null


                root.spawnShape()
            }
        )
    }


    function fitPreview(
        instance
    ) {


        if (
            instance.width <= 0 ||
            instance.height <= 0
        ) {

            return
        }


        var padding =
            0.85


        shapeCenter.scale =
            Math.min(
                shapeHolder.width /
                instance.width,

                shapeHolder.height /
                instance.height
            ) *
            padding
    }
}
