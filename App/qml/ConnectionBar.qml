import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.10

Rectangle {
    id: root
    height: 60
    color: "#ffffff"
    border.color: "#dee2e6"
    border.width: 2

    property bool showConnectButton: true
    property var calibrationWindow: null

    // Enhanced connection state properties
    property bool isConnected: droneModel ? droneModel.isConnected : false
    property bool isReconnecting: calibrationModel ? (calibrationModel.reconnectionAttempts > 0 && !calibrationModel.isDroneConnected) : false
    property bool autoReconnectEnabled: calibrationModel ? calibrationModel.autoReconnectEnabled : true
    property int reconnectionAttempts: calibrationModel ? calibrationModel.reconnectionAttempts : 0
    property var languageManager: null
    
    // Track popup open time for minimum display duration
    property real popupOpenTime: 0

    // Font properties
    readonly property string standardFontFamily: "Consolas"
    readonly property int standardFontSize: 16
    readonly property int standardFontWeight: Font.Bold

    // Signals
    signal connectionStateChanged(bool connected)
    signal parametersRequested()
    signal parametersReceived(var parameters)

    // 🔥 INSTANT POPUP - Always Created, Ready to Show
    Popup {
        id: connectionLoadingPopup
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        visible: false
        
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 400
        height: 300
        
        property string connectionString: ""
        property bool isConnecting: false
        property int dotsCount: 0
        
        background: Rectangle {
            color: "#ffffff"
            radius: 16
            border.color: "#dee2e6"
            border.width: 2
            
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 8
                radius: 16
                samples: 33
                color: "#40000000"
            }
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 30
            width: parent.width - 60
            
            Rectangle {
                width: 80
                height: 80
                radius: 40
                color: "#e3f2fd"
                anchors.horizontalCenter: parent.horizontalCenter
                
                Text {
                    anchors.centerIn: parent
                    text: "📡"
                    font.pixelSize: 40
                    
                    RotationAnimation on rotation {
                        running: connectionLoadingPopup.isConnecting
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 2000
                    }
                }
            }
            
            Column {
                width: parent.width
                spacing: 10
                
                Text {
                    width: parent.width
                    text: "Connecting to Drone"
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    font.family: "Consolas"
                    color: "#212529"
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    width: parent.width
                    text: "Please wait" + ".".repeat(connectionLoadingPopup.dotsCount)
                    font.pixelSize: 16
                    font.family: "Consolas"
                    color: "#6c757d"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            
            Rectangle {
                width: parent.width
                height: 60
                radius: 8
                color: "#f8f9fa"
                border.color: "#dee2e6"
                border.width: 1
                
                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    
                    Text {
                        text: "Connection String:"
                        font.pixelSize: 12
                        font.family: "Consolas"
                        color: "#6c757d"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        text: connectionLoadingPopup.connectionString
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        font.family: "Consolas"
                        color: "#0066cc"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
            
            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: "#e9ecef"
                
                Rectangle {
                    id: progressBar
                    height: parent.height
                    radius: parent.radius
                    color: "#0066cc"
                    width: 0
                    
                    SequentialAnimation on width {
                        running: connectionLoadingPopup.isConnecting
                        loops: Animation.Infinite
                        
                        NumberAnimation {
                            from: 0
                            to: progressBar.parent.width
                            duration: 1500
                            easing.type: Easing.InOutQuad
                        }
                        
                        NumberAnimation {
                            from: progressBar.parent.width
                            to: 0
                            duration: 1500
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
            
            Button {
                width: 120
                height: 40
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Cancel"
                
                background: Rectangle {
                    radius: 8
                    color: parent.pressed ? "#bd2130" : (parent.hovered ? "#c82333" : "#dc3545")
                    border.color: "#bd2130"
                    border.width: 1
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    font.family: "Consolas"
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    console.log("❌ Connection cancelled by user")
                    connectionLoadingPopup.isConnecting = false
                    
                    if (typeof droneModel !== 'undefined') {
                        droneModel.disconnectDrone()
                    }
                    
                    connectionLoadingPopup.close()
                }
            }
        }
        
        Timer {
            id: dotsTimer
            interval: 500
            running: connectionLoadingPopup.isConnecting
            repeat: true
            
            onTriggered: {
                connectionLoadingPopup.dotsCount = (connectionLoadingPopup.dotsCount + 1) % 4
            }
        }
        
        onOpened: {
            console.log("🔄 Loading popup OPENED")
            isConnecting = true
            dotsCount = 0
            dotsTimer.restart()
            root.popupOpenTime = Date.now()
        }
        
        onClosed: {
            console.log("ℹ️ Loading popup CLOSED")
            isConnecting = false
            dotsTimer.stop()
        }
    }

    // 🔥 INSTANT SHOW - Direct access to popup
    function showConnectionLoading(connectionStr) {
        console.log("🔄 showConnectionLoading called with:", connectionStr)
        connectionLoadingPopup.connectionString = connectionStr
        connectionLoadingPopup.open()
    }

    // 🔥 SMART HIDE - Minimum 1 second display
    function hideConnectionLoading() {
        console.log("ℹ️ hideConnectionLoading called")
        
        var elapsedTime = Date.now() - popupOpenTime
        var minimumDisplayTime = 1000  // 1 second minimum
        
        if (elapsedTime < minimumDisplayTime) {
            var remainingTime = minimumDisplayTime - elapsedTime
            console.log("⏰ Delaying popup close by", remainingTime, "ms for visibility")
            
            var delayTimer = Qt.createQmlObject(
                'import QtQuick 2.15; Timer { interval: ' + remainingTime + '; running: true; repeat: false }',
                root, "delayTimer"
            )
            delayTimer.triggered.connect(function() {
                console.log("✅ Closing loading popup (after minimum display time)")
                connectionLoadingPopup.close()
                delayTimer.destroy()
            })
        } else {
            console.log("✅ Closing loading popup immediately")
            connectionLoadingPopup.close()
        }
    }

    // [REST OF YOUR CODE - All calibration functions, etc.]
    function openAccelCalibration() {
        console.log("Opening AccelCalibration.qml...")
        if (root.calibrationWindow) {
            root.calibrationWindow.close()
            root.calibrationWindow = null
        }
        var component = Qt.createComponent("AccelCalibration.qml")
        if (component.status === Component.Ready) {
            root.calibrationWindow = component.createObject(null, {
                "calibrationModel": calibrationModel
            })
            if (root.calibrationWindow) {
                root.calibrationWindow.closing.connect(function() {
                    root.calibrationWindow = null
                })
                root.calibrationWindow.show()
            }
        }
    }

    function openESCCalibration() {
        if (!root.isConnected) return
        if (root.calibrationWindow) {
            root.calibrationWindow.close()
            root.calibrationWindow = null
        }
        var component = Qt.createComponent("esc_calibration.qml")
        if (component.status === Component.Ready) {
            root.calibrationWindow = component.createObject(null, {
                "droneModel": droneModel,
                "droneCommander": droneCommander,
                "escCalibrationModel": escCalibrationModel
            })
            if (root.calibrationWindow) {
                if (root.calibrationWindow.closing) {
                    root.calibrationWindow.closing.connect(function() {
                        root.calibrationWindow = null
                    })
                }
                root.calibrationWindow.show()
            }
        }
    }

    function openRadioCalibration() {
        if (!root.isConnected) return
        if (root.calibrationWindow) {
            root.calibrationWindow.close()
            root.calibrationWindow = null
        }
        var component = Qt.createComponent("radio.qml")
        if (component.status === Component.Ready) {
            root.calibrationWindow = component.createObject(null, {
                "radioCalibrationModel": radioCalibrationModel
            })
            if (root.calibrationWindow) {
                root.calibrationWindow.closing.connect(function() {
                    root.calibrationWindow = null
                })
                root.calibrationWindow.show()
            }
        }
    }

    function openCompassCalibration() {
        if (!root.isConnected) return
        if (root.calibrationWindow) {
            root.calibrationWindow.close()
            root.calibrationWindow = null
        }
        var component = Qt.createComponent("compass.qml")
        if (component.status === Component.Ready) {
            root.calibrationWindow = component.createObject(null, {
                "compassCalibrationModel": compassCalibrationModel,
                "droneModel": droneModel,
                "droneCommander": droneCommander
            })
            if (root.calibrationWindow) {
                if (root.calibrationWindow.closing) {
                    root.calibrationWindow.closing.connect(function() {
                        root.calibrationWindow = null
                    })
                }
                root.calibrationWindow.show()
            }
        }
    }

    function addCustomConnection(connectionString) {
        for (let i = 0; i < portModel.count; i++) {
            if (portModel.get(i).port === connectionString) {
                portSelector.currentIndex = i
                connectionStringInput.text = ""
                return
            }
        }
        const customId = "custom-" + Math.random().toString(36).substring(2, 8)
        portModel.append({ 
            id: customId, 
            port: connectionString, 
            display: "Custom (" + connectionString + ")" 
        })
        portSelector.currentIndex = portModel.count - 1
        connectionStringInput.text = ""
    }

    // Connection monitoring
    Connections {
        target: droneModel
        function onIsConnectedChanged() {
            root.isConnected = droneModel.isConnected
            root.connectionStateChanged(root.isConnected)
            
            if (root.isConnected) {
                console.log("✅ Connection successful - hiding loading popup")
                root.hideConnectionLoading()
            } else {
                console.log("❌ Connection failed/disconnected - hiding loading popup")
                root.hideConnectionLoading()
            }
            
            if (root.isConnected && calibrationModel) {
                if (droneModel.current_connection_string) {
                    console.log("Storing connection info:", droneModel.current_connection_string)
                }
            }
        }
    }

    Connections {
        target: calibrationModel
        function onCalibrationStatusChanged() {
            root.isReconnecting = (calibrationModel.reconnectionAttempts > 0 && !calibrationModel.isDroneConnected)
            root.reconnectionAttempts = calibrationModel.reconnectionAttempts
            root.autoReconnectEnabled = calibrationModel.autoReconnectEnabled
        }
    }

    Connections {
        target: droneCommander
        function onParametersUpdated(parameters) {
            root.parametersReceived(parameters)
        }
    }

    // Bottom accent line
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 3
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#0066cc" }
            GradientStop { position: 0.5; color: "#28a745" }
            GradientStop { position: 1.0; color: "#17a2b8" }
        }
        opacity: 0.8
    }

    // Main UI
    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 25
        spacing: 15
        
        ComboBox {
            id: portSelector
            width: 140
            height: 40
            model: ListModel { id: portModel }
            property var selectedPort: portModel.get(currentIndex)
            
            background: Rectangle {
                radius: 8
                border.color: portSelector.activeFocus ? "#4a90e2" : "#e0e0e0"
                border.width: portSelector.activeFocus ? 2 : 1
                color: (portSelector.currentIndex >= 0) ? "#add8e6" : "#f8fbff"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: (portSelector.currentIndex >= 0) ? "#b8dff0" : "#ffffff" }
                    GradientStop { position: 1.0; color: (portSelector.currentIndex >= 0) ? "#9dd0e6" : "#f0f8ff" }
                }
            }
            
            contentItem: Text {
                text: {
                    if (portSelector.currentIndex >= 0 && portSelector.currentIndex < portModel.count) {
                        return portModel.get(portSelector.currentIndex).display
                    }
                    return "Select Port"
                }
                font.pixelSize: root.standardFontSize
                font.family: root.standardFontFamily
                font.weight: Font.Medium
                color: (portSelector.currentIndex >= 0) ? "#2c3e50" : "#7f8c8d"
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                clip: true
                leftPadding: 12
                rightPadding: 35
            }
            
            delegate: ItemDelegate {
                width: portSelector.width
                height: 38
                background: Rectangle {
                    color: {
                        if (parent.pressed) return "#5a9fd4"
                        if (parent.hovered) return "#87ceeb"
                        return "transparent"
                    }
                    radius: 4
                }
                contentItem: Text {
                    text: model.display
                    color: {
                        if (parent.pressed) return "#ffffff"
                        if (parent.hovered) return "#ffffff"
                        return "#2c3e50"
                    }
                    font.pixelSize: root.standardFontSize
                    font.family: root.standardFontFamily
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    leftPadding: 12
                }
                onClicked: {
                    portSelector.currentIndex = index
                    portSelector.popup.close()
                }
            }
        }

        Rectangle {
            id: connectionStringContainer
            width: 200
            height: 40
            radius: 10
            color: "#f8f9fa"
            border.color: connectionStringInput.activeFocus ? "#0066cc" : "#dee2e6"
            border.width: 2

            TextInput {
                id: connectionStringInput
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                font.pixelSize: root.standardFontSize
                font.family: root.standardFontFamily
                color: "#212529"
                verticalAlignment: Text.AlignVCenter
                selectByMouse: true
                clip: true
                
                Text {
                    anchors.fill: parent
                    text: "Enter connection string..."
                    font.pixelSize: root.standardFontSize
                    font.family: root.standardFontFamily
                    color: "#6c757d"
                    verticalAlignment: Text.AlignVCenter
                    visible: !connectionStringInput.text && !connectionStringInput.activeFocus
                }
            }
        }

Button {
    id: toggleConnectBtn
    visible: showConnectButton
    text: {
        if (isReconnecting) {
            return "Reconnecting..."
        } else {
            return languageManager ? languageManager.getText(root.isConnected ? "DISCONNECT" : "CONNECT") : 
                (root.isConnected ? "DISCONNECT" : "CONNECT")
        }
    }
    width: 130
    height: 40
    enabled: !isReconnecting

    onClicked: {
        if (!root.isConnected) {
            // ========== CONNECT LOGIC ==========
            let connectionString = ""
            let connectionId = ""
            
            if (connectionStringInput.text.trim() !== "") {
                connectionString = connectionStringInput.text.trim()
                connectionId = "custom-" + Math.random().toString(36).substring(2, 8)
            } else {
                const selectedPort = portSelector.selectedPort
                if (selectedPort) {
                    connectionString = selectedPort.port
                    connectionId = selectedPort.id
                }
            }
            
            if (connectionString) {
                console.log("🔌 CONNECTING to:", connectionId, connectionString)
                
                // 🔥 SHOW LOADING POPUP FIRST - BEFORE ANY BLOCKING OPERATIONS
                root.showConnectionLoading(connectionString)
                
                // Force UI update before calling blocking Python code
                Qt.callLater(function() {
                    droneModel.current_connection_string = connectionString
                    droneModel.current_connection_id = connectionId
                    
                    // This call might block - but popup is already showing
                    droneModel.connectToDrone(connectionId, connectionString, 57600)
                })
            } else {
                console.log("⚠️ No connection string provided")
            }
            
        } else {
            // ========== DISCONNECT LOGIC ==========
            console.log("🔌 DISCONNECTING from drone...")
            
            // Disable auto-reconnect first (with safety check)
            if (typeof calibrationModel !== 'undefined' && calibrationModel !== null) {
                if (typeof calibrationModel.disableAutoReconnect === 'function') {
                    try {
                        calibrationModel.disableAutoReconnect()
                        console.log("✅ Auto-reconnect disabled")
                    } catch (e) {
                        console.log("⚠️ Could not disable auto-reconnect:", e)
                    }
                } else {
                    console.log("ℹ️ disableAutoReconnect method not available")
                }
            } else {
                console.log("ℹ️ calibrationModel not available")
            }
            
            // Disconnect immediately (Python will emit signal to update UI)
            if (typeof droneModel !== 'undefined' && droneModel !== null) {
                if (typeof droneModel.disconnectDrone === 'function') {
                    droneModel.disconnectDrone()
                    console.log("✅ Disconnect command sent to Python")
                } else {
                    console.log("❌ droneModel.disconnectDrone not available")
                }
            } else {
                console.log("❌ droneModel not available")
            }
        }
    }

    background: Rectangle {
        radius: 10
        border.width: 2
        border.color: {
            if (isReconnecting) return "#ffc107"
            else if (root.isConnected) {
                return toggleConnectBtn.pressed ? "#a71d2a" : "#dc3545"
            } else {
                return toggleConnectBtn.pressed ? "#1e7e34" : "#28a745"
            }
        }
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: {
                    if (isReconnecting) return "#ffc107"
                    else if (root.isConnected) {
                        return toggleConnectBtn.pressed ? "#a71d2a" : (toggleConnectBtn.hovered ? "#bd2130" : "#dc3545")
                    } else {
                        return toggleConnectBtn.pressed ? "#1e7e34" : (toggleConnectBtn.hovered ? "#218838" : "#28a745")
                    }
                }
            }
            GradientStop {
                position: 1.0
                color: {
                    if (isReconnecting) return "#e0a800"
                    else if (root.isConnected) {
                        return toggleConnectBtn.pressed ? "#7f1d1d" : (toggleConnectBtn.hovered ? "#a71d2a" : "#bd2130")
                    } else {
                        return toggleConnectBtn.pressed ? "#155d27" : (toggleConnectBtn.hovered ? "#1e7e34" : "#218838")
                    }
                }
            }
        }
    }
    contentItem: Text {
        text: toggleConnectBtn.text
        font.pixelSize: root.standardFontSize
        font.family: root.standardFontFamily
        font.weight: root.standardFontWeight
        color: "#ffffff"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}

        ComboBox {
            id: calibrationSelector
            width: 120
            height: 40
            enabled: root.isConnected
            model: ListModel {
                ListElement { text: "🔧 Accel"; value: 1 }
                ListElement { text: "🧭 Compass"; value: 2 }
                ListElement { text: "📻 Radio"; value: 3 }
                ListElement { text: "⚡ ESC"; value: 4 }
            }
            textRole: "text"
            currentIndex: -1
            displayText: "Calibrate"

            onActivated: function(index) {
                var selectedValue = model.get(index).value
                Qt.callLater(function() { calibrationSelector.currentIndex = -1 })
                if (selectedValue === 1) root.openAccelCalibration()
                else if (selectedValue === 2) root.openCompassCalibration()
                else if (selectedValue === 3) root.openRadioCalibration()
                else if (selectedValue === 4) root.openESCCalibration()
            }

            background: Rectangle {
                radius: 10
                border.width: 2
                border.color: enabled ? (calibrationSelector.pressed ? "#4a90e2" : "#87ceeb") : "#adb5bd"
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: enabled ? (calibrationSelector.pressed ? "#4a90e2" : (calibrationSelector.hovered ? "#7bb3e0" : "#87ceeb")) : "#adb5bd"
                    }
                    GradientStop {
                        position: 1.0
                        color: enabled ? (calibrationSelector.pressed ? "#357abd" : (calibrationSelector.hovered ? "#4a90e2" : "#7bb3e0")) : "#868e96"
                    }
                }
            }
            contentItem: Text {
                text: calibrationSelector.displayText
                font.pixelSize: root.standardFontSize
                font.family: root.standardFontFamily
                font.weight: root.standardFontWeight
                color: enabled ? "#2c5282" : "#6c757d"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            delegate: ItemDelegate {
                width: calibrationSelector.width
                height: 35
                background: Rectangle {
                    color: parent.hovered ? "#4CAF50" : "#ffffff"
                    radius: 4
                }
                contentItem: Text {
                    text: model.text
                    color: parent.hovered ? "#ffffff" : "#000000"
                    font.pixelSize: root.standardFontSize
                    font.family: root.standardFontFamily
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
                onClicked: {
                    calibrationSelector.activated(index)
                    calibrationSelector.popup.close()
                }
            }
        }

        ComboBox {
            id: languageSelector
            width: 120
            height: 40
            model: ["English", "हिंदी", "தமிழ்", "తెలుగు"]
            currentIndex: 0
            property var languageCodes: ["en", "hi", "ta", "te"]
            onCurrentIndexChanged: {
                if (languageManager) {
                    languageManager.changeLanguage(languageCodes[currentIndex])
                }
            }
            background: Rectangle {
                radius: 10
                border.width: 2
                border.color: enabled ? (languageSelector.pressed ? "#4a90e2" : "#87ceeb") : "#adb5bd"
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: enabled ? (languageSelector.pressed ? "#4a90e2" : (languageSelector.hovered ? "#7bb3e0" : "#87ceeb")) : "#adb5bd"
                    }
                    GradientStop {
                        position: 1.0
                        color: enabled ? (languageSelector.pressed ? "#357abd" : (languageSelector.hovered ? "#4a90e2" : "#7bb3e0")) : "#868e96"
                    }
                }
            }
            contentItem: Text {
                text: languageSelector.displayText
                font.pixelSize: root.standardFontSize
                font.family: root.standardFontFamily
                font.weight: root.standardFontWeight
                color: enabled ? "#2c5282" : "#6c757d"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            delegate: ItemDelegate {
                width: languageSelector.width
                height: 35
                background: Rectangle {
                    color: parent.hovered ? "#4CAF50" : "#ffffff"
                    radius: 4
                }
                contentItem: Text {
                    text: modelData
                    color: parent.hovered ? "#ffffff" : "#000000"
                    font.pixelSize: root.standardFontSize
                    font.family: root.standardFontFamily
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
                onClicked: {
                    languageSelector.currentIndex = index
                    languageSelector.popup.close()
                }
            }
        }
    }

    // Logo container
    Item {
        id: logoContainer
        width: 120
        height: 50
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 25

        Image {
            id: logoImage
            anchors.centerIn: parent
            width: 100
            height: 40
            source: "../images/tihan.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            antialiasing: true

            onStatusChanged: {
                if (status === Image.Error) {
                    console.log("Failed to load image from:", source)
                } else if (status === Image.Ready) {
                    console.log("Successfully loaded image from:", source)
                }
            }

            Text {
                anchors.centerIn: parent
                text: "TIHAN FLY"
                color: "#0066cc"
                font.pixelSize: root.standardFontSize
                font.family: root.standardFontFamily
                font.weight: root.standardFontWeight
                visible: logoImage.status !== Image.Ready
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                onEntered: { logoImage.scale = 1.05 }
                onExited: { logoImage.scale = 1.0 }

                onClicked: {
                    var component = Qt.createComponent("AboutTihan.qml");
                    if (component.status === Component.Ready) {
                        var window = component.createObject(null);
                        window.show();
                    } else if (component.status === Component.Error) {
                        console.log("Error loading AboutTihan.qml:", component.errorString());
                    }
                }
            }

            Behavior on scale {
                NumberAnimation { duration: 200 }
            }
        }
    }

    Component.onCompleted: {
        portModel.clear();
        const sitlPort = "udp:127.0.0.1:14550";
        const randomId = "sitl-" + Math.random().toString(36).substring(2, 8);
        portModel.append({ id: randomId, port: sitlPort, display: "SITL (" + sitlPort + ")" });

        const availablePorts = portManager.getAvailablePorts();
        for (let i = 0; i < availablePorts.length; ++i) {
            const port = availablePorts[i];
            if (port !== sitlPort) {
                portModel.append({ id: "port-" + i, port: port, display: port });
            }
        }

        portSelector.currentIndex = 0;
        
        if (calibrationModel) {
            calibrationModel.enableAutoReconnect();
        }
    }

    Component.onDestruction: {
        if (root.calibrationWindow) {
            root.calibrationWindow.close();
            root.calibrationWindow = null;
        }
    }
}