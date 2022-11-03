import QtQuick 2.15
import QtQuick.Controls 2.15

Slider {
    id: control
    value: 0.5

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 4
        width: control.availableWidth
        height: implicitHeight
        radius: 2
        color: "#202020"

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            color: "#424242"
            radius: 2
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 15
        implicitHeight: 23
        radius: 1
        color: control.pressed ? "#c5c5c5" : "#606060"
    }
}