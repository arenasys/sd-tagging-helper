import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.12

ApplicationWindow {
    visible: true
    width: 1100
    height: 600
    title: backend.title
    id: root
    property var altCropMode: true
    property var altLayoutMode: false
    property var needsSaving: view.changed || backend.changed

    onWidthChanged: {
        view.sync()
    }
    
    onHeightChanged: {
        view.sync()
    }

    function save() {
        var fx = ((view.media.x + view.media.fx)-view.crop.x)
        var fy = ((view.media.y + view.media.fy)-view.crop.y)
        var fw = (view.media.fw)
        var fh = (view.media.fh)
        var cw = (view.crop.width)
        var ch = (view.crop.height)
        backend.applyCrop(fx, fy, fw, fh, cw, ch)
        view.unchange()
        backend.saveStagingData()
    }

    function sourceDimension() {
        var w = Math.floor(view.media.w * (view.crop.width/view.media.fw))
        var h = Math.floor(view.media.h * (view.crop.height/view.media.fh))
        return Math.max(w,h)
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

    function changeMode() {
        if(view.changed) {
            save()
        }
        root.altCropMode = !root.altCropMode
        view.sync()
    }

    function changeLayout() {
        root.altLayoutMode = !root.altLayoutMode
        leftDivider.setup()
        rightDivider.setup()
        centerDivider.setup()
        view.sync()
    }

    Rectangle {
        id: bg
        color: "#000000"
        anchors.fill: parent
    }

    View {
        id: view
        needsSaving: root.needsSaving
        mode: root.altCropMode
        anchors.top: parent.top
        anchors.bottom: viewDivider.top
        anchors.left: altLayoutMode ? rightDivider.right : leftDivider.right
        anchors.right: altLayoutMode ? parent.right : rightDivider.left
    }

    Rectangle {
        id: viewDivider
        height: 5
        color: "#404040"
        clip: true
        anchors.left: altLayoutMode ? rightDivider.right : leftDivider.right
        anchors.right: altLayoutMode ? parent.right : rightDivider.left
        anchors.bottom: viewControls.top
    }

    Rectangle {
        id: viewControls
        height: 30
        color: "#303030"
        clip: true
        anchors.left: altLayoutMode ? rightDivider.right : leftDivider.right
        anchors.right: altLayoutMode ? parent.right : rightDivider.left
        anchors.bottom: parent.bottom

        IconButton {
            height: parent.height
            anchors.left: parent.left
            anchors.top: parent.top
            width: height
            icon: "qrc:/icons/crop.svg"
            tooltip: "Switch mode (Alt)"
            color: "#303030"
            iconColor: !altCropMode ? "#aaa" : "#606060"
            onPressed: {
                changeMode()
            }
        }

        Row {
            width: Math.min(parent.width, implicitWidth)
            anchors.right: parent.right
            Text {
                text: sourceDimension() + " ➜ " + backend.dimension
                rightPadding: 10
                font.pixelSize: 15
                font.bold: true
                height: 30
                color: "#c0c0c0"//sourceDimension() >= backend.dimension ? "green" : "#ba0000"
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
    
    TagsColumn {
        id: tags
        altLayoutMode: root.altLayoutMode
        anchors.left: parent.left
        anchors.right: leftDivider.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        onTagAdded: {
            current.tagAdded()
        }

        onFocusRelease: {
            keyboardFocus.forceActiveFocus()
        }
    }

    CurrentColumn {
        id: current
        altCropMode: root.altCropMode
        needsSaving: root.needsSaving
        anchors.left: altLayoutMode ? centerDivider.right : rightDivider.right
        anchors.right: altLayoutMode ? rightDivider.left : parent.right
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
    }

    DDBColumn {
        id: ddb
        visible: altLayoutMode
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftDivider.right
        anchors.right: centerDivider.left

        onTagAdded: {
            current.tagAdded()
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
        visible: altLayoutMode
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
        property int minX: altLayoutMode ? 100 : 5
        property int maxX: altLayoutMode ? parent.width-centerDivider.x-5 : Math.min(300, parent.width-leftDivider.x)
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
            if(altLayoutMode) {
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
            event.accepted = true
            if(event.modifiers & Qt.ControlModifier) {
                switch(event.key) {
                case Qt.Key_Z:
                    backend.reset()
                    break;
                case Qt.Key_S:
                    save()
                    break;
                case Qt.Key_A:
                    backend.center()
                    break;
                case Qt.Key_D:
                    backend.fill()
                    break;
                case Qt.Key_E:
                    save()
                    backend.writeDebugCrop()
                    break;
                case Qt.Key_C:
                    save()
                    backend.copy()
                    break;
                case Qt.Key_V:
                    backend.paste(false)
                    break;
                case Qt.Key_B:
                    backend.paste(true)
                    break;
                case Qt.Key_L:
                    changeLayout()
                    break;
                case Qt.Key_K:
                    backend.toggleTagColors()
                    break;
                case Qt.Key_Tab:
                    backend.doListEvent(-2)
                    break;
                case Qt.Key_Q:
                    save()
                    backend.ddbInterrogate()
                    break;
                case Qt.Key_1:
                    tags.addFavourites()
                    break;
                default:
                    event.accepted = false
                    break;
                }
            } else {
                switch(event.key) {
                case Qt.Key_Escape:
                    root.close()
                    break;
                case Qt.Key_Delete:
                    backend.deleteTag(current.currentlySelected)
                    break;
                case Qt.Key_Left:
                    prev()
                    break;
                case Qt.Key_Right:
                    next()
                    break;
                case Qt.Key_Up:
                    backend.doListEvent(-1)
                    break;
                case Qt.Key_Down:
                    backend.doListEvent(1)
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    backend.doListEvent(0)
                    break;
                case Qt.Key_Tab:
                    backend.doListEvent(2)
                    break;
                case Qt.Key_W:
                    view.media.up()
                    break;
                case Qt.Key_S:
                    view.media.down()
                    break;
                case Qt.Key_A:
                    view.media.left()
                    break;
                case Qt.Key_D:
                    view.media.right()
                    break;
                case Qt.Key_Alt:
                    changeMode()
                    break;
                default:
                    event.accepted = false
                    break;
                }
            }
        }

        Connections {
            target: backend
            function onImageUpdated() {
                view.sync()
            }
        }
    }
}