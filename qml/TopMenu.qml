import QtQuick 2.15
import QtQuick.Controls 2.15

Menu {
    readonly property real menuItemSize: 20
    topPadding: 2
    bottomPadding: 2
    delegate: MenuItem {
        id: menuItem
        implicitWidth: 200
        implicitHeight: menuItemSize
        hoverEnabled: true

        contentItem: Text {
            text: menuItem.text
            font: menuItem.font
            opacity: enabled ? 1.0 : 0.3
            color: menuItem.hovered ? "#aaa" : "#fff"
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            implicitWidth: 200
            implicitHeight: menuItemSize
            opacity: enabled ? 1 : 0.3
            color: menuItem.hovered ? "#505050" : "transparent"
        }
    }

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: menuItemSize
        color: "#404040"
        radius: 0
    }
}