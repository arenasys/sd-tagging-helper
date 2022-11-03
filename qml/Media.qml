import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: view
    property string source
    property string type
    property bool locked: true

    property var fx: full.x
    property var fy: full.y
    property var fw: full.width
    property var fh: full.height

    property alias w: full.implicitWidth
    property alias h: full.implicitHeight

    property var ox
    property var oy
    property var s

    property var scale: 1.0
    property var max: false

    property MouseArea mouse: mouse   

    property bool ready: full.status == Image.Ready 

    property bool changed: true

    color: locked ? "#00000000" : "#202020"

    function sync() {
        if(view.locked) {
            full.anchors.centerIn = view
            full.maxWidth = view.width
            full.maxHeight = view.height
            view.changed = false
        } else {
            view.scale = view.s
            full.maxWidth = Math.ceil(view.width * view.scale)
            full.maxHeight = Math.ceil(view.height * view.scale)
            full.anchors.centerIn = undefined
            full.x = view.width * view.ox
            full.y = view.width * view.oy
            view.changed = false
        }
    }

    function up() {
        full.y += 10
    }

    function down() {
        full.y -= 10
    }

    function left() {
        full.x += 10
    }

    function right() {
        full.x -= 10
    }

    CenteredImage {
        id: full
        anchors.centerIn: view 
        asynchronous: false
        source: "file:///" + view.source
        smooth: implicitWidth*2 < width && implicitHeight*2 < height ? false : true
        maxWidth: view.width
        maxHeight: view.height
        fill: true

        onStatusChanged: {
            if(status == Image.Ready) {
                full.sync()
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: !view.locked

        property var startX: 0
        property var startY: 0
        property var posX: 0
        property var posY: 0
        property var dragging: false

        onPressed: {
            posX = full.x
            posY = full.y
            startX = mouseX
            startY = mouseY
            dragging = true
        }

        onReleased: {
            dragging = false
        }

        onPositionChanged: {
            if(dragging) {
                full.anchors.centerIn = undefined

                full.x = posX + (mouseX - startX)
                full.y = posY + (mouseY - startY)

                bound()
            }
        }

        function bound() {
            view.changed = true
            var dx = (full.maxWidth - full.width)/2
            var dy = (full.maxHeight - full.height)/2

            var x = full.x + dx
            var y = full.y + dy
            var w = full.width
            var h = full.height

            if(x + w - dx < view.width/2)
                x = view.width/2 - w + dx
            if(y + h - dy < view.height/2)
                y = view.height/2 - h + dy

            if(x > view.width/2 + dx)
                x = view.width/2 + dx

            if(y > view.height/2 + dy)
                y = view.height/2 + dy

            full.x = x - dx
            full.y = y - dy
        }

        function scale(cx, cy, d) {
            full.anchors.centerIn = undefined

            d = view.scale * d

            var f = ((view.scale + d)/view.scale) -1

            if(view.scale + d < 0.1) {
                return
            }

            view.scale += d

            full.maxWidth = view.scale * view.width
            full.maxHeight = view.scale * view.height

            var dx = f*(cx - full.x)
            var dy = f*(cy - full.y)

            full.x -= dx
            full.y -= dy
            posX -= dx
            posY -= dy

            bound()

            view.max = true
        }

        onWheel: {
            if(wheel.angleDelta.y < 0) {
                wheel.accepted = true
                scale(wheel.x, wheel.y, -0.05)
            } else {
                wheel.accepted = true
                scale(wheel.x, wheel.y, 0.05)
            }
        }
    }
}
