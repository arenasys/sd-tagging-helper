import QtQuick 2.15

Item {
    id: root
    property alias text: search.text
    property bool hasFocus: search.activeFocus

    signal focusRelease()
    signal enter()
    signal up()
    signal down()

    clip: true

    function clear() {
        search.clear()
    }

    function gainFocus() {
        search.forceActiveFocus()
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

        Keys.onPressed: {
            switch(event.key) {
            case Qt.Key_Enter:
            case Qt.Key_Return:
                root.enter()
                event.accepted = true
                break;
            case Qt.Key_Escape:
                root.focusRelease()
                event.accepted = true
                break;
            case Qt.Key_Up:
                root.up()
                event.accepted = true
                break;
            case Qt.Key_Down:
                root.down()
                event.accepted = true
                break;
            case Qt.Key_Tab:
                event.accepted = true
                if(event.modifiers & Qt.ControlModifier) {
                    backend.doListEvent(-2)
                } else {
                    backend.doListEvent(2)
                }
                root.focusRelease()
                break;
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

    Keys.onPressed: {
        
    }
}