import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property var needsSaving: false
    property var altCropMode: false
    
    property alias currentlySelected: currentTagsList.selected

    signal save()
    signal changeMode()
    signal packageWindowOpen()
    signal focusRelease()
    signal prev()
    signal next()

    function tagAdded() {
        currentTagsList.tagAdded()
    }

    Rectangle {
        id: currentLabel
        color: "#303030"
        anchors.top: parent.top
        height: 30
        anchors.left: parent.left
        anchors.right: parent.right
        Text {
            text: "Active Tags"
            font.pixelSize: 15
            leftPadding: 8
            rightPadding: 16
            font.bold: false
            color: "white"
            verticalAlignment: Text.AlignVCenter
            width: Math.min(parent.width-40, implicitWidth)
            elide: Text.ElideRight
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        Row {
            width: Math.min(parent.width, implicitWidth)
            anchors.right: parent.right
            clip: true
            IconButton {
                height: currentLabel.height
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
                height: currentLabel.height
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
    }

    Rectangle {
        id: currentTags
        color: "#202020"
        anchors.top: currentLabel.bottom
        anchors.bottom: controls.top
        anchors.left: currentLabel.left
        anchors.right: currentLabel.right
        clip: true

        Tags {
            id: currentTagsList
            index: 0
            model: backend.tags
            anchors.fill: parent

            function getOverlay(tag, index) {
                return backend.tagExists(tag) ? "#00000000" : "#33550000"
            }

            onMoved: {
                backend.moveTag(from, to)
            }

            onDoublePressed: {
                backend.deleteTag(index)
            }
            
            onModelChanged: {
                populate()
            }
        }
    }

    Rectangle {
        id: controls
        color: "#303030"
        height: 30
        anchors.bottom: parent.bottom
        anchors.left: currentLabel.left
        anchors.right: currentLabel.right
        clip: true

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
                root.packageWindowOpen()
            }
        }

        Row {
            width: Math.min(parent.width, implicitWidth)
            anchors.right: parent.right
            IconButton {
                height: controls.height
                width: height
                icon: "qrc:/icons/save.svg"
                tooltip: "Save metadata (Ctrl+S)"
                color: "#303030"
                id: saveButton
                iconColor: needsSaving ? "#ba0000" : "green"
                onPressed: {
                    root.save()
                }
            }

            IconButton {
                height: controls.height
                width: height
                icon: "qrc:/icons/refresh.svg"
                tooltip: "Revert to last save (Ctrl+Z)"
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
                        root.focusRelease()
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
                    root.prev()
                }
            }

            IconButton {
                height: controls.height
                width: height
                icon: "qrc:/icons/next.svg"
                tooltip: "Next image (Right)"
                color: "#303030"
                onPressed: {
                    root.next()
                }
            }
        }
    }
}