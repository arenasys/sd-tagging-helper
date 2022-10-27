import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    visible: true
    width: 1100
    height: 600
    title: backend.title
    id: root

    function save() {
        backend.applyCrop((media.x + media.fx)-crop.x, (media.y + media.fy)-crop.y, media.fw, media.fh, crop.width, crop.height)
        backend.saveMetadata()
        media.changed = false
    }

    function next() {
        backend.active += 1
    }

    function prev() {
        backend.active -= 1
    }

    function search(text) {
        backend.search(text)
    }

    Rectangle {
        id: view
        color: "#000000"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftDivider.right
        anchors.right: rightDivider.left

        onWidthChanged: {
            media.reset()
        }
        
        onHeightChanged: {
            media.reset()
        }
    }
    
    Media {
        id: media
        source: backend.source
        anchors.fill: crop
        default_ox: backend.offset_x
        default_oy: backend.offset_y
        default_s: backend.scale

        Component.onCompleted: {
            reset()
        }
    }

    Rectangle {
        id: crop
        color: "#00000000"
        border.width: 4
        border.color: media.changed ? "#aaff0000" : "#aa00ff00"
        anchors.centerIn: view
        width: Math.min(view.width, view.height)
        height: width
    }

    Rectangle {
        color: "#aa000000"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftDivider.right
        anchors.right: crop.left
    }
    Rectangle {
        color: "#aa000000"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: crop.right
        anchors.right: rightDivider.left
    }
    Rectangle {
        color: "#aa000000"
        anchors.top: parent.top
        anchors.bottom: crop.top
        anchors.left: leftDivider.right
        anchors.right: rightDivider.left
    }
    Rectangle {
        color: "#aa000000"
        anchors.top: crop.bottom
        anchors.bottom: parent.bottom
        anchors.left: leftDivider.right
        anchors.right: rightDivider.left
    }

    Search {
        id: searchBox
        anchors.top: parent.top
        height: 30
        anchors.left: parent.left
        anchors.right: leftDivider.left
        
        onFocusReleased: {
            keyboardFocus.forceActiveFocus()
        }

        onTextChanged: {
            search(searchBox.text)
        }
    }

    Rectangle {
        id: searchTags
        color: "#202020"
        anchors.top: searchBox.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: leftDivider.left
        clip: true

        Tags {
            id: searchTagsList
            model: backend.results
            anchors.fill: parent

            highlight: "green"

            function getOverlay(tag, index) {
                return backend.tags.includes(tag) ? "#66000000" : "#00000000"
            } 

            onDoublePressed: {
                backend.addTag(tag)
                currentTagsList.add(tag)
            }

            onModelChanged: {
                populate()
            }
        }
    }

    Rectangle {
        id: currentLabel
        color: "#303030"
        anchors.top: parent.top
        height: 30
        anchors.left: rightDivider.right
        anchors.right: parent.right
        Text {
            text: "Active Tags"
            font.pixelSize: 15
            leftPadding: 8
            rightPadding: 16
            font.bold: true
            color: "white"
            verticalAlignment: Text.AlignVCenter
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }
    }

    Rectangle {
        id: controls
        color: "#303030"
        height: 30
        anchors.bottom: parent.bottom
        anchors.left: rightDivider.right
        anchors.right: parent.right

        IconButton {
            height: controls.height
            anchors.left: controls.left
            anchors.top: controls.top
            width: height
            icon: "qrc:/icons/package.svg"
            tooltip: "package outputs"
            color: "#303030"
            working: packageWindow.visible
            onPressed: {
                packageWindow.open()
            }
        }

        Row {
            width: Math.min(parent.width, implicitWidth)
            anchors.right: parent.right
            IconButton {
                height: controls.height
                width: height
                icon: "qrc:/icons/save.svg"
                tooltip: "save metadata (f)"
                color: "#303030"
                iconColor: media.changed || backend.changed ? "#ba0000" : "green"
                onPressed: {
                    save()
                }
            }

            IconButton {
                height: controls.height
                width: height
                icon: "qrc:/icons/refresh.svg"
                tooltip: "reset image position (r)"
                color: "#303030"
                onPressed: {
                    media.reset()
                }
            }

            IconButton {
                height: controls.height
                width: height
                icon: "qrc:/icons/back.svg"
                tooltip: "previous image (left)"
                color: "#303030"
                onPressed: {
                    prev()
                }
            }

            IconButton {
                height: controls.height
                width: height
                icon: "qrc:/icons/next.svg"
                tooltip: "next image (right)"
                color: "#303030"
                onPressed: {
                    next()
                }
            }
        }
    }

    Rectangle {
        id: currentTags
        color: "#202020"
        anchors.top: currentLabel.bottom
        anchors.bottom: controls.top
        anchors.left: rightDivider.right
        anchors.right: parent.right
        clip: true

        Tags {
            id: currentTagsList
            active: backend.active
            model: backend.tags
            anchors.fill: parent
            highlight: "#ba0000"

            function getOverlay(tag, index) {
                return index == currentTagsList.selected ? "#22ffffff" : "#00000000"
            } 

            onDoublePressed: {
                currentTagsList.remove(index)
                backend.deleteTag(index)
            }
            
            onMoved: {
                backend.moveTag(from, to)
            }
        }

    }

    Rectangle {
        z:10
        id: leftDivider
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 5
        property int minX: 0
        property int maxX: Math.min(300, rightDivider.x-5)
        color: "#404040"

        Component.onCompleted: {
            x = 150
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: {
                if(pressedButtons) {
                    leftDivider.x = Math.min(leftDivider.maxX, Math.max(leftDivider.minX, leftDivider.x + mouseX))
                }
            }
        }

        onMaxXChanged: {
            leftDivider.x = Math.min(leftDivider.maxX, Math.max(leftDivider.minX, leftDivider.x))
        }
    }

    Rectangle {
        id: rightDivider
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 5
        property int minX: 5
        property int maxX: Math.min(300, parent.width-leftDivider.x)
        property int offset: 200
        x: parent.width - offset
        color: "#404040"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: {
                if(pressedButtons) {
                    rightDivider.offset = Math.min(rightDivider.maxX, Math.max(rightDivider.minX, root.width - (rightDivider.x + mouseX)))
                }
            }
        }

        onMaxXChanged: {
            if(parent.width > 0 && leftDivider.x > 0) //wait for the GUI to actually be constructed...
                rightDivider.offset = Math.min(rightDivider.maxX, Math.max(rightDivider.minX, rightDivider.offset))
        }

        Component.onCompleted: {
            offset = 200
        }
    }

    PopupWindow {
        id: packageWindow
        title: "Package"
        titleIcon: "qrc:/icons/package.svg"
        parent: Overlay.overlay
        modal: true
        closePolicy: Popup.CloseOnEscape

        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 280
        height: 160

        onOpened: {
            forceActiveFocus()
        }

        onClosed: {
            keyboardFocus.forceActiveFocus()
        }

        Text {
            id: modeLabel
            text: "Mode"
            font.pixelSize: 15
            x: 10
            y: packageWindow.header.height + 10
            height: 30
            leftPadding: 4
            rightPadding: 16
            font.bold: true
            color: "white"
            verticalAlignment: Text.AlignVCenter
        }

        Combo {
            id: mode
            font.pixelSize: 15
            anchors.top: modeLabel.top
            anchors.left: modeLabel.right
            currentIndex: 0
            width: 200
            height: 30
            model: ["Single Image", "Image/Prompt Pairs"]
        }

        Text {
            id: typeLabel
            text: "Type"
            font.pixelSize: 15
            anchors.left: modeLabel.left
            y: modeLabel.y + 40
            height: 30
            leftPadding: 4
            rightPadding: 16
            font.bold: true
            color: "white"
            verticalAlignment: Text.AlignVCenter
        }

        Combo {
            id: type
            font.pixelSize: 15
            anchors.top: typeLabel.top
            anchors.left: mode.left
            currentIndex: 0
            width: 200
            height: 30
            model: ["jpg", "png"]
        }

        IconButton {
            id: startButton
            y: typeLabel.y + 40
            anchors.left: parent.left
            anchors.right: progress.left
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            width: 30
            height: 30
            icon: "qrc:/icons/tick.svg"
            tooltip: "Start!"
            color: "#202020"
            onPressed: {
                backend.package(mode.currentIndex, type.currentIndex)
            }
        }

        Rectangle {
            id: progress
            anchors.top: startButton.top
            anchors.bottom: startButton.bottom
            x: startButton.x + 40
            anchors.left: mode.left
            anchors.right: mode.right
            height: 30
            color: "#202020"

            Rectangle {
                id: progressGreen
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * backend.workerProgress
                height: 30
                color: "green"
            }

            Text {
                id: progressLabel
                text:  backend.workerStatus
                font.pixelSize: 13
                anchors.fill: parent
                leftPadding: 4
                rightPadding: 16
                font.bold: true
                color: "white"
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }


    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: !keyboardFocus.hasFocus ? Qt.LeftButton : 0
        propagateComposedEvents: true
        onPressed: {
            keyboardFocus.forceActiveFocus()
            mouse.accepted = false
        }
    }

    Item {
        id: keyboardFocus
        focus: true
        anchors.fill: parent

        Keys.onPressed: {
            switch(event.key) {
            case Qt.Key_Escape:
                root.close()
                event.accepted = true
                break;
            case Qt.Key_Delete:
                backend.deleteTag(currentTagsList.selected)
                currentTagsList.active = ""
                event.accepted = true
                break;
            case Qt.Key_R:
                media.reset()
                event.accepted = true
                break;
            case Qt.Key_F:
                save()
                event.accepted = true
                break;
            case Qt.Key_N:
                backend.center()
                event.accepted = true
                break;
            case Qt.Key_M:
                backend.fill()
                event.accepted = true
                break;
            case Qt.Key_Left:
                prev()
                event.accepted = true
                break;
            case Qt.Key_Right:
                next()
                event.accepted = true
                break;
            case Qt.Key_Up:
                currentTagsList.up()
                event.accepted = true
                break;
            case Qt.Key_Down:
                currentTagsList.down()
                event.accepted = true
                break;
            case Qt.Key_W:
                media.up()
                event.accepted = true
                break;
            case Qt.Key_S:
                media.down()
                event.accepted = true
                break;
            case Qt.Key_A:
                media.left()
                event.accepted = true
                break;
            case Qt.Key_D:
                media.right()
                event.accepted = true
                break;
            default:

            }
        }

        Connections {
            target: backend
            function onImageUpdated() {
                media.reset()
            }
        }
    }

}