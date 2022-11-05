import QtQuick 2.15
import QtQuick.Controls 2.15

BusyIndicator {
    id: control
    implicitWidth: 64
    implicitHeight: 64

    contentItem: Item {
        implicitWidth: control.width
        implicitHeight: control.width

        Item {
            id: item
            x: parent.width / 2 - control.width/2
            y: parent.height / 2 - control.width/2
            width: control.width
            height: control.width
            opacity: control.running ? 1 : 0

            Behavior on opacity {
                OpacityAnimator {
                    duration: 250
                }
            }

            RotationAnimator {
                target: item
                running: control.visible && control.running
                from: 0
                to: 360
                loops: Animation.Infinite
                duration: 1250
            }

            Repeater {
                id: repeater
                model: 6

                Rectangle {
                    id: delegate
                    x: item.width / 2 - width / 2
                    y: item.height / 2 - height / 2
                    implicitWidth: control.width/8
                    implicitHeight: control.width/8
                    radius: 5
                    color: "#ffffff"
                    opacity: 0.5

                    required property int index

                    transform: [
                        Translate {
                            y: -Math.min(item.width, item.height) * 0.5 + 5
                        },
                        Rotation {
                            angle: delegate.index / repeater.count * 360
                            origin.x: control.width/12
                            origin.y: control.width/12
                        }
                    ]
                }
            }
        }
    }
}
