import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    visible: true
    width: 1100
    height: 600
    title: backend.title
    id: root
    property var mode: true

    onWidthChanged: {
        sync()
    }
    
    onHeightChanged: {
        sync()
    }

    function save() {
        if(root.mode) {
            backend.applyCrop((media.x + media.fx)-cropAlt.x, (media.y + media.fy)-cropAlt.y, media.fw, media.fh, cropAlt.width, cropAlt.height)
            cropAlt.changed = false
        } else {
            backend.applyCrop((media.x + media.fx)-crop.x, (media.y + media.fy)-crop.y, media.fw, media.fh, crop.width, crop.height)
            media.changed = false
        }
        backend.saveMetadata()
        
    }

    function next() {
        if(saveButton.needsSaving) {
            save()
        }

        backend.active += 1
    }

    function prev() {
        if(saveButton.needsSaving) {
            save()
        }

        backend.active -= 1
    }

    function search(text) {
        backend.search(text)
    }

    function sync() {
        if(root.mode) {
            cropAlt.sync()
            media.sync()
        } else {
            media.sync()
        }
    }

    function changeMode() {
        if(media.changed || cropAlt.changed) {
            save()
        }
        root.mode = !root.mode
        media.sync()
        cropAlt.sync()
    }

    Rectangle {
        id: bg
        color: "#000000"
        anchors.fill: parent
    }

    Rectangle {
        id: view
        color: "#000000"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftDivider.right
        anchors.right: rightDivider.left
        anchors.margins: 4

        onWidthChanged: {
            sync()
        }
        
        onHeightChanged: {
            sync()
        }
    }
    
    Media {
        id: media
        locked: root.mode
        source: backend.source
        anchors.fill: crop
        default_ox: backend.offset_x
        default_oy: backend.offset_y
        default_s: backend.scale

        Component.onCompleted: {
            media.sync()
        }
    }

    Rectangle {
        id: cropOutline
        visible: crop.visible
        color: "#00000000"
        border.width: 4
        border.color: saveButton.needsSaving ? "#aaff0000": "#aa00ff00"
        x: crop.x-4
        y: crop.y-4
        width: crop.width + 8
        height: crop.height + 8
    }

    Rectangle {
        id: crop
        visible: !root.mode
        color: "#00000000"
        anchors.centerIn: view
        width: Math.min(view.width, view.height)
        height: width
    }

    Rectangle {
        id: cropAltOutline
        visible: cropAlt.visible
        color: "#00000000"
        border.width: 4
        border.color: saveButton.needsSaving ? "#aaff0000": "#aa00ff00"
        x: Math.ceil(cropAlt.x-4)
        y: Math.ceil(cropAlt.y-4)
        width: Math.floor(cropAlt.width + 8)
        height: Math.floor(cropAlt.height + 8)
    }

    DashedRectangle {
        id: cropAltOutlineDashed
        visible: cropAlt.visible
        x: Math.ceil(cropAlt.x)
        y: Math.ceil(cropAlt.y)
        width: Math.floor(cropAlt.width) + 1
        height: Math.floor(cropAlt.height) + 1

        Handle {
            id: handleTL
            anchors.right: parent.left
            anchors.bottom: parent.top
        }

        Handle {
            id: handleTR
            anchors.left: parent.right
            anchors.bottom: parent.top
        }

        Handle {
            id: handleBR
            anchors.left: parent.right
            anchors.top: parent.bottom
        }

        Handle {
            id: handleBL
            anchors.right: parent.left
            anchors.top: parent.bottom
        }

        Handle {
            id: handleL
            anchors.right: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        Handle {
            id: handleR
            anchors.left: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }

        Handle {
            id: handleT
            anchors.bottom: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Handle {
            id: handleB
            anchors.top: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Rectangle {
        id: cropAlt
        visible: root.mode
        color: "#00000000"
        height: width

        property bool changed: true

        property var relX: 0
        property var relY: 0
        property var relW: 1.0
        property var max: Math.min(media.fw, media.fh)

        x: media.x+media.fx + relX*width
        y: media.y+media.fy + relY*width
        width: relW*media.width

        function sync() {
            relW = 1/backend.scale
            relX = -backend.offset_x
            relY = -backend.offset_y
            changed = false
        }
    }

    MouseArea {
        anchors.fill: view
        enabled: root.mode
        property var target: cropAlt
        property var startX: 0
        property var startY: 0
        property var posX: 0
        property var posY: 0
        property var posW: 0
        property var posH: 0
        property var dragging: false
        property var adjusting: false

        property var lockL: false
        property var lockR: false
        property var lockT: false
        property var lockB: false

        onPressed: {
            lockL = false
            lockR = false
            lockT = false
            lockB = false

            posX = target.x
            posY = target.y
            posW = target.width
            posH = target.height
            startX = mouseX
            startY = mouseY
            var g = mapToGlobal(startX, startY)

            if(handleTL.contains(g)) {
                adjusting = true
                lockR = true
                lockB = true
                return
            }
            if(handleBR.contains(g)) {
                adjusting = true
                lockL = true
                lockT = true
                return
            }
            if(handleTR.contains(g)) {
                adjusting = true
                lockL = true
                lockB = true
                return
            }
            if(handleBL.contains(g)) {
                adjusting = true
                lockR = true
                lockT = true
                return
            }
            if(handleL.contains(g)) {
                lockT = true
            }
            if(handleR.contains(g)) {
                lockT = true
            }
            if(handleT.contains(g)) {
                lockL = true
            }
            if(handleB.contains(g)) {
                lockL = true
            } 

            dragging = true
        }

        onReleased: {
            dragging = false
            adjusting = false
        }

        function bound(x, y, w, h) {
            w = Math.max(Math.min(w, target.max), 32)

            x = Math.max(media.fx+crop.x, x)
            y = Math.max(media.fy+crop.y, y)
            x = Math.min(media.fx+crop.x+media.fw, x+w)-w
            y = Math.min(media.fy+crop.y+media.fh, y+h)-h

            var relW = w/media.width
            var relX = (x - media.x - media.fx)/w
            var relY = (y - media.y - media.fy)/w

            target.relW = relW
            target.relX = relX
            target.relY = relY

            target.changed = true
        }

        onPositionChanged: {
            if(dragging || adjusting) {
                var dx = (mouseX - startX)
                var dy = (mouseY - startY)
                var x = posX + dx
                var y = posY + dy
                var w = posW
                var h = posH
                
                if(adjusting) {
                    var d = (dx + dy)/2
                    var ddx = d
                    var ddy = d

                    if(lockT && lockR) {
                        d = (dx - dy)/2
                        ddx = d
                        ddy = -d
                    }

                    if(lockB && lockL) {
                        d = (-dx + dy)/2
                        ddx = -d
                        ddy = d
                    }

                    if(lockR) {
                        x = posX + ddx
                        w = posW - ddx
                    }
                    if(lockL) {
                        x = posX
                        w = posW + ddx
                    }
                    if(lockB) {
                        y = posY + ddy
                        h = posH - ddy
                    }
                    if(lockT) {
                        y = posY
                        h = posH + ddy
                    }
                }

                if(dragging) {
                    if(lockL || lockR) {
                        x = posX
                    }
                    if(lockT || lockB) {
                        y = posY
                    }
                }

                if(w > 32) {
                    bound(x, y, w, h)
                    bound(target.x, target.y, target.width, target.height)
                }
            }
        }

        onWheel: {
            if(wheel.angleDelta.y > 0) {
                wheel.accepted = true

                if(target.relW > 0.2) {
                    var o = target.width * 0.05
                    bound(target.x+o/2, target.y+o/2, target.width-o, target.height-o)
                    bound(target.x, target.y, target.width, target.height)
                }

            } else {
                wheel.accepted = true

                if(target.relW < 1.0) {
                    var o = target.width * 0.05
                    bound(target.x-o/2, target.y-o/2, target.width + o, target.height + o)
                    bound(target.x, target.y, target.width, target.height)
                }
            }
        }
    }

    Rectangle {
        visible: !root.mode
        color: "#aa000000"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftDivider.right
        anchors.right: crop.left
        anchors.rightMargin: 4
    }
    Rectangle {
        visible: !root.mode
        color: "#aa000000"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: crop.right
        anchors.right: rightDivider.left
        anchors.leftMargin: 4
    }
    Rectangle {
        visible: !root.mode
        color: "#aa000000"
        anchors.top: parent.top
        anchors.bottom: crop.top
        anchors.left: leftDivider.right
        anchors.right: rightDivider.left
        anchors.bottomMargin: 4
    }
    Rectangle {
        visible: !root.mode
        color: "#aa000000"
        anchors.top: crop.bottom
        anchors.bottom: parent.bottom
        anchors.left: leftDivider.right
        anchors.right: rightDivider.left
        anchors.topMargin: 4
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
        anchors.bottom: sugDivider.top
        anchors.left: parent.left
        anchors.right: leftDivider.left
        clip: true

        Tags {
            id: searchTagsList
            model: backend.results
            anchors.fill: parent
            moveEnabled: false

            function getOverlay(tag, index) {
                return backend.tags.includes(tag) ? "#77000000" : "#00000000"
            }

            onPressed: {
                currentTagsList.deselect()
                favTagsList.deselect()
            }

            onDoublePressed: {
                if(!backend.tags.includes(tag)) {
                    backend.addTag(tag)
                    currentTagsList.add(tag)
                }
            }

            onModelChanged: {
                populate()
            }
        }
    }

    Rectangle {
        z:10
        id: sugDivider
        anchors.left: parent.left
        anchors.right: leftDivider.left
        height: 5
        property int minY: 30
        property int maxY: parent.height - 10
        color: "#404040"

        Component.onCompleted: {
            y = parent.height/3
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: {
                if(pressedButtons) {
                    sugDivider.y = Math.min(sugDivider.maxY, Math.max(sugDivider.minY, sugDivider.y + mouseY))
                }
            }
        }

        onMaxYChanged: {
            sugDivider.y = Math.min(sugDivider.maxY, Math.max(sugDivider.minY, sugDivider.y))
        }
    }

    Rectangle {
        id: sugLabel
        color: "#303030"
        anchors.top: sugDivider.bottom
        height: 30
        anchors.left: parent.left
        anchors.right: leftDivider.left
        Text {
            text: "Suggestions"
            font.pixelSize: 15
            leftPadding: 8
            rightPadding: 16
            font.bold: false
            color: "white"
            verticalAlignment: Text.AlignVCenter
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        IconButton {
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height
            width: height
            icon: "qrc:/icons/brain.svg"
            property int s: backend.ddbStatus
            id: ddbButton

            tooltip: s == -2 ? "Load DeepDanbooru?" : s == -1 ? "Loading..." : "Interrogate via DeepDanbooru"
            color: "#303030"
            iconColor: s <= -1 ? "#424242" : "#516a98"
            iconHoverColor: s <= -1 ? "#424242" : "#5d91f0"
            working: backend.ddbStatus > 0
            onPressed: {
                backend.ddbInterrogate()
            }
        }

        IconButton {
            visible: !backend.showingFrequent
            anchors.right: ddbButton.left
            anchors.top: parent.top
            height: parent.height
            width: height
            icon: "qrc:/icons/bookshelf.svg"
            tooltip: "Show frequently used"
            color: "#303030"
            onPressed: {
                backend.showFrequent()
            }
        }
    }

    Rectangle {
        id: sugTags
        color: "#202020"
        anchors.top: sugLabel.bottom
        anchors.bottom: favDivider.top
        anchors.left: parent.left
        anchors.right: leftDivider.left
        clip: true

        Tags {
            id: sugTagsList
            model: backend.suggestions
            anchors.fill: parent
            moveEnabled: false

            function getOverlay(tag, index) {
                return backend.tags.includes(tag) ? "#77000000" : "#00000000"
            }

            onPressed: {
                currentTagsList.deselect()
                favTagsList.deselect()
            }

            onDoublePressed: {
                if(!backend.tags.includes(tag)) {
                    backend.addTag(tag)
                    currentTagsList.add(tag)
                }
            }

            onModelChanged: {
                populate()
            }
        }
    }


    Rectangle {
        z:10
        id: favDivider
        anchors.left: parent.left
        anchors.right: leftDivider.left
        height: 5
        property int minY: sugDivider.y + 5
        property int maxY: parent.height-5
        color: "#404040"

        Component.onCompleted: {
            y = 2*parent.height/3
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: {
                if(pressedButtons) {
                    favDivider.y = Math.min(favDivider.maxY, Math.max(favDivider.minY, favDivider.y + mouseY))
                }
            }
        }

        onMinYChanged: {
            favDivider.y = Math.min(favDivider.maxY, Math.max(favDivider.minY, favDivider.y))
        }

        onMaxYChanged: {
            favDivider.y = Math.min(favDivider.maxY, Math.max(favDivider.minY, favDivider.y))
        }
    }

    Rectangle {
        id: favLabel
        color: "#303030"
        anchors.top: favDivider.bottom
        height: 30
        anchors.left: parent.left
        anchors.right: leftDivider.left
        Text {
            text: "Favourites"
            font.pixelSize: 15
            leftPadding: 8
            rightPadding: 16
            font.bold: false
            color: "white"
            verticalAlignment: Text.AlignVCenter
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        IconButton {
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height
            width: height
            icon: "qrc:/icons/plus.svg"
            tooltip: "Add all"
            color: "#303030"
            onPressed: {
                for(var i = 0; i < backend.favourites.length; i++) {
                    var tag = backend.favourites[i]
                    if(!backend.tags.includes(tag)) {
                        backend.addTag(tag)
                        currentTagsList.add(tag)
                    }
                }
            }
        }
    }

    Rectangle {
        id: favTags
        color: "#202020"
        anchors.top: favLabel.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: leftDivider.left
        clip: true

        Tags {
            id: favTagsList
            model: backend.favourites
            anchors.fill: parent

            function getOverlay(tag, index) {
                return backend.tags.includes(tag) ? "#77000000" : "#00000000"
            } 

            onPressed: {
                searchTagsList.deselect()
                currentTagsList.deselect()
            }

            onDoublePressed: {
                if(!backend.tags.includes(tag)) {
                    backend.addTag(tag)
                    currentTagsList.add(tag)
                }
            }
       
            onMoved: {
                backend.moveFavourite(from, to)
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
            font.bold: false
            color: "white"
            verticalAlignment: Text.AlignVCenter
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        IconButton {
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height
            width: height
            icon: "qrc:/icons/trash.svg"
            tooltip: "Remove unknown"
            color: "#303030"
            id: cleanButton
            onPressed: {
                backend.cleanTags()
            }
        }

        IconButton {
            anchors.right: cleanButton.left
            anchors.top: parent.top
            height: parent.height
            width: height
            icon: "qrc:/icons/sort.svg"
            tooltip: "Sort by popularity"
            color: "#303030"
            id: sortButton
            onPressed: {
                backend.sortTags()
            }
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
            id: packageButton
            height: controls.height
            anchors.left: controls.left
            anchors.top: controls.top
            width: height
            icon: "qrc:/icons/package.svg"
            tooltip: "Package outputs"
            color: "#303030"
            working: packageWindow.visible
            onPressed: {
                packageWindow.open()
            }
        }

        IconButton {
            height: controls.height
            anchors.left: packageButton.right
            anchors.leftMargin: 0
            anchors.top: controls.top
            width: height
            icon: "qrc:/icons/crop.svg"
            tooltip: "Toggle mode (T)"
            color: "#303030"
            iconColor: !root.mode ? "#aaa" : "#606060"
            onPressed: {
                changeMode()
            }
        }

        Row {
            width: Math.min(parent.width, implicitWidth)
            anchors.right: parent.right
            IconButton {
                height: controls.height
                width: height
                icon: "qrc:/icons/save.svg"
                tooltip: "Save metadata (F)"
                color: "#303030"
                id: saveButton
                property bool needsSaving: media.changed || cropAlt.changed || backend.changed
                iconColor: needsSaving ? "#ba0000" : "green"
                onPressed: {
                    save()
                }
            }

            IconButton {
                height: controls.height
                width: height
                icon: "qrc:/icons/refresh.svg"
                tooltip: "Revert to last save (R)"
                color: "#303030"

                onPressed: {
                    backend.reset()
                }

                onContextMenu: {
                    resetContextMenu.popup()
                }

                ContextMenu {
                    id: resetContextMenu
                    y: -100

                    Action {
                        text: "Full reset"
                        onTriggered: {
                            backend.fullReset()
                        }
                    }

                    onClosed: {
                        keyboardFocus.forceActiveFocus()
                    }
                }
            }

            IconButton {
                height: controls.height
                width: height
                icon: "qrc:/icons/back.svg"
                tooltip: "Previous image (Left)"
                color: "#303030"
                onPressed: {
                    prev()
                }
            }

            IconButton {
                height: controls.height
                width: height
                icon: "qrc:/icons/next.svg"
                tooltip: "Next image (Right)"
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
            model: backend.tags
            anchors.fill: parent

            function getOverlay(tag, index) {
                return backend.lookup(tag) ? "#00000000" : "#33550000"
            } 

            onPressed: {
                searchTagsList.deselect()
                favTagsList.deselect()
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
                backend.reset()
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
            case Qt.Key_T:
                changeMode()
                event.accepted = true
                break;
            case Qt.Key_O:
                save()
                backend.writeDebugCrop()
                event.accepted = true
                break;
            default:

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