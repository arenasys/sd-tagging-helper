import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15

Rectangle {
    id: button
    color: "#303030"
    property var icon
    property var iconColor: "#606060"
    property var iconHoverColor: "white"
    property bool disabled: false
    property bool working: false
    property var inset: 10
    property var tooltip: ""
    property var hovered: false
    
    property bool glowing: false
    property var glowColor: "white"
    property var glowStrength: 3
    
    signal pressed();
    signal contextMenu();
    signal entered();
    signal exited();

    MouseArea {
        anchors.fill: parent
        id: mouse
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPressed: {
            if(disabled)
                return
            if (mouse.button === Qt.LeftButton) {
                button.pressed()
            } else {
                button.contextMenu()
            }
            
        }

        onEntered: {
            button.entered()
        }

        onExited: {
            button.exited()
        }
    }

    InfoToolTip {
        id: infoToolTip
        visible: !disabled && tooltip != "" && mouse.containsMouse
        delay: 100
        text: tooltip
    }

    Image {
        id: img
        source: icon
        width: parent.height - inset
        height: width
        sourceSize: Qt.size(parent.width, parent.height)
        anchors.centerIn: parent
    }

    ColorOverlay {
        id: color
        anchors.fill: img
        source: img
        color: disabled ? Qt.darker(iconColor) : (mouse.containsMouse ? iconHoverColor : iconColor)
    }

    Glow {
        id: glow
        visible: glowing
        anchors.fill: img
        source: color
        radius: Math.abs(glowStrength - r)
        samples: 17
        color: glowColor
        property var r: 0

        RotationAnimation on r {
            id: glowAnimation
            duration: 1000
            loops: Animation.Infinite
            from: 0
            to: 2*glowStrength
            onStopped: {
                glow.r = 0
            }
        }
    }

    function sync() {
        if(working) {
            glowAnimation.restart()
        } else {
            glowAnimation.stop()
        }
    }

    onWorkingChanged: sync()
    Component.onCompleted: sync()
    onVisibleChanged: sync()

}
