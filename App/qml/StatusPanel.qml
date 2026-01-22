import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15

Rectangle {
    id: root
    width: 280
    height: 139
    color: "#ffffff"
    radius: 8
    border.color: "#cccccc"
    border.width: 1

    // Professional gradient background
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#f5f5f5" }
        GradientStop { position: 0.5; color: "#e0e0e0" }
        GradientStop { position: 1.0; color: "#d5d5d5" }
    }

    // Professional data binding properties
    property real altitude: 0.0
    property real groundSpeed: 2.22
    property real yaw: 153.09
    property real vibration: 0.0
    property var languageManager: null
    
    // FIXED: Add dynamic flight mode property that updates from telemetry
    property string flightMode: droneModel.telemetry.mode || "UNKNOWN"

    // FIXED: Add connection to update when telemetry changes
    Connections {
        target: droneModel
        function onTelemetryChanged() {
            root.flightMode = droneModel.telemetry.mode || "UNKNOWN"
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 3

        // First row - Altitude and Ground Speed
        Row {
            width: parent.width
            spacing: 3

            Rectangle {
                width: (parent.width - 3) / 2
                height: 35
                color: "#f0f0f0"
                radius: 4
                border.color: "#cccccc"
                border.width: 1

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Text {
                        text: (languageManager ? languageManager.getText("AGL") : "AGL") + ":(" + (languageManager ? languageManager.getText("m") : "m") + ")"
                        color: "#ff0000"
                        font.pixelSize: 14
                        font.family: "Consolas"
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: altitude.toFixed(1)
                    color: "black"
                    font.pixelSize: 14
                    font.family: "Consolas"
                    font.weight: Font.Bold
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: (parent.width - 3) / 2
                height: 35
                color: "#f0f0f0"
                radius: 4
                border.color: "#cccccc"
                border.width: 1

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Text {
                        text: (languageManager ? languageManager.getText("Ground Speed") : "Ground Speed") + ":(" + (languageManager ? languageManager.getText("m/s") : "m/s") + ")"
                        color: "#ff0000"
                        font.pixelSize: 14
                        font.family: "Consolas"
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: groundSpeed.toFixed(2)
                    color: "black"
                    font.pixelSize: 14
                    font.family: "Consolas"
                    font.weight: Font.Bold
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Second row - Yaw and Vibration
        Row {
            width: parent.width
            spacing: 3

            Rectangle {
                width: (parent.width - 3) / 2
                height: 35
                color: "#f0f0f0"
                radius: 4
                border.color: "#cccccc"
                border.width: 1

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Text {
                        text: (languageManager ? languageManager.getText("Yaw") : "Yaw") + ":(" + (languageManager ? languageManager.getText("deg") : "deg") + ")"
                        color: "#ff0000"
                        font.pixelSize: 14
                        font.family: "Consolas"
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: yaw.toFixed(2)
                    color: "black"
                    font.pixelSize: 14
                    font.family: "Consolas"
                    font.weight: Font.Bold
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: (parent.width - 3) / 2
                height: 35
                color: "#f0f0f0"
                radius: 4
                border.color: "#cccccc"
                border.width: 1

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Text {
                        text: (languageManager ? languageManager.getText("Vibration") : "Vibration") + ":(" + (languageManager ? languageManager.getText("m/s²") : "m/s²") + ")"
                        color: "#ff0000"
                        font.pixelSize: 14
                        font.family: "Consolas"
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: vibration.toFixed(2)
                    color: "black"
                    font.pixelSize: 14
                    font.family: "Consolas"
                    font.weight: Font.Bold
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        
        
        // FIXED: 4th row for DYNAMIC flight mode
        Row {
            width: parent.width
            spacing: 3

            Rectangle {
                width: parent.width
                height: 35
                color: "#f0f0f0"
                radius: 4
                border.color: "#cccccc"
                border.width: 1

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Text {
                        text: (languageManager ? languageManager.getText("Flight Mode") : "Flight Mode")
                        color: "#ff0000"
                        font.pixelSize: 14
                        font.family: "Consolas"
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // FIXED: This now shows the ACTUAL current mode, not static "STABILIZE"
                Text {
                    text: {
                        var mode = root.flightMode
                        // Translate the mode if languageManager is available
                        return languageManager ? languageManager.getText(mode) : mode
                    }
                    color: "black"
                    font.pixelSize: 14
                    font.family: "Consolas"
                    font.weight: Font.Bold
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}