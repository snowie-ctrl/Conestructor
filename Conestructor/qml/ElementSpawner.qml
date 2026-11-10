import QtQuick 2.15
import QtQuick.Controls

import Conestructor


Rectangle {
    id: root

    property Component shapeComponent: null
    property int defaultShapeAngle: -15 // Angle the shape spawns at (for preview purposes)
    property Item currentInstance: null

    color: "#303030"

    Item {
        id: shapeHolder

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: spawnerLabel.top

        clip: true

        Item {
            id: shapeCenter
            anchors.centerIn: parent
            width: 1
            height: 1
        }
    }

    Label {
        id: spawnerLabel

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        height: 50

        text: root.currentInstance
            ? root.currentInstance.shapeName
            : ""
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }


    Component.onCompleted: {
        root.trySpawn() // Initial spawn
    }


    function trySpawn() {
        if (!root.shapeComponent) return

        if (root.shapeComponent.status === Component.Error) console.warn("Spawner: Component error:", root.shapeComponent.errorString())

        if (root.shapeComponent.status !== Component.Ready) return


        root.spawnShape()
    }

    function spawnShape() {
        if (!root.shapeComponent || root.currentInstance) return

        var instance = root.shapeComponent.createObject(
            shapeCenter,
            { // property assignments go here in hash fashion

            }
        )

        if (!instance) {
            console.warn("ElementSpawner: failed to create new instance")
            return
        }

        instance.elementRotation = root.defaultShapeAngle
        root.currentInstance = instance

        root.fitPreview(instance)

        instance.dragStarted.connect( // On drag, sever link between spawner and instance
            function() {
                if (root.currentInstance !== instance) return

                root.currentInstance = null

                root.spawnShape() // Spawn new shape once old ones link been severed
            }
        )
    }

    function fitPreview(instance) {
        if (instance.width <= 0 || instance.height <= 0) return

        var padding = 0.85

        shapeCenter.scale = Math.min(
            shapeHolder.width / instance.width,
            shapeHolder.height / instance.height
            ) * padding
    }
}


