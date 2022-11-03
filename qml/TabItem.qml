import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

TabButton {
    id: control
    width: implicitWidth
    property var selected: false


    contentItem: Item {

    }

    background: Item {
        implicitHeight: 40
        implicitWidth: 100
        Rectangle {
            height: 25
            opacity: enabled ? 1 : 0.3
            color: control.down ? "#161616" : (selected ? "#404040" : "#202020")
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            clip:true
            Rectangle {
                rotation: 20
                width: parent.height
                height:  2*parent.height
                x: -width
                y: -parent.height
                transformOrigin: Item.BottomRight
                antialiasing: true
                color: "#303030"
            }

            Rectangle {
                rotation: -20
                width: parent.height
                height:  2*parent.height
                x: parent.width+2
                y: -parent.height
                transformOrigin: Item.BottomRight
                antialiasing: true
                color: "#303030"
            }

            Text {
                anchors.fill: parent
                topPadding: 2
                text: control.text
                font: control.font
                opacity: enabled ? 1.0 : 0.3
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:  Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }
}