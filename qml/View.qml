import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.12

Rectangle {
    id: view
    color: "#000000"
    anchors.margins: 4
    property var mode: false
    property var needsSaving: false

    property alias media: media
    property var crop: mode ? cropAlt : crop
    property var changed: cropAlt.changed || media.changed

    onWidthChanged: {
        sync()
    }
    
    onHeightChanged: {
        sync()
    }

    function unchange() {
        media.changed = false
        cropAlt.changed = false
    }

    function sync() {
        cropAlt.sync()
        media.sync()
    }

    Media {
        id: media
        locked: view.mode
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
        border.color: needsSaving ? "#aaff0000": "#aa00ff00"
        x: crop.x-4
        y: crop.y-4
        width: crop.width + 8
        height: crop.height + 8
    }

    Rectangle {
        id: crop
        visible: !view.mode
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
        border.color: needsSaving ? "#aaff0000": "#aa00ff00"
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
        visible: view.mode
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
        enabled: view.mode
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
        visible: !view.mode
        color: "#aa000000"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: crop.left
        anchors.margins: -4
        anchors.rightMargin: 4
    }
    Rectangle {
        visible: !view.mode
        color: "#aa000000"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: crop.right
        anchors.right: parent.right
        anchors.margins: -4
        anchors.leftMargin: 4
    }
    Rectangle {
        visible: !view.mode
        color: "#aa000000"
        anchors.top: parent.top
        anchors.bottom: crop.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: -4
        anchors.bottomMargin: 4
    }
    Rectangle {
        visible: !view.mode
        color: "#aa000000"
        anchors.top: crop.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: -4
        anchors.topMargin: 4

    }
}