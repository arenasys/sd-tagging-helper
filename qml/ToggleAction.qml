import QtQuick 2.15
import QtQuick.Controls 2.15

Action {
    property var toggled
    checkable: true
    onToggledChanged: {
        checked = toggled
    }
    Component.onCompleted: {
        checked = toggled
    }
}