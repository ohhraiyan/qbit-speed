import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property string screenName: screen?.name ?? ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    readonly property var instances: pluginApi?.pluginSettings?.instances ?? []
    readonly property int refreshInterval: pluginApi?.pluginSettings?.refreshInterval ?? 3
    readonly property bool showUpload: pluginApi?.pluginSettings?.showUpload ?? true
    readonly property bool showDownload: pluginApi?.pluginSettings?.showDownload ?? true

    property real totalDl: 0
    property real totalUl: 0
    property bool hasError: false
    property bool loading: true

    readonly property real contentWidth: row.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: capsuleHeight

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    function formatSpeed(b) {
        if (b < 1024)        return b.toFixed(0) + " B/s"
        if (b < 1048576)     return (b / 1024).toFixed(1) + " KiB/s"
        if (b < 1073741824)  return (b / 1048576).toFixed(2) + " MiB/s"
        return (b / 1073741824).toFixed(2) + " GiB/s"
    }

    function fetchAll() {
        if (!instances || instances.length === 0) {
            root.totalDl = 0; root.totalUl = 0; root.loading = false; return
        }
        var accDl = 0, accUl = 0, remaining = instances.length, anyError = false
        root.loading = true
        for (var i = 0; i < instances.length; i++) {
            (function(inst) {
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
                                accDl += d.dl_info_speed || 0
                                accUl += d.up_info_speed || 0
                            } catch(e) { anyError = true }
                        } else { anyError = true }
                        remaining--
                        if (remaining === 0) {
                            root.totalDl = accDl; root.totalUl = accUl
                            root.hasError = anyError && accDl === 0 && accUl === 0
                            root.loading = false
                        }
                    }
                    infoXhr.send()
                }
                loginXhr.send("username=" + encodeURIComponent(inst.username || "admin")
                    + "&password=" + encodeURIComponent(inst.password || ""))
            })(instances[i])
        }
    }

    Timer {
        interval: root.refreshInterval * 1000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.fetchAll()
    }

    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        radius: Style.radiusL
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Style.marginS

            // Error icon only shown on error
            NIcon {
                visible: root.hasError
                icon: "alert-triangle"
                color: Color.mError
                applyUiScale: true
            }

            // Download
            RowLayout {
                visible: root.showDownload
                spacing: 2
                NIcon {
                    icon: "arrow-down"
                    color: Color.mTertiary
                    pointSize: root.barFontSize * 0.85
                    applyUiScale: false
                }
                NText {
                    text: root.loading ? "…" : root.formatSpeed(root.totalDl)
                    color: Color.mOnSurface
                    pointSize: root.barFontSize
                    font.weight: Font.Medium
                }
            }

            // Upload
            RowLayout {
                visible: root.showUpload
                spacing: 2
                NIcon {
                    icon: "arrow-up"
                    color: Color.mSecondary
                    pointSize: root.barFontSize * 0.85
                    applyUiScale: false
                }
                NText {
                    text: root.loading ? "…" : root.formatSpeed(root.totalUl)
                    color: Color.mOnSurface
                    pointSize: root.barFontSize
                    font.weight: Font.Medium
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { if (pluginApi) pluginApi.openPanel(root.screen, root) }
        onEntered: TooltipService.show(root, "qBittorrent – " + (instances ? instances.length : 0) + " instance(s) — click for details", BarService.getTooltipDirection())
        onExited: TooltipService.hide()
    }
}
