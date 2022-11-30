import QtQuick 2.15
import QtQuick.Controls 2.15

MenuBar {
    readonly property real menuBarHeight: 20
    readonly property real menuBarWidth: 50
    height: menuBarHeight
    contentHeight: menuBarHeight

    delegate: MenuBarItem {
            id: menuBarItem
            implicitHeight: menuBarHeight
            implicitWidth: menuBarWidth
            hoverEnabled: true
            contentItem: Item {

            }

            background: Rectangle {
                UniformText {
                    text: menuBarItem.text
                    opacity: enabled ? 1.0 : 0.3
                    color: menuBarItem.hovered  ? "#aaa" : "#fff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    anchors.fill: parent
                }

                implicitWidth: menuBarWidth
                implicitHeight: menuBarHeight
                opacity: enabled ? 1 : 0.3
                color: menuBarItem.hovered ?  "#505050" : "transparent"
            }
    }

    background: Rectangle {
        implicitHeight: menuBarHeight
        color: "#404040"
    }
}