import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.12

Menu {
    readonly property real menuItemSize: 20
    topPadding: 2
    bottomPadding: 2
    delegate: MenuItem {
        id: menuItem
        implicitWidth: 200
        implicitHeight: menuItemSize
        hoverEnabled: true

        contentItem: Item {
            implicitWidth: 200
            implicitHeight: menuItemSize
            Text {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                leftPadding: menuItem.checkable ? menuItem.indicator.width : 6
                text: menuItem.text
                font: menuItem.font
                opacity: enabled ? 1.0 : 0.3
                color: menuItem.hovered ? "#eee" : "#fff"
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                text: ""
                font: menuItem.font
                opacity: enabled ? 1.0 : 0.3
                color: menuItem.hovered ? "#999" : "#aaa"
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }
        }

        background: Rectangle {
            implicitWidth: 200
            implicitHeight: menuItemSize
            opacity: enabled ? 1 : 0.3
            color: menuItem.hovered ? "#404040" : "transparent"
        }

        arrow: Canvas {
            x: parent.width - width
            implicitWidth: 20
            implicitHeight: 20
            visible: menuItem.subMenu
            onPaint: {
                var ctx = getContext("2d")
                ctx.fillStyle = menuItem.highlighted ? "#ffffff" : "#aaa"
                ctx.moveTo(5, 5)
                ctx.lineTo(width - 5, height / 2)
                ctx.lineTo(5, height - 5)
                ctx.closePath()
                ctx.fill()
            }
        }

        indicator: Item {
            implicitWidth: 20
            implicitHeight: 20
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
    }

    background: Item {
        implicitWidth: 200
        implicitHeight: menuItemSize
        
        Rectangle {
            id: bg
            anchors.fill: parent
            color: "#383838"
            radius: 0
        }

        DropShadow {
            anchors.fill: bg
            horizontalOffset: 3
            verticalOffset: 3
            radius: 8.0
            samples: 17
            color: "#80000000"
            source: bg
        }
    }
}