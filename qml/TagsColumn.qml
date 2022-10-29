import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.12

Item {
    id: root
    property var layoutMode: false

    signal deselect()

    function doDeselect() {
        searchTagsList.deselect()
        sugTagsList.deselect()
        favTagsList.deselect()
    }

    Search {
        id: searchBox
        anchors.top: parent.top
        height: 30
        anchors.left: parent.left
        anchors.right: parent.right
        
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
        anchors.left: searchBox.left
        anchors.right: searchBox.right
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
                sugTagsList.deselect()
                favTagsList.deselect()
                root.deselect()
            }

            onDoublePressed: {
                if(!backend.tags.includes(tag)) {
                    backend.addTag(tag)
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
        anchors.right: parent.right
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
        anchors.left: sugDivider.left
        anchors.right: sugDivider.right
        Text {
            text: "Suggestions"
            font.pixelSize: 15
            leftPadding: 8
            rightPadding: 16
            font.bold: false
            color: "white"
            verticalAlignment: Text.AlignVCenter
            width: Math.min(parent.width, implicitWidth)
            elide: Text.ElideRight
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        DDBButton {
            id: ddbButton
            visible: !layoutMode
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height
            width: height
        }

        IconButton {
            visible: !layoutMode && !backend.showingFrequent
            anchors.right: ddbButton.left
            anchors.top: parent.top
            height: parent.height
            width: height
            icon: "qrc:/icons/bookshelf.svg"
            tooltip: "Show frequently used"
            color: "transparent"
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
        anchors.left: sugDivider.left
        anchors.right: sugDivider.right
        clip: true

        Tags {
            id: sugTagsList
            model: !layoutMode && !backend.showingFrequent ? backend.ddb : backend.frequent
            anchors.fill: parent
            moveEnabled: false

            function getOverlay(tag, index) {
                return backend.tags.includes(tag) ? "#77000000" : "#00000000"
            }

            onPressed: {
                searchTagsList.deselect()
                favTagsList.deselect()
                root.deselect()
            }

            onDoublePressed: {
                if(!backend.tags.includes(tag)) {
                    backend.addTag(tag)
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
        anchors.right: parent.right
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
        anchors.left: favDivider.left
        anchors.right: favDivider.right
        Text {
            text: "Favourites"
            font.pixelSize: 15
            leftPadding: 8
            rightPadding: 16
            font.bold: false
            color: "white"
            verticalAlignment: Text.AlignVCenter
            width: Math.min(parent.width, implicitWidth)
            elide: Text.ElideRight
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
        anchors.left: favDivider.left
        anchors.right: favDivider.right
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
                sugTagsList.deselect()
                root.deselect()
            }

            onDoublePressed: {
                if(!backend.tags.includes(tag)) {
                    backend.addTag(tag)
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
}