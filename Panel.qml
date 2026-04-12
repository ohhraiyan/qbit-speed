import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 500 * Style.uiScaleRatio
    property real contentPreferredHeight: 620 * Style.uiScaleRatio

    anchors.fill: parent

    // ── State ──────────────────────────────────────────────────────────────────
    readonly property int refreshInterval: pluginApi?.pluginSettings?.refreshInterval ?? 3

    // Live instances from settings (read-only view)
    property var instances: []

    // Edit state for the "add instance" form
    property bool showAddForm: false
    property string newName: ""
    property string newHost: "http://localhost:8080"
    property string newUsername: "admin"
    property string newPassword: ""

    // Per-instance live data
    property var instanceData: []

    // Track which view: "speeds" or "manage"
    property string view: "speeds"

    function loadInstances() {
        var src = (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.instances) || []
        var copy = []
        for (var i = 0; i < src.length; i++)
            copy.push({ name: src[i].name || "", host: src[i].host || "", username: src[i].username || "", password: src[i].password || "" })
        root.instances = copy
        var blank = []
        for (var j = 0; j < copy.length; j++)
            blank.push({ dl: 0, ul: 0, dlTotal: 0, ulTotal: 0, torrents: null, status: "loading", error: false })
        root.instanceData = blank
    }

    function saveInstances(arr) {
        if (!pluginApi) return
        pluginApi.pluginSettings.instances = arr
        pluginApi.saveSettings()
        root.instances = arr
        fetchAll()
    }

    function addInstance() {
        if (!root.newHost || root.newHost.trim() === "") return
        var arr = root.instances.slice()
        arr.push({ name: root.newName || root.newHost, host: root.newHost, username: root.newUsername, password: root.newPassword })
        root.newName = ""; root.newHost = "http://localhost:8080"; root.newUsername = "admin"; root.newPassword = ""
        root.showAddForm = false
        saveInstances(arr)
    }

    function removeInstance(idx) {
        var arr = root.instances.slice()
        arr.splice(idx, 1)
        saveInstances(arr)
    }

    // ── Fetch ──────────────────────────────────────────────────────────────────

    function formatSpeed(b) {
        if (b < 1024)       return b.toFixed(0) + " B/s"
        if (b < 1048576)    return (b / 1024).toFixed(1) + " KiB/s"
        if (b < 1073741824) return (b / 1048576).toFixed(2) + " MiB/s"
        return (b / 1073741824).toFixed(2) + " GiB/s"
    }

    function formatBytes(b) {
        if (b < 1024)       return b.toFixed(0) + " B"
        if (b < 1048576)    return (b / 1024).toFixed(1) + " KiB"
        if (b < 1073741824) return (b / 1048576).toFixed(1) + " MiB"
        return (b / 1073741824).toFixed(2) + " GiB"
    }

    function fetchAll() {
        for (var i = 0; i < root.instances.length; i++) fetchInstance(i)
    }

    function fetchInstance(idx) {
        var inst = root.instances[idx]
        if (!inst) return
        var loginXhr = new XMLHttpRequest()
        loginXhr.open("POST", inst.host + "/api/v2/auth/login")
        loginXhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        loginXhr.onreadystatechange = function() {
            if (loginXhr.readyState !== XMLHttpRequest.DONE) return
            var infoXhr = new XMLHttpRequest()
            infoXhr.open("GET", inst.host + "/api/v2/transfer/info")
            infoXhr.onreadystatechange = function() {
                if (infoXhr.readyState !== XMLHttpRequest.DONE) return
                if (infoXhr.status === 200) {
                    try {
                        var d = JSON.parse(infoXhr.responseText)
                        updateInstance(idx, { dl: d.dl_info_speed||0, ul: d.up_info_speed||0, dlTotal: d.dl_info_data||0, ulTotal: d.up_info_data||0, connected: d.connection_status||"connected", status: "ok", error: false })
                        fetchTorrentCount(idx, inst)
                    } catch(e) { updateInstance(idx, { error: true, status: "Parse error" }) }
                } else { updateInstance(idx, { error: true, status: "HTTP " + infoXhr.status }) }
            }
            infoXhr.send()
        }
        loginXhr.send("username=" + encodeURIComponent(inst.username||"admin") + "&password=" + encodeURIComponent(inst.password||""))
    }

    function fetchTorrentCount(idx, inst) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", inst.host + "/api/v2/torrents/count")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try { updateInstance(idx, { torrents: parseInt(xhr.responseText) }) } catch(e) {}
            }
        }
        xhr.send()
    }

    function updateInstance(idx, patch) {
        var arr = root.instanceData.slice()
        arr[idx] = Object.assign({}, arr[idx] || {}, patch)
        root.instanceData = arr
    }

    Timer {
        id: panelTimer
        interval: root.refreshInterval * 1000
        running: true; repeat: true; triggeredOnStart: false
        onTriggered: root.fetchAll()
    }

    Component.onCompleted: { root.loadInstances(); root.fetchAll() }

    // ── UI ─────────────────────────────────────────────────────────────────────

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginM

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon { icon: "arrows-down-up"; color: Color.mPrimary }
                NText {
                    text: "qBittorrent Speeds"
                    pointSize: Style.fontSizeL
                    font.weight: Font.Bold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                // Tab switcher
                RowLayout {
                    spacing: Style.marginXS
                    Rectangle {
                        width: 80; height: 28; radius: Style.radiusM
                        color: root.view === "speeds" ? Color.mPrimary : Style.capsuleColor
                        border.color: Style.capsuleBorderColor
                        border.width: Style.capsuleBorderWidth
                        NText { anchors.centerIn: parent; text: "Speeds"; pointSize: Style.fontSizeS; color: root.view === "speeds" ? Color.mOnPrimary : Color.mOnSurface }
                        MouseArea { anchors.fill: parent; onClicked: root.view = "speeds"; cursorShape: Qt.PointingHandCursor }
                    }
                    Rectangle {
                        width: 80; height: 28; radius: Style.radiusM
                        color: root.view === "manage" ? Color.mPrimary : Style.capsuleColor
                        border.color: Style.capsuleBorderColor
                        border.width: Style.capsuleBorderWidth
                        NText { anchors.centerIn: parent; text: "Manage"; pointSize: Style.fontSizeS; color: root.view === "manage" ? Color.mOnPrimary : Color.mOnSurface }
                        MouseArea { anchors.fill: parent; onClicked: root.view = "manage"; cursorShape: Qt.PointingHandCursor }
                    }
                }

                NIconButton { icon: "refresh"; onClicked: root.fetchAll() }
            }

            // ── SPEEDS VIEW ────────────────────────────────────────────────────
            NScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.view === "speeds"

                ListView {
                    id: speedsList
                    model: root.instances
                    spacing: Style.marginM

                    delegate: Rectangle {
                        width: speedsList.width
                        height: cardCol.implicitHeight + Style.marginL * 2
                        color: Color.mSurfaceVariant
                        radius: Style.radiusL

                        readonly property var instData: root.instanceData[index] || {}
                        readonly property bool isLoading: !instData.status || instData.status === "loading"
                        readonly property bool hasError: instData.error === true

                        ColumnLayout {
                            id: cardCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginL }
                            spacing: Style.marginM

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginS
                                Rectangle { width: 8; height: 8; radius: 4; color: parent.parent.hasError ? Color.mError : parent.parent.isLoading ? Color.mOnSurfaceVariant : Color.mSuccess }
                                NText { text: modelData.name || modelData.host || "Instance " + (index+1); pointSize: Style.fontSizeM; font.weight: Font.Bold; color: Color.mOnSurface; Layout.fillWidth: true }
                                NText { visible: !parent.parent.hasError && instData.torrents != null; text: (instData.torrents || 0) + " torrents"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
                                NText { visible: parent.parent.hasError; text: instData.status || "Error"; pointSize: Style.fontSizeS; color: Color.mError }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginL
                                visible: !parent.parent.hasError

                                ColumnLayout {
                                    spacing: 2
                                    RowLayout {
                                        spacing: Style.marginXS
                                        NIcon { icon: "arrow-down"; color: Color.mTertiary; pointSize: Style.fontSizeS }
                                        NText { text: "Download"; pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant }
                                    }
                                    NText {
                                        text: parent.parent.parent.isLoading ? "—" : root.formatSpeed(instData.dl || 0)
                                        pointSize: Style.fontSizeM
                                        font.weight: Font.Bold
                                        color: Color.mOnSurface
                                    }
                                    NText {
                                        text: parent.parent.parent.isLoading ? "" : "Total: " + root.formatBytes(instData.dlTotal || 0)
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                }

                                Rectangle { width: 1; height: 44; color: Style.capsuleBorderColor }

                                ColumnLayout {
                                    spacing: 2
                                    RowLayout {
                                        spacing: Style.marginXS
                                        NIcon { icon: "arrow-up"; color: Color.mSecondary; pointSize: Style.fontSizeS }
                                        NText { text: "Upload"; pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant }
                                    }
                                    NText {
                                        text: parent.parent.parent.isLoading ? "—" : root.formatSpeed(instData.ul || 0)
                                        pointSize: Style.fontSizeM
                                        font.weight: Font.Bold
                                        color: Color.mOnSurface
                                    }
                                    NText {
                                        text: parent.parent.parent.isLoading ? "" : "Total: " + root.formatBytes(instData.ulTotal || 0)
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            NText { text: modelData.host || ""; pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                    }

                    // Empty state
                    Item {
                        width: speedsList.width
                        height: 180
                        visible: root.instances.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Style.marginM
                            NIcon { Layout.alignment: Qt.AlignHCenter; icon: "server-off"; pointSize: Style.fontSizeXXL; color: Color.mOnSurfaceVariant }
                            NText { Layout.alignment: Qt.AlignHCenter; text: "No instances — go to Manage tab to add one"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; Layout.preferredWidth: 260 * Style.uiScaleRatio }
                        }
                    }
                }
            }

            // ── MANAGE VIEW ────────────────────────────────────────────────────
            NScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.view === "manage"

                ColumnLayout {
                    width: parent.width
                    spacing: Style.marginM

                    // Existing instances
                    Repeater {
                        model: root.instances
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            width: parent ? parent.width : 400
                            implicitHeight: manageRow.implicitHeight + Style.marginM * 2
                            color: Color.mSurfaceVariant
                            radius: Style.radiusL

                            RowLayout {
                                id: manageRow
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginM }
                                spacing: Style.marginS

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    NText { text: modelData.name || "Instance " + (index+1); pointSize: Style.fontSizeM; font.weight: Font.Medium; color: Color.mOnSurface }
                                    NText { text: modelData.host || ""; pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant; elide: Text.ElideRight; Layout.fillWidth: true }
                                }

                                NIconButton {
                                    icon: "trash"
                                    onClicked: root.removeInstance(index)
                                }
                            }
                        }
                    }

                    // Add form toggle
                    NButton {
                        Layout.fillWidth: true
                        visible: !root.showAddForm
                        text: "+ Add Instance"
                        onClicked: root.showAddForm = true
                    }

                    // Add form
                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.showAddForm
                        implicitHeight: addFormCol.implicitHeight + Style.marginL * 2
                        color: Color.mSurfaceVariant
                        radius: Style.radiusL

                        ColumnLayout {
                            id: addFormCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginL }
                            spacing: Style.marginS

                            NText { text: "New Instance"; pointSize: Style.fontSizeM; font.weight: Font.Bold; color: Color.mOnSurface }

                            NTextInput {
                                Layout.fillWidth: true
                                label: "Name"
                                placeholderText: "e.g. Home, Seedbox..."
                                text: root.newName
                                onTextChanged: root.newName = text
                            }
                            NTextInput {
                                Layout.fillWidth: true
                                label: "Host URL"
                                placeholderText: "http://localhost:8080"
                                text: root.newHost
                                onTextChanged: root.newHost = text
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginM
                                NTextInput {
                                    Layout.fillWidth: true
                                    label: "Username"
                                    text: root.newUsername
                                    onTextChanged: root.newUsername = text
                                }
                                NTextInput {
                                    Layout.fillWidth: true
                                    label: "Password"
                                    echoMode: TextInput.Password
                                    text: root.newPassword
                                    onTextChanged: root.newPassword = text
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginM
                                NButton {
                                    text: "Cancel"
                                    onClicked: { root.showAddForm = false; root.newName = ""; root.newHost = "http://localhost:8080"; root.newUsername = "admin"; root.newPassword = "" }
                                }
                                NButton {
                                    text: "Add"
                                    highlighted: true
                                    onClicked: root.addInstance()
                                }
                            }
                        }
                    }

                    // Refresh interval
                    NDivider { Layout.fillWidth: true }

                    NLabel { Layout.fillWidth: true; label: "Refresh Interval"; description: "Every " + root.refreshInterval + "s" }
                    NSlider {
                        Layout.fillWidth: true
                        from: 1; to: 30; stepSize: 1
                        value: root.refreshInterval
                        onValueChanged: {
                            if (!pluginApi) return
                            pluginApi.pluginSettings.refreshInterval = value
                            pluginApi.saveSettings()
                        }
                    }

                    // Show/hide toggles
                    NDivider { Layout.fillWidth: true }
                    NToggle {
                        Layout.fillWidth: true
                        label: "Show Download Speed"
                        checked: pluginApi?.pluginSettings?.showDownload ?? true
                        onCheckedChanged: { if (pluginApi) { pluginApi.pluginSettings.showDownload = checked; pluginApi.saveSettings() } }
                    }
                    NToggle {
                        Layout.fillWidth: true
                        label: "Show Upload Speed"
                        checked: pluginApi?.pluginSettings?.showUpload ?? true
                        onCheckedChanged: { if (pluginApi) { pluginApi.pluginSettings.showUpload = checked; pluginApi.saveSettings() } }
                    }
                }
            }

            // Footer
            NText {
                Layout.alignment: Qt.AlignHCenter
                text: "Auto-refreshes every " + root.refreshInterval + "s"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                visible: root.view === "speeds"
            }
        }
    }
}
