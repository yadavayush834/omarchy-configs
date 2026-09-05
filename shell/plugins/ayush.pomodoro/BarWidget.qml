import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "ayush.pomodoro"

  readonly property string backend: Quickshell.env("HOME") + "/.config/omarchy/bar/scripts/pomodoro"
  property string statusText: "󰔟"
  property string statusTooltip: "Open Pomodoro"
  property bool timerActive: false

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function refresh() {
    if (!statusProc.running) statusProc.running = true
    if (panelLoader.item && panelLoader.item.opened && panelLoader.item.refresh)
      panelLoader.item.refresh()
  }

  function applyStatus(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      statusText = String(data.text || "󰔟")
      statusTooltip = String(data.tooltip || "Open Pomodoro")
      timerActive = data.running === true || data.completed === true
    } catch (e) {
      statusText = "󰔟"
      statusTooltip = "Open Pomodoro"
      timerActive = false
    }
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Process {
    id: statusProc
    command: [root.backend, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  IpcHandler {
    target: "ayush.pomodoro"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function refresh(): void { root.refresh() }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.statusText
    active: root.timerActive
    horizontalMargin: 8.5
    fontSize: Style.font.bodySmall
    tooltipText: root.statusTooltip

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.togglePanel()
    }
  }
}
