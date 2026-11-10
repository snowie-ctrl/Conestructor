import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

import Conestructor


Rectangle {
    id: root

    color: AppState.backgroundColor


    Component.onCompleted: AppState.elementPanel = root




    Column {
        anchors.fill: parent

        GridLayout {
            id: grid

            property int itemSpacing: 10

            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter

            columns: 2
            rows: 3

            columnSpacing: grid.itemSpacing
            rowSpacing: grid.itemSpacing


                // Ruler Spawner
            ElementSpawner {
                Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                Layout.preferredHeight: width

                shapeComponent: Qt.createComponent("elements/Ruler.qml")
            }

                // Target Spawner
            ElementSpawner {
                Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                Layout.preferredHeight: width

                shapeComponent: Qt.createComponent("elements/Target.qml")
            }

                // Chicane Spawner
            ElementSpawner {
                Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                Layout.preferredHeight: width

                shapeComponent: Qt.createComponent("elements/Chicane.qml")
            }

                // Slalom Spawner
            ElementSpawner {
                Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                Layout.preferredHeight: width

                shapeComponent: Qt.createComponent("elements/Slalom.qml")
            }

                // Hairpin Spawner
            ElementSpawner {
                Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                Layout.preferredHeight: width

                shapeComponent: Qt.createComponent("elements/Hairpin.qml")
            }

                // Straight Spawner
            ElementSpawner {
                Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                Layout.preferredHeight: width

                shapeComponent: Qt.createComponent("elements/Straight.qml")
            }
        }

        Item { Layout.fillHeight: true } // Push everything up
    }
}
