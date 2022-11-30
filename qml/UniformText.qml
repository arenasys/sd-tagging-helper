import QtQuick 2.15
import QtQuick.Controls 2.15

Text {
    FontLoader {
        source: "qrc:/fonts/Cantarell-Regular.ttf"
    }
    FontLoader {
        source: "qrc:/fonts/Cantarell-Bold.ttf"
    }
    font.family: "Cantarell"
    font.pointSize: 10.8

    Component.onCompleted: {
        if(font.bold) {
            font.letterSpacing = -1.0
        }
    }
}