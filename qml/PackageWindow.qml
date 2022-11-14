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
    width: 370
    height: 200

    onOpened: {
        forceActiveFocus()
    }

    onClosed: {
        focusRelease()
    }

    Text {
        id: imageLabel
        text: "Image"
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
        id: imageMode
        font.pixelSize: 15
        anchors.top: imageLabel.top
        anchors.left: imageLabel.right
        currentIndex: 0
        width: 180
        height: 30
        model: ["crop/letterbox", "scale", "original", "none"]
    }

    Combo {
        id: extMode
        font.pixelSize: 15
        visible: imageMode.currentIndex <= 2
        anchors.top: imageLabel.top
        anchors.left: imageMode.right
        anchors.leftMargin: 5
        currentIndex: 0
        width: 100
        height: 30
        model: ["jpg", "png", "original"]
    }

    Text {
        id: promptLabel
        text: "Prompt"
        font.pixelSize: 15
        anchors.left: imageLabel.left
        y: imageLabel.y + 40
        height: 30
        leftPadding: 4
        rightPadding: 16
        font.bold: true
        color: "white"
        verticalAlignment: Text.AlignVCenter
    }

    Combo {
        id: promptMode
        font.pixelSize: 15
        anchors.top: promptLabel.top
        anchors.left: imageMode.left
        anchors.right: extMode.right
        currentIndex: 0
        height: 30
        model: ["txt file", "json file", "filename", "none"]
    }

    Text {
        id: threadLabel
        text: "Threads"
        font.pixelSize: 15
        anchors.left: imageLabel.left
        y: imageLabel.y + 80
        height: 30
        leftPadding: 4
        rightPadding: 16
        font.bold: true
        color: "white"
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        id: threadCountLabel
        text: threadCount.value
        font.pixelSize: 15
        anchors.left: threadLabel.right
        anchors.leftMargin: -8
        anchors.top: threadLabel.top
        height: 30
        width: 20
        horizontalAlignment: Text.AlignHCenter
        color: "white"
        verticalAlignment: Text.AlignVCenter
    }

    Slide {
        id: threadCount
        font.pixelSize: 15
        anchors.top: threadLabel.top
        anchors.left: threadCountLabel.right
        anchors.right: extMode.right
        height: 30
        from: 1
        value: 2
        to: backend.maxThreads
        snapMode: Slider.SnapAlways
        stepSize: 1.0
    }

    IconButton {
        id: startButton
        y: imageLabel.y + 120
        anchors.left: parent.left
        anchors.right: progress.left
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        width: 30
        height: 30
        icon: backend.cropActive ? "qrc:/icons/cross.svg" : "qrc:/icons/tick.svg"
        tooltip: backend.cropActive ? "Stop!" : "Start!"
        color: "#202020"
        onPressed: {
            if(backend.cropActive) {
                backend.stopPackage()
            } else {
                backend.package(imageMode.currentIndex, extMode.currentIndex, promptMode.currentIndex, threadCount.value)
            }
        }
    }

    Rectangle {
        id: progress
        anchors.top: startButton.top
        anchors.bottom: startButton.bottom
        x: startButton.x + 40
        anchors.left: promptMode.left
        anchors.right: openButton.left
        anchors.rightMargin: 10
        height: 30
        color: "#202020"

        Rectangle {
            id: progressGreen
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * backend.cropProgress
            height: 30
            color: "green"
        }

        Text {
            id: progressLabel
            text:  backend.cropStatus
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

    IconButton {
        id: openButton
        y: imageLabel.y + 120
        anchors.top: startButton.top
        anchors.bottom: startButton.bottom
        anchors.right: promptMode.right
        width: 30
        height: 30
        icon: "qrc:/icons/folder.svg"
        tooltip: "Open Folder"
        color: "#202020"
        onPressed: {
            backend.openOutputFolder()
        }
    }
}