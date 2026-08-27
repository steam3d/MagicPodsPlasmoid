import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.components as PC3
import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import QtWebSockets
import "." as Local
//import "mockData.js" as MockData

PlasmoidItem {
    id: root
    property var infoData: ({})
    property var btAdapterData: ({})
    property var headphonesData: []
    readonly property var sortedHeadphones: hasHeadphones
        ? headphonesData.slice().sort(function(a, b) { return (a.name || "").localeCompare(b.name || ""); })
        : []
    readonly property bool hasInfo: infoData && Object.keys(infoData).length > 0
    readonly property bool hasHeadphones: infoData && Object.keys(headphonesData).length > 0
    readonly property var capabilities: infoData?.capabilities ?? null
    readonly property var batteryData: capabilities?.battery ?? null
    readonly property var ancData: capabilities?.anc ?? null
    readonly property var conversationAwarenessData: capabilities?.conversationAwareness ?? null
    readonly property var personalizedVolumeData: capabilities?.personalizedVolume ?? null
    readonly property var ancOneAirPodData: capabilities?.ancOneAirPod ?? null
    readonly property var volumeSwipeData: capabilities?.volumeSwipe ?? null
    readonly property var adaptiveAudioNoiseData: capabilities?.adaptiveAudioNoise ?? null
    readonly property var pressAndHoldDurationData: capabilities?.pressAndHoldDuration ?? null
    readonly property var pressSpeedData: capabilities?.pressSpeed ?? null
    readonly property var toneVolumeData: capabilities?.toneVolume ?? null
    readonly property var volumeSwipeLengthData: capabilities?.volumeSwipeLength ?? null
    readonly property var endCallData: capabilities?.endCall ?? null
    readonly property var bluetoothCodec: capabilities?.bluetoothCodec ?? null
    readonly property bool backendConnected: backend.socketState === WebSocket.Open
    readonly property bool hasConnectedDevice: backendConnected && hasInfo
    property int selectedAnc: ancData?.selected ?? 0
    readonly property var ancModes: ({ OFF: 1, TRANSPARENCY: 2, ADAPTIVE: 4, WIND: 8, ANC: 16 })
    function currentAddress() { return infoData?.address }



    Local.Backend {
        id: backend
        active: true
        onDataReceived: json => {

            //json = MockData.data2

            if (json?.info) {
                root.infoData = json.info
                root.selectedAnc = json.info?.capabilities?.anc?.selected ?? root.selectedAnc
            }
            if (json?.defaultbluetooth) {
                root.btAdapterData = json.defaultbluetooth
            }
            if (json?.headphones) {
                root.headphonesData = json.headphones
            }
        }
    }

    function batteryAvailable(status) { return status === 2 || status === 3 }
    readonly property int trayBattery: {
        if (!batteryData) return 0
        if (batteryAvailable(batteryData?.single?.status)) return batteryData.single.battery ?? 0
        const left = batteryAvailable(batteryData?.left?.status)
        const right = batteryAvailable(batteryData?.right?.status)
        if (left && right) return Math.round(((batteryData.left.battery ?? 0) + (batteryData.right.battery ?? 0)) / 2)
        if (left) return batteryData.left.battery ?? 0
        if (right) return batteryData.right.battery ?? 0
        return 0
    }
    readonly property int trayBatteryCapped: Math.min(99, trayBattery)
    readonly property string trayTooltip: {
        if (!batteryData) {
            return Local.Texts.disconnected
        }
        var parts = []
        if (batteryAvailable(batteryData?.single?.status)) parts.push("%1: %2%".arg(Local.Texts.battery_single).arg(batteryData.single.battery ?? 0))
        if (batteryAvailable(batteryData?.left?.status)) parts.push("%1: %2%".arg(Local.Texts.battery_left).arg(batteryData.left.battery ?? 0))
        if (batteryAvailable(batteryData?.right?.status)) parts.push("%1: %2%".arg(Local.Texts.battery_right).arg(batteryData.right.battery ?? 0))
        if (batteryAvailable(batteryData?.case?.status)) parts.push("%1: %2%".arg(Local.Texts.battery_case).arg(batteryData.case.battery ?? 0))
        return parts.length ? parts.join(" ") : Local.Texts.disconnected
    }
    toolTipMainText: Plasmoid.title && Plasmoid.title.length ? Plasmoid.title : qsTr("MagicPods")
    toolTipSubText: trayTooltip
    toolTipTextFormat: Text.PlainText
    Plasmoid.status: hasConnectedDevice ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus


    compactRepresentation: MouseArea {
        id: compactButton
        implicitWidth: PlasmaCore.Units.iconSizes.medium
        implicitHeight: implicitWidth
        onClicked: root.expanded = !root.expanded
        hoverEnabled: true

        Item {
            anchors.fill: parent

            Kirigami.Icon {
                anchors.fill: parent
                visible: root.batteryData === null
                source: Qt.resolvedUrl("../icons/logo.svg")
            }

            PlasmaComponents.Label {
                anchors.centerIn: parent
                visible: root.batteryData !== null
                text: root.trayBatteryCapped
                font.family: "monospace"
                font.pixelSize: 20
                color: Kirigami.Theme.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        id: dialog
        collapseMarginsHint: true
        focus: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 24
        Layout.minimumHeight: Kirigami.Units.gridUnit * 24
        Layout.maximumWidth: Kirigami.Units.gridUnit * 80
        Layout.maximumHeight: Kirigami.Units.gridUnit * 40
        property int currentTab: 0

        header: PlasmaExtras.PlasmoidHeading {
            rightPadding: -1
            bottomPadding: -bottomInset

            ColumnLayout {
                id: headerLayout
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading {
                        level: 1
                        text: Plasmoid.title && Plasmoid.title.length ? Plasmoid.title : i18n("MagicPods")
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: Kirigami.Units.smallSpacing * 2
                    }

                    Item { Layout.fillWidth: true }

                    PlasmaComponents.ToolButton {
                        id: burgerButton
                        icon.name: "application-menu"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        flat: true
                        onClicked: burgerMenu.popup(burgerButton)

                        PlasmaComponents.ToolTip {
                            text: Local.Texts.menu
                            visible: parent.hovered
                        }
                    }

                    PlasmaComponents.Menu {
                        id: burgerMenu

                        PlasmaComponents.MenuItem {
                            text: Local.Texts.menu_home
                            onTriggered: Qt.openUrlExternally("https://magicpods.app")
                        }
                        PlasmaComponents.MenuItem {
                            text: Local.Texts.menu_issue
                            onTriggered: Qt.openUrlExternally("https://github.com/steam3d/MagicPodsPlasmoid/issues")
                        }

                        PlasmaComponents.MenuItem {
                            text: Local.Texts.menu_donate
                            onTriggered: Qt.openUrlExternally("https://magicpods.app/donate")
                        }
                    }

                    PlasmaComponents.ToolButton {
                        id: pinButton
                        icon.name: checked ? "window-unpin" : "window-pin"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        flat: true
                        checkable: true
                        checked: !root.hideOnWindowDeactivate
                        onClicked: {
                            root.hideOnWindowDeactivate = !pinButton.checked
                            if (pinButton.checked) {
                                root.expanded = true
                            }
                        }
                        Accessible.name: Local.Texts.pin

                        PlasmaComponents.ToolTip {
                            text: Local.Texts.pin
                            visible: parent.hovered
                        }
                    }
                }

                PC3.TabBar {
                    id: tabsHeader
                    Layout.fillWidth: true
                    currentIndex: dialog.currentTab
                    onCurrentIndexChanged: dialog.currentTab = currentIndex

                    PC3.TabButton { text: Local.Texts.info }
                    PC3.TabButton { text: Local.Texts.headphones }
                }
            }
        }

        contentItem: ColumnLayout {
            id: contentLayout
            spacing: Kirigami.Units.mediumSpacing
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.largeSpacing

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                currentIndex: dialog.currentTab
                visible: root.backendConnected

                PC3.ScrollView {
                    anchors.fill: parent
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true

                    ColumnLayout{
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        Item {
                            visible: !root.hasInfo
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            PlasmaComponents.Label {
                                anchors.centerIn: parent
                                width: parent.width - Kirigami.Units.gridUnit * 2
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: Local.Texts.headphones_disconnected
                                wrapMode: Text.WordWrap
                            }
                        }
                        ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: root.hasInfo
                            Kirigami.Heading {
                                level: 1
                                text: root.infoData.name
                                font.bold: true
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.5
                        }

                        Row {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing * 1.5
                            visible: root.batteryData

                            BatteryItem {
                                title: Local.Texts.battery_left
                                battery: root.batteryData?.left?.battery ?? 0
                                isCharging: root.batteryData?.left?.charging ?? false
                                status: root.batteryData?.left?.status ?? 0
                            }
                            BatteryItem {
                                title: Local.Texts.battery_right
                                battery: root.batteryData?.right?.battery ?? 0
                                isCharging: root.batteryData?.right?.charging ?? false
                                status: root.batteryData?.right?.status ?? 0
                            }
                            BatteryItem {
                                title: Local.Texts.battery_case
                                battery: root.batteryData?.case?.battery ?? 0
                                isCharging: root.batteryData?.case?.charging ?? false
                                status: root.batteryData?.case?.status ?? 0
                            }
                            BatteryItem {
                                title: Local.Texts.battery_single
                                battery: root.batteryData?.single?.battery ?? 0
                                isCharging: root.batteryData?.single?.charging ?? false
                                status: root.batteryData?.single?.status ?? 0
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.largeSpacing
                            spacing: Kirigami.Units.mediumSpacing
                            visible: root.ancData

                            PlasmaComponents.Button {
                                Layout.fillWidth: true
                                checkable: true
                                checked: root.selectedAnc === root.ancModes.OFF
                                visible: (root.ancData?.options ?? 0) & root.ancModes.OFF
                                enabled: !(root.ancData?.readonly ?? true)
                                onClicked: if (root.ancData) { root.selectedAnc = root.ancModes.OFF; root.ancData.selected = root.selectedAnc; backend.setAnc(root.currentAddress(), root.selectedAnc) }
                                contentItem: Kirigami.Icon {
                                    anchors.centerIn: parent
                                    source: Qt.resolvedUrl("../icons/Off.svg")
                                    implicitWidth: 24
                                    implicitHeight: 24
                                }

                                PlasmaComponents.ToolTip {
                                    text: Local.Texts.anc_off
                                    visible: noiseButton.hovered
                                }
                            }

                            PlasmaComponents.Button {
                                Layout.fillWidth: true
                                checkable: true
                                checked: root.selectedAnc === root.ancModes.TRANSPARENCY
                                visible: (root.ancData?.options ?? 0) & root.ancModes.TRANSPARENCY
                                enabled: !(root.ancData?.readonly ?? true)
                                onClicked: if (root.ancData) { root.selectedAnc = root.ancModes.TRANSPARENCY; root.ancData.selected = root.selectedAnc; backend.setAnc(root.currentAddress(), root.selectedAnc) }
                                contentItem: Kirigami.Icon {
                                    anchors.centerIn: parent
                                    source: Qt.resolvedUrl("../icons/Tra.svg")
                                    implicitWidth: 24
                                    implicitHeight: 24
                                }

                                PlasmaComponents.ToolTip {
                                    text: Local.Texts.anc_tra
                                    visible: noiseButton.hovered
                                }
                            }

                            PlasmaComponents.Button {
                                Layout.fillWidth: true
                                checkable: true
                                checked: root.selectedAnc === root.ancModes.ADAPTIVE
                                visible: (root.ancData?.options ?? 0) & root.ancModes.ADAPTIVE
                                enabled: !(root.ancData?.readonly ?? true)
                                onClicked: if (root.ancData) { root.selectedAnc = root.ancModes.ADAPTIVE; root.ancData.selected = root.selectedAnc; backend.setAnc(root.currentAddress(), root.selectedAnc) }
                                contentItem: Kirigami.Icon {
                                    anchors.centerIn: parent
                                    source: Qt.resolvedUrl("../icons/Adaptive.svg")
                                    implicitWidth: 24
                                    implicitHeight: 24
                                }

                                PlasmaComponents.ToolTip {
                                    text: Local.Texts.anc_adaptive
                                    visible: noiseButton.hovered
                                }
                            }

                            PlasmaComponents.Button {
                                Layout.fillWidth: true
                                checkable: true
                                checked: root.selectedAnc === root.ancModes.WIND
                                visible: (root.ancData?.options ?? 0) & root.ancModes.WIND
                                enabled: !(root.ancData?.readonly ?? true)
                                onClicked: if (root.ancData) { root.selectedAnc = root.ancModes.WIND; root.ancData.selected = root.selectedAnc; backend.setAnc(root.currentAddress(), root.selectedAnc) }
                                contentItem: Kirigami.Icon {
                                    anchors.centerIn: parent
                                    source: Qt.resolvedUrl("../icons/Wind.svg")
                                    implicitWidth: 24
                                    implicitHeight: 24
                                }

                                PlasmaComponents.ToolTip {
                                    text: Local.Texts.anc_wind
                                    visible: noiseButton.hovered
                                }
                            }

                            PlasmaComponents.Button {
                                Layout.fillWidth: true
                                checkable: true
                                checked: root.selectedAnc === root.ancModes.ANC
                                visible: (root.ancData?.options ?? 0) & root.ancModes.ANC
                                enabled: !(root.ancData?.readonly ?? true)
                                onClicked: if (root.ancData) { root.selectedAnc = root.ancModes.ANC; root.ancData.selected = root.selectedAnc; backend.setAnc(root.currentAddress(), root.selectedAnc) }
                                contentItem: Kirigami.Icon {
                                    anchors.centerIn: parent
                                    source: Qt.resolvedUrl("../icons/Noise.svg")
                                    implicitWidth: 24
                                    implicitHeight: 24
                                }

                                PlasmaComponents.ToolTip {
                                    text: Local.Texts.anc_anc
                                    visible: noiseButton.hovered
                                }
                            }
                        }

                        //Options
                        ColumnLayout {
                            spacing: Kirigami.Units.largeSpacing
                            visible: root.capabilities &&
                                     ((root.conversationAwarenessData !== null) ||
                                      (root.personalizedVolumeData !== null) ||
                                      (root.ancOneAirPodData !== null) ||
                                      (root.volumeSwipeData !== null) ||
                                      (root.adaptiveAudioNoiseData !== null) ||
                                      (root.pressAndHoldDurationData !== null) ||
                                      (root.pressSpeedData !== null) ||
                                      (root.toneVolumeData !== null) ||
                                      (root.volumeSwipeLengthData !== null) ||
                                      (root.endCallData !== null) ||
                                      (root.bluetoothCodec !== null))

                            Kirigami.Heading {
                                level: 1
                                text: Local.Texts.capabilities_header
                                Layout.topMargin: Kirigami.Units.largeSpacing * 3
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                            }

                            // conversation awareness (bool)
                            RowLayout {
                                visible: root.conversationAwarenessData !== null
                                width: parent.width
                                spacing: Kirigami.Units.mediumSpacing
                                PlasmaComponents.Label {
                                    text: Local.Texts.conversation_awareness
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }

                                PlasmaComponents.Switch {
                                    checked: root.conversationAwarenessData?.selected ?? false
                                    enabled: !(root.conversationAwarenessData?.readonly ?? true)
                                    onToggled: {
                                        if (root.conversationAwarenessData) {
                                            root.conversationAwarenessData.selected = checked
                                            backend.setCapability("conversationAwareness", root.currentAddress(), checked)
                                        }
                                    }
                                }
                            }

                            // personalized volume (bool)
                            RowLayout {
                                visible: root.personalizedVolumeData !== null
                                width: parent.width
                                spacing: Kirigami.Units.mediumSpacing
                                PlasmaComponents.Label {
                                    text: Local.Texts.personalized_volume
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }

                                PlasmaComponents.Switch {
                                    checked: root.personalizedVolumeData?.selected ?? false
                                    enabled: !(root.personalizedVolumeData?.readonly ?? true)
                                    onToggled: {
                                        if (root.personalizedVolumeData) {
                                            root.personalizedVolumeData.selected = checked
                                            backend.setCapability("personalizedVolume", root.currentAddress(), checked)
                                        }
                                    }
                                }
                            }

                            // adaptive audio noise (enum)
                            RowLayout {
                                visible: root.adaptiveAudioNoiseData !== null
                                width: parent.width
                                spacing: Kirigami.Units.mediumSpacing
                                PlasmaComponents.Label {
                                    text: Local.Texts.adaptive_audio_noise
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }
                                PlasmaComponents.ComboBox {
                                    implicitWidth: Kirigami.Units.gridUnit * 10
                                    model: [Local.Texts.adaptive_audio_noise_more, Local.Texts.adaptive_audio_noise_default, Local.Texts.adaptive_audio_noise_less]
                                    currentIndex: {
                                        const val = root.adaptiveAudioNoiseData?.selected;
                                        if (val === 0) return 0;
                                        if (val === 50) return 1;
                                        if (val === 100) return 2;
                                        return 1;
                                    }
                                    enabled: !(root.adaptiveAudioNoiseData?.readonly ?? true)
                                    Layout.alignment: Qt.AlignVCenter
                                    popup.width: Math.max(width, popup.implicitWidth)
                                    popup.x: width - popup.width
                                    onCurrentIndexChanged: {
                                        if (root.adaptiveAudioNoiseData) {
                                            if (currentIndex === 0) root.adaptiveAudioNoiseData.selected = 0;
                                            else if (currentIndex === 1) root.adaptiveAudioNoiseData.selected = 50;
                                            else root.adaptiveAudioNoiseData.selected = 100;
                                            backend.setCapability("adaptiveAudioNoise", root.currentAddress(), root.adaptiveAudioNoiseData.selected)
                                        }
                                    }
                                }
                            }

                            // anc one airpod (bool)
                            RowLayout {
                                visible: root.ancOneAirPodData !== null
                                width: parent.width
                                spacing: Kirigami.Units.mediumSpacing
                                PlasmaComponents.Label {
                                    text: Local.Texts.anc_one_airpod
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }

                                PlasmaComponents.Switch {
                                    checked: root.ancOneAirPodData?.selected ?? false
                                    enabled: !(root.ancOneAirPodData?.readonly ?? true)
                                    onToggled: {
                                        if (root.ancOneAirPodData) {
                                            root.ancOneAirPodData.selected = checked
                                            backend.setCapability("ancOneAirPod", root.currentAddress(), checked)
                                        }
                                    }
                                }
                            }

                            // press and hold duration (enum)
                            RowLayout {
                                visible: root.pressAndHoldDurationData !== null
                                width: parent.width
                                spacing: Kirigami.Units.mediumSpacing
                                PlasmaComponents.Label {
                                    text: Local.Texts.press_and_hold_duration
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }
                                PlasmaComponents.ComboBox {
                                    implicitWidth: Kirigami.Units.gridUnit * 10
                                    model: [Local.Texts.press_and_hold_duration_default, Local.Texts.press_and_hold_duration_shorter, Local.Texts.press_and_hold_duration_shortest]
                                    currentIndex: root.pressAndHoldDurationData?.selected ?? 0
                                    enabled: !(root.pressAndHoldDurationData?.readonly ?? true)
                                    Layout.alignment: Qt.AlignVCenter
                                    popup.width: Math.max(width, popup.implicitWidth)
                                    popup.x: width - popup.width
                                    onCurrentIndexChanged: {
                                        if (root.pressAndHoldDurationData) {
                                            root.pressAndHoldDurationData.selected = currentIndex
                                            backend.setCapability("pressAndHoldDuration", root.currentAddress(), currentIndex)
                                        }
                                    }
                                }
                            }

                            // press speed (enum)
                            RowLayout {
                                visible: root.pressSpeedData !== null
                                width: parent.width
                                spacing: Kirigami.Units.mediumSpacing
                                PlasmaComponents.Label {
                                    text: Local.Texts.press_speed
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }
                                PlasmaComponents.ComboBox {
                                    implicitWidth: Kirigami.Units.gridUnit * 10
                                    model: [Local.Texts.press_speed_default, Local.Texts.press_speed_slower, Local.Texts.press_speed_slowest]
                                    currentIndex: root.pressSpeedData?.selected ?? 0
                                    enabled: !(root.pressSpeedData?.readonly ?? true)
                                    Layout.alignment: Qt.AlignVCenter
                                    popup.width: Math.max(width, popup.implicitWidth)
                                    popup.x: width - popup.width
                                    onCurrentIndexChanged: {
                                        if (root.pressSpeedData) {
                                            root.pressSpeedData.selected = currentIndex
                                            backend.setCapability("pressSpeed", root.currentAddress(), currentIndex)
                                        }
                                    }
                                }
                            }

                            // tone volume (slider)
                            RowLayout {
                                visible: root.toneVolumeData !== null
                                width: parent.width
                                spacing: Kirigami.Units.mediumSpacing
                                PlasmaComponents.Label {
                                    text: Local.Texts.tone_volume
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }

                                PlasmaComponents.Slider {
                                    implicitWidth: (Kirigami.Units.gridUnit * 10) - (Kirigami.Units.gridUnit * 2.2) - Kirigami.Units.mediumSpacing
                                    id: volumeSlider
                                    from: 15
                                    to: 125
                                    value: root.toneVolumeData?.selected ?? 50
                                    stepSize: 1
                                    enabled: !(root.toneVolumeData?.readonly ?? true)
                                    onValueChanged: {
                                        if (root.toneVolumeData) {
                                            root.toneVolumeData.selected = Math.round(value)
                                            backend.setCapability("toneVolume", root.currentAddress(), root.toneVolumeData.selected)
                                        }
                                    }
                                }

                                PlasmaComponents.Label {
                                    Layout.minimumWidth: Kirigami.Units.gridUnit * 2.2
                                    horizontalAlignment: Text.AlignRight
                                    text: Math.round(root.toneVolumeData?.selected ?? 50).toString() + "%"
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            // volume swipe (bool)
                            RowLayout {
                                visible: root.volumeSwipeData !== null
                                width: parent.width
                                spacing: Kirigami.Units.mediumSpacing
                                PlasmaComponents.Label {
                                    text: Local.Texts.volume_swipe
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }

                                PlasmaComponents.Switch {
                                    checked: root.volumeSwipeData?.selected ?? false
                                    enabled: !(root.volumeSwipeData?.readonly ?? true)
                                    onToggled: {
                                        if (root.volumeSwipeData) {
                                            root.volumeSwipeData.selected = checked
                                            backend.setCapability("volumeSwipe", root.currentAddress(), checked)
                                        }
                                    }
                                }
                            }

                            // volume swipe length (enum)
                            RowLayout {
                                visible: root.volumeSwipeLengthData !== null
                                width: parent.width
                                spacing: Kirigami.Units.mediumSpacing
                                PlasmaComponents.Label {
                                    text: Local.Texts.volume_swipe_length
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }
                                PlasmaComponents.ComboBox {
                                    implicitWidth: Kirigami.Units.gridUnit * 10
                                    model: [Local.Texts.volume_swipe_length_default, Local.Texts.volume_swipe_length_longer, Local.Texts.volume_swipe_length_longest]
                                    currentIndex: root.volumeSwipeLengthData?.selected ?? 0
                                    enabled: !(root.volumeSwipeLengthData?.readonly ?? true)
                                    Layout.alignment: Qt.AlignVCenter
                                    popup.width: Math.max(width, popup.implicitWidth)
                                    popup.x: width - popup.width
                                    onCurrentIndexChanged: {
                                        if (root.volumeSwipeLengthData) {
                                            root.volumeSwipeLengthData.selected = currentIndex
                                            backend.setCapability("volumeSwipeLength", root.currentAddress(), currentIndex)
                                        }
                                    }
                                }
                            }

                            // end call / mute-unmute (enum)
                            RowLayout {
                                visible: root.endCallData !== null
                                width: parent.width
                                spacing: Kirigami.Units.mediumSpacing
                                PlasmaComponents.Label {
                                    text: Local.Texts.end_call
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }
                                PlasmaComponents.ComboBox {
                                    implicitWidth: Kirigami.Units.gridUnit * 10
                                    model: [Local.Texts.end_call_twice, Local.Texts.end_call_once]
                                    currentIndex: (root.endCallData?.selected === 3) ? 1 : 0
                                    enabled: !(root.endCallData?.readonly ?? true)
                                    Layout.alignment: Qt.AlignVCenter
                                    popup.width: Math.max(width, popup.implicitWidth)
                                    popup.x: width - popup.width
                                    onCurrentIndexChanged: {
                                        if (root.endCallData) {
                                            root.endCallData.selected = currentIndex === 0 ? 2 : 3;
                                            backend.setCapability("endCall", root.currentAddress(), root.endCallData.selected)
                                        }
                                    }
                                }
                            }


                            RowLayout {
                                visible: root.endCallData !== null
                                width: parent.width
                                spacing: Kirigami.Units.mediumSpacing
                                PlasmaComponents.Label {
                                    text: Local.Texts.mute_unmute
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }
                                PlasmaComponents.ComboBox {
                                    implicitWidth: Kirigami.Units.gridUnit * 10
                                    model: [Local.Texts.end_call_twice, Local.Texts.end_call_once]
                                    currentIndex: (root.endCallData?.selected === 2) ? 1 : 0
                                    enabled: false
                                    Layout.alignment: Qt.AlignVCenter
                                    popup.width: Math.max(width, popup.implicitWidth)
                                    popup.x: width - popup.width
                                    }
                                }
                            
                            // bluetooth codec
                            RowLayout {
                                visible: root.bluetoothCodec !== null
                                width: parent.width
                                spacing: Kirigami.Units.mediumSpacing
                                PlasmaComponents.Label {
                                    text: Local.Texts.bluetooth_codec
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }
                                PlasmaComponents.ComboBox {
                                    implicitWidth: Kirigami.Units.gridUnit * 10
                                    model: (root.bluetoothCodec?.options ?? []).map(function(option) {
                                        return option[0]
                                    })
                                    currentIndex: {
                                        var options = root.bluetoothCodec?.options || []
                                        for (var i = 0; i < options.length; i++) {
                                            if (options[i][0] === root.bluetoothCodec.selected) {
                                                return i
                                            }
                                        }
                                        return -1
                                    }
                                    enabled: !(root.bluetoothCodec?.readonly ?? true)
                                    Layout.alignment: Qt.AlignVCenter
                                    popup.width: Math.max(width, popup.implicitWidth)
                                    popup.x: width - popup.width
                                    onCurrentIndexChanged: {
                                        if (root.bluetoothCodec && currentIndex >= 0) {
                                            var options = root.bluetoothCodec.options || []
                                            if (options[currentIndex]) {
                                                root.bluetoothCodec.selected = options[currentIndex][0]
                                                backend.setCapability("bluetoothCodec", root.currentAddress(), options[currentIndex][0])
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Kirigami.Units.largeSpacing
                            }
                        }
                    }
                    }
                }

                PC3.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            width: parent.width
                            spacing: Kirigami.Units.mediumSpacing
                            Layout.topMargin: Kirigami.Units.largeSpacing
                            PlasmaComponents.Label {
                                text: Local.Texts.bluetooth
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            PlasmaComponents.Switch {
                                checked: root.btAdapterData.enabled
                                onToggled: {
                                    root.btAdapterData.enabled = checked
                                    if (checked) backend.enableDefaultBluetoothAdapter()
                                    else backend.disableDefaultBluetoothAdapter()
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: Kirigami.Units.largeSpacing

                            Kirigami.Heading {
                                level: 1
                                text: Local.Texts.headphones
                                Layout.topMargin: Kirigami.Units.largeSpacing * 3
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                            }

                            PlasmaComponents.Label {
                                        text: Local.Texts.headphones_empty
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        verticalAlignment: Text.AlignVCenter
                                        visible: !hasHeadphones
                            }

                            Repeater {
                                model: root.sortedHeadphones
                                delegate: RowLayout {
                                    width: parent ? parent.width : undefined
                                    spacing: Kirigami.Units.mediumSpacing
                                    Layout.fillWidth: true

                                    PlasmaComponents.Label {
                                        text: modelData.name
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    PlasmaComponents.Switch {
                                        checked: modelData.connected
                                        onToggled: {
                                            modelData.connected = checked
                                            if (modelData.address) {
                                                if (checked) backend.connectDevice(modelData.address)
                                                else backend.disconnectDevice(modelData.address)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Kirigami.Units.largeSpacing
                        }
                    }

                }
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.backendConnected

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Kirigami.Units.mediumSpacing
                width: Math.min(parent.width, Kirigami.Units.gridUnit * 30)

                Kirigami.Heading {
                    level: 1
                    text: Local.Texts.socket_error_header
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.5
                }
                PlasmaComponents.Label {
                    text: Local.Texts.socket_error_description
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                PlasmaComponents.Button {
                    text: Local.Texts.socket_error_button
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    onClicked: {
                        backend.connectSocket()
                    }
                }
            }
        }
    }
}
