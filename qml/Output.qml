import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.12

Rectangle {
    id: output
    color: "#161616"

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: previewDivider.top
        CenteredImage {
            id: preview
            anchors.centerIn: parent
            asynchronous: false
            source: backend.preview
            maxWidth: parent.width
            maxHeight: parent.height
            fill: true

            onStatusChanged: {
                if(status == Image.Ready) {
                    preview.sync()
                }
            }
        }
    }

    Rectangle {
        id: previewDivider
        height: 5
        color: "#404040"
        clip: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: promptBox.top
    }

    Rectangle {
        id: promptBox
        color: "#202020"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        
        height: parent.height * (1/3)

        clip: true

        Flickable {
            id: flick
            anchors.fill: parent
            contentHeight: text.height

            interactive: false

            ScrollBar.vertical: ScrollBar {
                id: scrollBar
            }
        
            TextEdit {
                id: text
                readOnly: true
                wrapMode: Text.WordWrap
                width: parent.width
                selectByMouse: true

                leftPadding: 8
                topPadding: 8
                bottomPadding: 8
                rightPadding: 8

                color: "#ccc"
                text: backend.prompt
            }
        }
    }

}