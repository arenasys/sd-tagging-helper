import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import QtGraphicalEffects 1.15

Popup {
    id: popup
    parent: Overlay.overlay
    modal: true

    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: parent.width - 100
    height: parent.height - 100
    padding: 0

    background: Rectangle {
        color: "#303030"
    }

    property var header: headerBar
    property var title: "Title"
    property var titleIcon: "qrc:/icons/settings.svg"

    Rectangle {
        id: headerBar
        color: "#202020"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        Image {
            id: img
            source: titleIcon
            width: parent.height - 4
            height: width
            sourceSize: Qt.size(width, height)
            x: (title.width - title.contentWidth) / 2 - width - 5
            y: 2

        }
        ColorOverlay {
            anchors.fill: img
            source: img
            color: "#606060"
        }

        Image {
            id: close
            source: "qrc:/icons/cross.svg"
            width: 20
            height: width
            sourceSize: Qt.size(width, height)
            x: parent.width - width - (parent.height - height)/2
            anchors.verticalCenter: parent.verticalCenter
            ColorOverlay {
                anchors.fill: parent
                source: parent
                color: mouse.containsMouse ? "white" : "#606060"
            }
            MouseArea {
                id: mouse
                hoverEnabled: true
                anchors.fill: parent
                onPressed: {
                    popup.close()
                }
            }
        }


        Text {
            id: title
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: popup.title
            font.pixelSize: 16
            font.bold: true
            leftPadding: 4
            color: "#707070"
            elide: Text.ElideRight
            height: parent.height
            anchors.right: parent.right
            anchors.left: parent.left
        }
        height: 30
        width: parent.width
    }

    onOpened: {
        forceActiveFocus()
    }
}
