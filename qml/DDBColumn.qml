import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    
    signal tagAdded()
    signal tagDeleted()

    function selectUp() {
        ddbTagsList.selectUp()
    }

    function selectDown() {
        ddbTagsList.selectDown()
    }

    function selectEnter() {
        ddbTagsList.selectEnter()
    }

    Rectangle {
        id: ddbLabel
        color: "#303030"
        anchors.top: parent.top
        height: 30
        anchors.left: parent.left
        anchors.right: parent.right
        Text {
            text: "DeepDanbooru"
            font.pixelSize: 15
            leftPadding: 8
            rightPadding: 16
            font.bold: false
            color: "white"
            verticalAlignment: Text.AlignVCenter
            width: Math.min(parent.width, implicitWidth)
            elide: Text.ElideRight
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }
    }

    Rectangle {
        id: ddbTags
        color: "#202020"
        anchors.top: ddbLabel.bottom
        anchors.bottom: parent.bottom
        anchors.left: ddbLabel.left
        anchors.right: ddbLabel.right
        clip: true

        Tags {
            id: ddbTagsList
            index: 5
            model: backend.ddb
            anchors.fill: parent

            function getOverlay(tag, index, model) {
                return backend.tags.includes(tag) ? "#77000000" : "#00000000"
            } 

            onDoublePressed: {
                if(!backend.tags.includes(tag)) {
                    backend.addTag(tag)
                    root.tagAdded()
                } else {
                    backend.deleteTagByName(tag)
                    root.tagDeleted()
                }
            }

            onMoved: {

            }

            onModelChanged: {
                populate()
            }
        }
    }

    Rectangle {
        id: ddbControls
        color: "#303030"
        height: 30
        anchors.bottom: parent.bottom
        anchors.left: ddbLabel.left
        anchors.right: ddbLabel.right

        DDBButton {
            anchors.left: parent.left
            anchors.top: parent.top
            height: parent.height
            width: height
        }
    }
}