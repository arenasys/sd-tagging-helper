import QtQuick 2.15
import QtQuick.Controls 2.15

ToolTip {
    id: control
    font.pointSize: 10
    contentItem: UniformText {

        text: control.text
        font: control.font
        color: "white"
    }

    background: Rectangle {
        color: "#c0000000"
    }
}
