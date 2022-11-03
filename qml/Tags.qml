import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property var model
    property int selected: -1
    property bool moveEnabled: true
    property int index: 0

    signal pressed(string tag, int index)
    signal doublePressed(string tag, int index)
    signal moved(int from, int to)
    signal contextMenu(string tag, int index)

    property var tagColor: ["#0879f8", "#c00004", "#fff", "#c10cad", "#00ab2c", "#fd9200"]

    function tagAdded() {
        listView.positionViewAtEnd()
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

        if(selected != -1 && selected >= model.length) {
            selected = model.length-1
        }

        listView.forceLayout()

        listView.positionViewAtIndex(idx, ListView.Visible)
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
            root.moved(from, to)
            selected = to
        }
    }

    function moveUp() {
        if(selected > 0) {
            move(selected, selected-1)
            listView.positionViewAtIndex(selected,ListView.Contain)
        }
    }

    function moveDown() {
        if(selected != -1 && selected < model.length-1) {
            move(selected, selected+1)
            listView.positionViewAtIndex(selected,ListView.Contain)
        }
    }

    function selectEnter() {
        if(selected != -1) {
            root.doublePressed(model[selected], selected)
        }
    }

    function selectFirst() {
        if(model.length > 0) {
            selected = 0
            listView.positionViewAtBeginning()
        }
    }

    function selectDown() {
        if(selected == -1) {
            return;
        } else if(selected < model.length-1) {
            selected += 1
            listView.positionViewAtIndex(selected,ListView.Contain)
        }
    }
    
    function selectUp() {
        if(selected == -1) {
            return;
        } else if(selected > 0) {
            selected -= 1
            if(selected == 0) {
                listView.positionViewAtBeginning()
            } else {
                listView.positionViewAtIndex(selected,ListView.Contain)
            }
        }
    }

    Connections {
        target: backend
        function onListEvent(event) {
            if(backend.activeList != root.index) {
                root.selected = -1
                return
            }

            switch(event) {
            case -1:
                if(root.index == 0)
                    root.moveUp()
                else
                    root.selectUp()
                break;
            case 0:
                root.selectEnter()
                break;
            case 1:
                if(root.index == 0)
                    root.moveDown()
                else
                    root.selectDown()
                break;
            case 2:
                if(root.selected == -1) {
                    if(model.length > 0) {
                        root.selectFirst()
                    } else {
                        backend.doListEvent(3)
                    }
                }
                break;
            }
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
        signal hovered(int index)

        ScrollBar.vertical: ScrollBar {
            id: scrollBar
            stepSize: 1/(root.model.length)
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
                    color: favButton.visible ? "#353535" : "#2a2a2a"
                }

                Rectangle {
                    visible: favButton.visible
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
                    visible: false
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

                    onEntered: {
                        favButton.visible = true
                    }

                    onExited: {
                        favButton.visible = false
                    }

                    // favButton will miss mouse exit events when scrolling :/
                    Connections {
                        target: item

                        function onEntered() {
                            favButton.visible = true
                        }

                        function onExited() {
                            favButton.visible = false
                        }
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
                    color: backend.showingTagColors ? Qt.lighter(root.tagColor[backend.tagType(model.text)], 1.2) : "white"
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
                if(backend.activeList != root.index) {
                    backend.changeList(root.index)
                }
            }

            onContextMenu: {
                root.contextMenu(model.text, model.index)
            }

            onDoublePressed: {
                root.doublePressed(model.text, model.index)
            }
        }
    }
}