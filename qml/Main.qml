import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.12

ApplicationWindow {
    visible: true
    width: 1100
    height: 600
    title: backend.title
    id: root
    property var cropMode: true
    property var layoutMode: false
    property var needsSaving: view.changed || backend.changed

    onWidthChanged: {
        sync()
    }
    
    onHeightChanged: {
        sync()
    }

    function save() {
        backend.applyCrop((view.media.x + view.media.fx)-view.crop.x, (view.media.y + view.media.fy)-view.crop.y, view.media.fw, view.media.fh, view.crop.width, view.crop.height)
        view.unchange()
        backend.saveMetadata()
    }

    function next() {
        if(needsSaving) {
            save()
        }
        backend.active += 1
    }

    function prev() {
        if(needsSaving) {
            save()
        }
        backend.active -= 1
    }

    function search(text) {
        backend.search(text)
    }

    function sync() {
        view.sync()
    }

    function changeMode() {
        if(view.changed) {
            save()
        }
        root.cropMode = !root.cropMode
        view.sync()
    }

    function changeLayout() {
        root.layoutMode = !root.layoutMode
        leftDivider.setup()
        rightDivider.setup()
        centerDivider.setup()
        sync()
    }

    Rectangle {
        id: bg
        color: "#000000"
        anchors.fill: parent
    }

    View {
        id: view
        needsSaving: root.needsSaving
        mode: root.cropMode
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: layoutMode ? rightDivider.right : leftDivider.right
        anchors.right: layoutMode ? parent.right : rightDivider.left
    }
    
    TagsColumn {
        id: tags
        layoutMode: root.layoutMode
        anchors.left: parent.left
        anchors.right: leftDivider.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        onDeselect: {
            current.doDeselect()
        }
    }

    CurrentColumn {
        id: current
        needsSaving: root.needsSaving
        anchors.left: layoutMode ? centerDivider.right : rightDivider.right
        anchors.right: layoutMode ? rightDivider.left : parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        onSave: {
            root.save()
        }
        onChangeMode: {
            root.changeMode()
        }
        onPackageWindowOpen: {
            packageWindow.open()
        }
        onFocusRelease: {
            keyboardFocus.forceActiveFocus()
        }
        onPrev: {
            root.prev()
        }
        onNext: {
            root.next()
        }
        onDeselect: {
            tags.doDeselect()
        }
    }

    DDBColumn {
        visible: layoutMode
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftDivider.right
        anchors.right: centerDivider.left
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

        function setup() {
            x = 150
        }

        Component.onCompleted: {
            setup()
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
        z:10
        visible: layoutMode
        id: centerDivider
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 5
        property int minX: leftDivider.x+5
        property int maxX: rightDivider.x-5
        color: "#404040"

        function setup() {
            x = 300
        }

        Component.onCompleted: {
            setup()
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: {
                if(pressedButtons) {
                    centerDivider.x = Math.min(centerDivider.maxX, Math.max(centerDivider.minX, centerDivider.x + mouseX))
                }
            }
        }

        onMaxXChanged: {
            centerDivider.x = Math.min(centerDivider.maxX, Math.max(centerDivider.minX, centerDivider.x))
        }
    }

    

    Rectangle {
        id: rightDivider
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 5
        property int minX: layoutMode ? 100 : 5
        property int maxX: layoutMode ? parent.width-centerDivider.x-5 : Math.min(300, parent.width-leftDivider.x)
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

        function setup() {
            if(layoutMode) {
                offset = parent.width - 450
            } else {
                offset = 190
            }
        }

        Component.onCompleted: {
            setup()
        }
    }

    PackageWindow {
        id: packageWindow
        onFocusRelease: {
            keyboardFocus.forceActiveFocus()
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
                view.media.up()
                event.accepted = true
                break;
            case Qt.Key_S:
                view.media.down()
                event.accepted = true
                break;
            case Qt.Key_A:
                view.media.left()
                event.accepted = true
                break;
            case Qt.Key_D:
                view.media.right()
                event.accepted = true
                break;
            case Qt.Key_Alt:
                changeMode()
                event.accepted = true
                break;
            }

            if((event.modifiers & Qt.ControlModifier)) {
                switch(event.key) {
                case Qt.Key_Z:
                    backend.reset()
                    event.accepted = true
                    break;
                case Qt.Key_S:
                    save()
                    event.accepted = true
                    break;
                case Qt.Key_A:
                    backend.center()
                    event.accepted = true
                    break;
                case Qt.Key_D:
                    backend.fill()
                    event.accepted = true
                    break;
                case Qt.Key_E:
                    save()
                    backend.writeDebugCrop()
                    event.accepted = true
                    break;
                case Qt.Key_C:
                    save()
                    backend.copy()
                    event.accepted = true
                    break;
                case Qt.Key_V:
                    backend.paste(false)
                    event.accepted = true
                    break;
                case Qt.Key_B:
                    backend.paste(true)
                    event.accepted = true
                    break;
                case Qt.Key_L:
                    changeLayout()
                    event.accepted = true
                    break;
                }
            }
        }

        Connections {
            target: backend
            function onImageUpdated() {
                sync()
            }
        }
    }
}