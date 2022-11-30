import QtQuick 2.12
import QtQuick.Controls 2.12
import QtGraphicalEffects 1.15

Menu {
    readonly property real menuItemSize: 20
    topPadding: 2
    bottomPadding: 2

    delegate: MenuItem {
        id: menuItem
        implicitWidth: 150
        implicitHeight: menuItemSize
        hoverEnabled: true
        //font.bold: true
        font.pointSize: 10.5

        indicator: Item {
            implicitWidth: menuItemSize
            implicitHeight: menuItemSize
            Rectangle {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 6
                visible: menuItem.checkable
                radius: 3
                color: "#606060"

                border.color: "#505050"
                border.width: 3

                Image {
                    id: img
                    width: 16
                    height: 16
                    visible:  menuItem.checked
                    anchors.centerIn: parent
                    source: "qrc:/icons/tick.svg"
                    sourceSize: Qt.size(parent.width, parent.height)
                }

                ColorOverlay {
                    id: color
                    visible:  menuItem.checked
                    anchors.fill: img
                    source: img
                    color: "#eee"
                }
            }
        }

        contentItem: UniformText {
            leftPadding: menuItem.checkable ? menuItem.indicator.width : 0
            text: menuItem.text
            font: menuItem.font
            color: "white"
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            implicitWidth: 150
            implicitHeight: menuItemSize
            color: menuItem.hovered ? "#505050" : "transparent"
        }
    }



    background: RectangularGlow {
        implicitWidth: 150
        implicitHeight: menuItemSize
        glowRadius: 5
        //spread: 0.2
        color: "black"
        cornerRadius: 10

        Rectangle {
            anchors.fill: parent
            color: "#404040"
        }

    }
}
