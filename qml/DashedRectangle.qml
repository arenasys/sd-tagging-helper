import QtQuick 2.14
import QtQuick.Shapes 1.12
Shape {
    id: shape
    property var radius: 0
    property var strokeWidth: 1
    property var dashLength: 4
    property var dashOffset: 0

    RotationAnimation on dashOffset {
        duration: 2000
        loops: Animation.Infinite
        from: 0
        to: 2*dashLength
    }

    ShapePath {
        strokeColor: "black"
        strokeWidth: shape.strokeWidth
        fillColor: 'transparent'
        strokeStyle: ShapePath.DashLine
        dashPattern: [dashLength, dashLength]
        dashOffset: shape.dashOffset

        startX: radius
        startY: 0
        PathLine {
            x: shape.width
            y: 0
        }
        PathLine {
            x: shape.width
            y: shape.height
        }
        PathLine {
            x: 0
            y: shape.height
        }
        PathLine {
            x: 0
            y: 0
        }
    }
    ShapePath {
        strokeColor: "white"
        strokeWidth: shape.strokeWidth
        fillColor: 'transparent'
        strokeStyle: ShapePath.DashLine
        dashPattern: [dashLength, dashLength]
        dashOffset: dashLength + shape.dashOffset

        startX: radius
        startY: 0
        PathLine {
            x: shape.width
            y: 0
        }
        PathLine {
            x: shape.width
            y: shape.height
        }
        PathLine {
            x: 0
            y: shape.height
        }
        PathLine {
            x: 0
            y: 0
        }
    }
}