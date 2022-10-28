import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    width: 10
    height: 10
    color: "#fff"
    border.width: 1
    border.color: "#000"
    anchors.leftMargin: -1
    anchors.topMargin: -1
    function contains(g) {
        g = mapFromGlobal(g)
        return g.x > 0 && g.x < width && g.y > 0 && g.y < height
    }
}