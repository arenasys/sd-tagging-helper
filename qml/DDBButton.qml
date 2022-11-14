import QtQuick 2.15
import QtQuick.Controls 2.15

IconButton {
    icon: "qrc:/icons/brain.svg"
    property int s: backend.ddbStatus
    id: ddbButton

    tooltip: {
        if(s == -2)
            return "Load DeepDanbooru?"
        if(s == -1)
            return "Loading..."
        if(s == 0)
            return "Interrogate via DeepDanbooru"
        if(s == 1)
            return "Interrogating..."
        return "Interrogating " + String(s-1) + " of " + String(backend.total)
        
    }
    color: "transparent"
    iconColor: s <= -1 ? "#424242" : (s > 0 ?  "#83aaf2" : "#516a98")
    iconHoverColor: s <= -1 ? "#424242" : "#5d91f0"
    working: backend.ddbStatus > 0
    glowing: backend.ddbStatus > 0
    glowColor: "#99437be0"
    glowStrength: 10
    onPressed: {
        save()
        backend.ddbInterrogate()
    }
    onContextMenu: {
        allContextMenu.popup()
    }

    ContextMenu {
        id: allContextMenu

        Action {
            text: "Interrogate All?"
            onTriggered: {
                backend.ddbInterrogateAll(false)
            }
        }

        Action {
            id: addFound
            text: "Add found tags?" 

            checkable: true
            
            onCheckedChanged: {
                backend.ddbSetAdding(checked)
                checked = backend.ddbIsAdding
            }

            Component.onCompleted: {
                checked: backend.ddbIsAdding
            }
        }

        onClosed: {
            keyboardFocus.forceActiveFocus()
        }
    }
}