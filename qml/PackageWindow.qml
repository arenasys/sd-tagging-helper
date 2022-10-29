import QtQuick 2.15
import QtQuick.Controls 2.15

PopupWindow {
    id: packageWindow
    title: "Package"
    titleIcon: "qrc:/icons/package.svg"
    parent: Overlay.overlay
    modal: true
    closePolicy: Popup.CloseOnEscape

    signal focusRelease()

    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: 280
    height: 160

    onOpened: {
        forceActiveFocus()
    }

    onClosed: {
        focusRelease()
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