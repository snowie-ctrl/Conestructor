import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts


Rectangle {
    id: root

    property Item canvas: null

    //anchors.fill: parent
    color: "#1f1f1f"

    property int itemSpacing: 5


    Column {
        anchors.fill: parent

        GridLayout {
            id: grid
            width: parent.width

            columns: 2
            rows: 3

            anchors.horizontalCenter: parent.horizontalCenter

            columnSpacing: root.itemSpacing
            rowSpacing: root.itemSpacing


                // Ruler spawner
            ElementSpawner {
                Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                Layout.preferredHeight: width

                shapeComponent: Qt.createComponent("elements/Ruler.qml")
                canvasRef: root.canvas
            }

                // Target spawner
            ElementSpawner {
                Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                Layout.preferredHeight: width

                shapeComponent: Qt.createComponent("elements/Target.qml")
                canvasRef: root.canvas
            }

                // Chicane spawner
            ElementSpawner {
                Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                Layout.preferredHeight: width

                shapeComponent: Qt.createComponent("elements/Chicane.qml")
                canvasRef: root.canvas
            }

                // Hairpin spawner
            ElementSpawner {
                Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                Layout.preferredHeight: width

                shapeComponent: Qt.createComponent("elements/Hairpin.qml")
                canvasRef: root.canvas
            }

                // Slalom spawner
            ElementSpawner {
                Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                Layout.preferredHeight: width

                shapeComponent: Qt.createComponent("elements/Slalom.qml")
                canvasRef: root.canvas
            }

                // Straight spawner
            ElementSpawner {
                Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                Layout.preferredHeight: width

                shapeComponent: Qt.createComponent("elements/Straight.qml")
                canvasRef: root.canvas
            }
        }
        Item { Layout.fillHeight: true }
    }
}
