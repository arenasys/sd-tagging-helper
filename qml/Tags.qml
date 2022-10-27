import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property int active
    property var model
    property var highlight
    property int selected: -1

    signal pressed(string tag, int index)
    signal doublePressed(string tag, int index)
    signal moved(int from, int to)

    ListModel {
        id: listModel
        Component.onCompleted: {
            populate()
        }
    }

    function populate() {
        listModel.clear()
        selected = -1
        listView.contentY = -6
        for(var i = 0; i < model.length; i++) {
            listModel.append({"text": model[i]});
        }
    }

    onActiveChanged: {
        populate()
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
        listModel.move(from, to, 1)
        moved(from, to)
        selected = to
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
                if(listView.contentY > 0) {
                    listView.contentY -= 23
                }
            } else {
                if(listView.contentY+listView.height < 23*listView.count) {
                    listView.contentY += 23
                }
            }

        }
    }

    ListView {
        anchors.fill: parent
        id: listView
        model: listModel
        interactive: false

        ScrollBar.vertical: ScrollBar {    }

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
                    color: item.hovered ? "#353535" : "#2a2a2a"
                }

                Text {
                    id: textLabel
                    anchors.left: padding.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom                    
                    width: parent.width - 10
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