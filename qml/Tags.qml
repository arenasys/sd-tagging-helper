import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property var model
    property int selected: -1
    property bool moveEnabled: true

    signal pressed(string tag, int index)
    signal doublePressed(string tag, int index)
    signal moved(int from, int to)
    signal contextMenu(string tag, int index)

    function deselect() {
        selected = -1
    }

    ListModel {
        id: listModel
        Component.onCompleted: {
            populate()
        }
    }

    function populate() {
        var idx = listView.indexAt(listView.contentX,listView.contentY)

        for(var i = 0; i < model.length; i++) {
            if(i >= listModel.count) {
                listModel.append({"text": model[i]})
                continue
            }
            if(listModel.get(i).text == model[i]) {
                continue
            }
            listModel.insert(i, {"text": model[i]})
        }

        if(listModel.count > model.length) {
            listModel.remove(model.length, listModel.count-model.length)
        }

        listView.forceLayout()

        listView.positionViewAtIndex(idx, ListView.Contain)
    }

    Connections {
        target: backend
        function onUpdated() {
            populate()
        }
    }

    function remove(i) {
        listModel.remove(i,1)
        selected = -1
    }

    function add(tag) {
        listModel.append({"text": tag})
        listView.positionViewAtEnd()
    }

    function move(from, to) {
        if(moveEnabled) {
            listModel.move(from, to, 1)
            moved(from, to)
            selected = to
        }
    }

    function up() {
        if(selected > 0) {
            move(selected, selected-1)
            listView.positionViewAtIndex(selected,ListView.Contain)
        }
    }

    function down() {
        if(selected != -1 && selected < model.length-1) {
            move(selected, selected+1)
            listView.positionViewAtIndex(selected,ListView.Contain)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: {
            if(wheel.angleDelta.y > 0) {
                scrollBar.decrease()
            } else {
                scrollBar.increase()
            }
        }
    }

    ListView {
        anchors.fill: parent
        id: listView
        model: listModel
        interactive: false

        ScrollBar.vertical: ScrollBar {
            id: scrollBar
            stepSize: 1/root.model.length
        }

        spacing: 3
        header: Item {
            height: 7
        }
        footer: Item {
            height: 7
        }

        delegate: DraggableItem {
            id: item
            property bool isDouble: false

            Item {
                height: 20
                width: listView.width

                Rectangle {
                    color: model.index == root.selected ? "#1c1c1c" : "transparent"
                    anchors.fill: parent
                    anchors.margins: -3
                }

                Item {
                    id:  padding
                    width: 5
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }

                Rectangle {
                    id: bg
                    x: textLabel.x
                    width: textLabel.contentWidth + 9
                    anchors.top: textLabel.top
                    anchors.bottom: textLabel.bottom
                    radius: 5
                    color: item.hovered || favButton.hovered ? "#353535" : "#2a2a2a"
                }

                Rectangle {
                    visible: item.hovered || favButton.hovered
                    id: favBg
                    anchors.left: bg.right
                    anchors.leftMargin: 5
                    anchors.top: textLabel.top
                    anchors.bottom: textLabel.bottom
                    width: height
                    radius: 5
                    color: "#2a2a2a"
                }

                IconButton {
                    z: 0
                    id: favButton
                    visible: favBg.visible
                    anchors.centerIn: favBg
                    height: parent.height*1.3
                    width: height
                    property var favourited: backend.favourites.includes(model.text)
                    icon: favourited ? "qrc:/icons/star.svg" : "qrc:/icons/star-outline.svg"
                    color: "transparent"
                    iconColor: favourited ? "#bd9d35" : "#606060"
                    iconHoverColor: favourited ? "#a98719" : "#fff"
                    onPressed: {
                        backend.toggleFavourite(model.text)
                    }
                }

                Text {
                    id: textLabel
                    anchors.left: padding.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom                    
                    width: favBg.visible ? parent.width - 30 : parent.width - 10
                    elide: Text.ElideRight
                    text: model.text
                    padding: 5
                    color: "white"
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    id: overlay
                    anchors.fill: bg
                    radius: 5
                    color: getOverlay(model.text, model.index)
                }
            }

            draggedItemParent: root

            onMoveItemRequested: {
                move(from, to)
            }

            onPressed: {
                root.selected = model.index
                root.pressed(model.text, model.index)
                item.isDouble = !item.isDouble
            }

            onContextMenu: {
                root.contextMenu(model.text, model.index)
            }

            onDoublePressed: {
                root.doublePressed(model.text, model.index)
            }

            onHoveredChanged: {
                if(!item.hovered) {
                    item.isDouble = false
                }
            }
        }
    }
}