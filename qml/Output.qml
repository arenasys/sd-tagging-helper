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

        LoadingSpinner {
            anchors.centerIn: parent
        }


        CenteredImage {
            id: preview
            anchors.centerIn: parent
            asynchronous: true
            source: output.visible ? backend.preview : ""
            maxWidth: parent.width
            maxHeight: parent.height
            fill: true

            onStatusChanged: {
                if(status == Image.Ready) {
                    preview.sync()
                    canvas.requestPaint()
                }
            }
        }

        Canvas {
            id: canvas
            anchors.fill: preview
            property var l: backend.letterboxs
            property var drawing: false
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                if(!drawing) {
                    return
                }
                
                ctx.lineWidth = 1

                var s = width/1024

                for(var i = 0; i < l.length; i++) {
                    var letterbox = l[i]
                    var polygon = letterbox[0]
                    var edges = letterbox[1]

                    var hue = (i/(l.length+1))
                    var color = Qt.hsva(hue, 0.25, 1.0, 1.0)

                    ctx.lineWidth = 1
                    ctx.strokeStyle = "#aaa"
                    ctx.fillStyle = ctx.createPattern(color, Qt.DiagCrossPattern)
                    
                    ctx.beginPath()
                    ctx.moveTo(polygon[0].x*s, polygon[0].y*s)
                    for(var k = 1; k < polygon.length; k++) {
                        ctx.lineTo(polygon[k].x*s, polygon[k].y*s)
                    }
                    ctx.lineTo(polygon[0].x*s, polygon[0].y*s)
                    ctx.stroke()
                    ctx.fill()

                    //ctx.lineWidth = 3
                    ctx.strokeStyle = Qt.hsva(hue, 1.0, 1.0, 1.0)

                    for(var k = 0; k < edges.length; k++) {
                        var edge = edges[k]
                        ctx.beginPath()
                        ctx.moveTo(edge[0].x*s, edge[0].y*s)
                        ctx.lineTo(edge[1].x*s, edge[1].y*s)
                        ctx.stroke()
                    }
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

    Rectangle {
        id: controlsDivider
        height: 5
        color: "#404040"
        clip: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: outputControls.top
    }

    Rectangle {
        id: outputControls
        height: 30
        color: "#303030"
        clip: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        IconButton {
            height: parent.height
            anchors.left: parent.left
            anchors.top: parent.top
            width: height
            icon: "qrc:/icons/eye.svg"
            tooltip: "View letterbox geometry"
            color: "#303030"
            iconColor: canvas.drawing ? "#aaa" : "#606060"
            onPressed: {
                canvas.drawing = !canvas.drawing
                canvas.requestPaint()
            }
        }
    }
}