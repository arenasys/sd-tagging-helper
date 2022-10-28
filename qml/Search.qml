import QtQuick 2.15

Item {
    id: container
    property alias text: search.text
    property bool hasFocus: search.activeFocus
    signal focusReleased()

    signal enter()

    clip: true

    function clear() {
        search.text = ""
        doSearch(search.text)
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        color: "#303030"
        clip: true
    }

    TextInput {
        id: search
        color: "white"
        font.bold: false
        font.pointSize: 12
        selectByMouse: true
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        verticalAlignment: Text.AlignVCenter
        leftPadding: 8
        topPadding: 1
        onAccepted: {
            if(activeFocus) {
                backend.doSearch(search.text)
                focusReleased()
            }
        }

        Keys.onPressed: {
            if(event.key === Qt.Key_Escape) {
                event.accepted = true
                focusReleased()
            }
            if(event.key === Qt.Key_Enter) {
                event.accepted = true
                if(search.text != "") {
                    enter()
                }
            }
        }

        Text {
            text: "Search..."
            anchors.fill: search
            verticalAlignment: Text.AlignVCenter
            font.bold: false
            font.pointSize: 12
            leftPadding: 8
            topPadding: 1
            color: "#aaa"
            visible: !search.text && !search.activeFocus
        }
    }

    Keys.forwardTo: [search]
}