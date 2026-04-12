import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null

    implicitWidth: 500
    implicitHeight: col.implicitHeight

    property var editInstances: []
    property int editRefreshInterval: 3
    property bool editShowDownload: true
    property bool editShowUpload: true

    Component.onCompleted: {
        var ri = pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.refreshInterval
        root.editRefreshInterval = ri || 3

        var sd = pluginApi && pluginApi.pluginSettings ? pluginApi.pluginSettings.showDownload : undefined
        root.editShowDownload = (sd !== undefined && sd !== null) ? sd : true

        var su = pluginApi && pluginApi.pluginSettings ? pluginApi.pluginSettings.showUpload : undefined
        root.editShowUpload = (su !== undefined && su !== null) ? su : true

        var src = (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.instances)
            || []
        var copy = []
        for (var i = 0; i < src.length; i++) {
            copy.push({
                name:     src[i].name     || "",
                host:     src[i].host     || "",
                username: src[i].username || "",
                password: src[i].password || ""
            })
        }
        root.editInstances = copy
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Style.marginM

        // ── Instances ──────────────────────────────────────────────────────

        NLabel {
            Layout.fillWidth: true
            label: "qBittorrent Instances"
            description: "Add or remove instances to monitor"
        }

        Repeater {
            model: root.editInstances

            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: instCol.implicitHeight + Style.marginL * 2
                color: Color.mSurfaceVariant
                radius: Style.radiusL

                ColumnLayout {
                    id: instCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Style.marginL
                    }
                    spacing: Style.marginS

                    RowLayout {
                        Layout.fillWidth: true
                        NText {
                            text: "Instance " + (index + 1)
                            pointSize: Style.fontSizeM
                            font.weight: Font.Bold
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }
                        NIconButton {
                            icon: "trash"
                            onClicked: {
                                var arr = root.editInstances.slice()
                                arr.splice(index, 1)
                                root.editInstances = arr
                            }
                        }
                    }

                    NTextInput {
                        Layout.fillWidth: true
                        label: "Name"
                        placeholderText: "e.g. Home, Seedbox..."
                        text: modelData.name || ""
                        onTextChanged: {
                            var arr = root.editInstances.slice()
                            arr[index] = { name: text, host: arr[index].host, username: arr[index].username, password: arr[index].password }
                            root.editInstances = arr
                        }
                    }

                    NTextInput {
                        Layout.fillWidth: true
                        label: "Host URL"
                        placeholderText: "http://localhost:8080"
                        text: modelData.host || ""
                        onTextChanged: {
                            var arr = root.editInstances.slice()
                            arr[index] = { name: arr[index].name, host: text, username: arr[index].username, password: arr[index].password }
                            root.editInstances = arr
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NTextInput {
                            Layout.fillWidth: true
                            label: "Username"
                            text: modelData.username || ""
                            onTextChanged: {
                                var arr = root.editInstances.slice()
                                arr[index] = { name: arr[index].name, host: arr[index].host, username: text, password: arr[index].password }
                                root.editInstances = arr
                            }
                        }

                        NTextInput {
                            Layout.fillWidth: true
                            label: "Password"
                            echoMode: TextInput.Password
                            text: modelData.password || ""
                            onTextChanged: {
                                var arr = root.editInstances.slice()
                                arr[index] = { name: arr[index].name, host: arr[index].host, username: arr[index].username, password: text }
                                root.editInstances = arr
                            }
                        }
                    }
                }
            }
        }

        NButton {
            Layout.fillWidth: true
            text: "+ Add Instance"
            onClicked: {
                var arr = root.editInstances.slice()
                arr.push({ name: "", host: "http://localhost:8080", username: "admin", password: "" })
                root.editInstances = arr
            }
        }

        NDivider { Layout.fillWidth: true }

        // ── Display options ────────────────────────────────────────────────

        NLabel {
            Layout.fillWidth: true
            label: "Display Options"
        }

        NToggle {
            Layout.fillWidth: true
            label: "Show Download Speed"
            description: "Display download rate in the bar widget"
            checked: root.editShowDownload
            onCheckedChanged: root.editShowDownload = checked
        }

        NToggle {
            Layout.fillWidth: true
            label: "Show Upload Speed"
            description: "Display upload rate in the bar widget"
            checked: root.editShowUpload
            onCheckedChanged: root.editShowUpload = checked
        }

        NDivider { Layout.fillWidth: true }

        // ── Refresh interval ───────────────────────────────────────────────

        NLabel {
            Layout.fillWidth: true
            label: "Refresh Interval"
            description: "Polling every " + root.editRefreshInterval + "s"
        }

        NSlider {
            Layout.fillWidth: true
            from: 1
            to: 30
            stepSize: 1
            value: root.editRefreshInterval
            onValueChanged: root.editRefreshInterval = value
        }
    }

    function saveSettings() {
        if (!pluginApi) return
        var valid = []
        for (var i = 0; i < root.editInstances.length; i++) {
            var inst = root.editInstances[i]
            if (inst.host && inst.host.trim() !== "") valid.push(inst)
        }
        pluginApi.pluginSettings.instances       = valid
        pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval
        pluginApi.pluginSettings.showDownload    = root.editShowDownload
        pluginApi.pluginSettings.showUpload      = root.editShowUpload
        pluginApi.saveSettings()
    }
}
