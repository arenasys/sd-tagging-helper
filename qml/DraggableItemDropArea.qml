import QtQuick 2.15

DropArea {
    id: root
    property int dropIndex

    Rectangle {
        id: dropIndicator
        anchors {
            left: parent.left
            right: parent.right
            top: dropIndex === 0 ? parent.verticalCenter : undefined
            bottom: dropIndex === 0 ? undefined : parent.verticalCenter
        }
        height: 2
        opacity: root.containsDrag ? 0.8 : 0.0
        color: "#606060"
    }
}