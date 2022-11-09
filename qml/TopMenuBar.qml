import QtQuick 2.15
import QtQuick.Controls 2.15

MenuBar {
    readonly property real menuBarSize: 20
    height: menuBarSize
    contentHeight: menuBarSize

    delegate: MenuBarItem {
            id: menuBarItem
            implicitHeight: menuBarSize
            hoverEnabled: true
            contentItem: Text {
                text: menuBarItem.text
                font: menuBarItem.font
                opacity: enabled ? 1.0 : 0.3
                color: menuBarItem.hovered  ? "#aaa" : "#fff"
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                implicitWidth: menuBarSize
                implicitHeight: menuBarSize
                opacity: enabled ? 1 : 0.3
                color: menuBarItem.hovered ?  "#505050" : "transparent"
            }
    }

    background: Rectangle {
        implicitWidth: menuBarSize
        implicitHeight: menuBarSize
        color: "#404040"
    }
}