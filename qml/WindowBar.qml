import QtQuick 2.15
import QtQuick.Controls 2.15

TopMenuBar {
    id: root
    signal packageWindowOpen()
    signal changeLayout()
    signal changeCrop()
    signal interrogate()
    signal interrogateAll()
    signal save()

    property var altCropMode
    property var altLayoutMode

    TopMenu {
        id: menu
        title: "File"
        Action {
            text: "Load"
            onTriggered: {
                backend.doLoad()
            }
        }
        Action {
            text: "Package"
            onTriggered: {
                root.packageWindowOpen()
            }
        }
        TopMenu {
            title: "Configure"
            Action {
                text: "Staging Folder"
                onTriggered: {
                    backend.setStagingFolder()
                }
            }
            Action {
                text: "Output Folder"
                onTriggered: {
                    backend.setOutputFolder()
                }
            }
            TopMenu {
                id: dimMenu
                title: "Dimension"
                ToggleAction {
                    property var dim: 512
                    text: dim
                    toggled: backend.dimension == dim
                    onTriggered: {
                        backend.setDimension(dim)
                    }
                }
                ToggleAction {
                    property var dim: 576
                    text: dim
                    toggled: backend.dimension == dim
                    onTriggered: {
                        backend.setDimension(dim)
                    }
                }
                ToggleAction {
                    property var dim: 640
                    text: dim
                    toggled: backend.dimension == dim
                    onTriggered: {
                        backend.setDimension(dim)
                    }
                }
                ToggleAction {
                    property var dim: 704
                    text: dim
                    toggled: backend.dimension == dim
                    onTriggered: {
                        backend.setDimension(dim)
                    }
                }
                ToggleAction {
                    property var dim: 768
                    text: dim
                    toggled: backend.dimension == dim
                    onTriggered: {
                        backend.setDimension(dim)
                    }
                }
                ToggleAction {
                    property var dim: 832
                    text: dim
                    toggled: backend.dimension == dim
                    onTriggered: {
                        backend.setDimension(dim)
                    }
                }
                ToggleAction {
                    property var dim: 896
                    text: dim
                    toggled: backend.dimension == dim
                    onTriggered: {
                        backend.setDimension(dim)
                    }
                }
                ToggleAction {
                    property var dim: 960
                    text: dim
                    toggled: backend.dimension == dim
                    onTriggered: {
                        backend.setDimension(dim)
                    }
                }
                ToggleAction {
                    property var dim: 1024
                    text: dim
                    toggled: backend.dimension == dim
                    onTriggered: {
                        backend.setDimension(dim)
                    }
                }
            }
        }
    }
    TopMenu {
        title: "Edit"

        Action {
            text: "Save"
            onTriggered: {
                root.save()
            }
        }
        Action {
            text: "Undo"
            onTriggered: {
                backend.reset()
            }
        }
        TopMenu {
            id: positionMenu
            title: "Position Image"
            Action {
                text: "Center"
                onTriggered: {
                    backend.center()
                }
            }
            Action {
                text: "Contain"
                onTriggered: {
                    backend.contain()
                }
            }
        }
        TopMenu {
            id: tagsMenu
            title: "Tags"
            ToggleAction {
                id: appendTags
                text: "Append tags to start?"
                toggled: backend.prefixingTags
                onTriggered: {
                    backend.setPrefixingTags(checked)
                }
            }
            Action {
                text: "Sort by popularity"
                onTriggered: {
                    backend.sortTags()
                }
            }
            Action {
                text: "Remove unknown"
                onTriggered: {
                    backend.cleanTags()
                }
            }
        }
        TopMenu {
            id: intMenu
            title: "Interrogate"

            Action {
                text: "Interrogate"
                onTriggered: {
                    root.interrogate()
                }
            }
            Action {
                text: "Interrogate All"
                onTriggered: {
                    root.interrogateAll()
                }
            }
            ToggleAction {
                id: addDDBTags
                text: "Add found tags?"
                checkable: true
                toggled: backend.ddbIsAdding
                onTriggered: {
                    backend.ddbSetAdding(checked)
                }
            } 
        }
    }
    TopMenu {
        title: "View"

        ToggleAction {
            text: "Alternate layout"
            checkable: true
            toggled: root.altLayoutMode
            onTriggered: {
                root.changeLayout()
            }
        }
        ToggleAction {
            text: "Alternate cropping mode"
            checkable: true
            toggled: root.altCropMode
            onTriggered: {
                root.changeCrop()
            }
        }
        ToggleAction {
            text: "Show global"
            checkable: true
            toggled: backend.showingGlobal
            onTriggered: {
                backend.toggleGlobal()
            }
        }
        ToggleAction {
            text: "Show tag colors"
            checkable: true
            toggled: backend.showingTagColors
            onTriggered: {
                backend.toggleTagColors()
            }
        }
    }
    TopMenu {
        title: "Help"
        Action {
            text: "Project page"        
            onTriggered: {
                backend.openProjectPage()
            }
        }
        Action {
            text: "Update"        
            onTriggered: {
                backend.update()
            }
        }
    }
}