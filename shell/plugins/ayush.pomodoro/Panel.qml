import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "ayush.pomodoro"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property string backend: Quickshell.env("HOME") + "/.config/omarchy/bar/scripts/pomodoro"

  property string mode: "pomodoro"
  property string currentTask: ""
  property int durationSeconds: 1500
  property int remainingSeconds: 1500
  property bool timerRunning: false
  property bool timerCompleted: false
  property int sessions: 0
  property bool editingTask: false
  property bool editingCustom: false
  property string errorText: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string clockText: {
    var value = Math.max(0, remainingSeconds)
    var minutes = Math.floor(value / 60)
    var seconds = value % 60
    return String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0")
  }
  readonly property string modeTitle: mode === "short" ? "Short break"
    : mode === "long" ? "Long break"
    : mode === "custom" ? "Custom timer"
    : "Time to focus!"

  function open() {
    refresh()
    root.controller.show()
  }

  function close() {
    editingTask = false
    editingCustom = false
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function applyState(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      mode = String(data.mode || "pomodoro")
      currentTask = String(data.task || "")
      durationSeconds = Number(data.duration || 1500)
      remainingSeconds = Number(data.remaining || durationSeconds)
      timerRunning = data.running === true
      timerCompleted = data.completed === true
      sessions = Number(data.sessions || 0)
      errorText = ""
    } catch (e) {
      errorText = "Could not read timer state"
    }
  }

  function invoke(args) {
    if (actionProc.running) return
    actionProc.command = [backend].concat(args)
    actionProc.running = true
  }

  function selectMode(nextMode) {
    editingCustom = false
    invoke(["mode", nextMode])
  }

  function showCustomEditor() {
    editingCustom = true
    Qt.callLater(function() {
      customMinutes.text = String(Math.max(1, Math.round(durationSeconds / 60)))
      customMinutes.selectAll()
      customMinutes.forceActiveFocus()
    })
  }

  function applyCustomDuration() {
    var minutes = parseInt(customMinutes.text, 10)
    if (isNaN(minutes) || minutes < 1 || minutes > 1440) {
      errorText = "Enter 1–1440 minutes"
      return
    }
    editingCustom = false
    invoke(["custom", String(minutes)])
  }

  function showTaskEditor() {
    editingTask = true
    Qt.callLater(function() {
      taskField.text = currentTask
      taskField.selectAll()
      taskField.forceActiveFocus()
    })
  }

  function saveTask() {
    var value = taskField.text.trim()
    editingTask = false
    invoke(["task", value])
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: content
    contentWidth: popup.fittedContentWidth(Style.space(520))
    contentHeight: popup.cappedContentHeight(Style.space(520))

    Item {
      id: content
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.close()

      Column {
        anchors.fill: parent
        spacing: Style.space(12)

        Row {
          width: parent.width
          spacing: Style.space(6)

          ModeButton { label: "Pomodoro"; modeKey: "pomodoro" }
          ModeButton { label: "Short Break"; modeKey: "short" }
          ModeButton { label: "Long Break"; modeKey: "long" }
          ModeButton { label: "Custom"; modeKey: "custom"; customButton: true }
        }

        Row {
          visible: root.editingCustom
          width: parent.width
          height: visible ? implicitHeight : 0
          spacing: Style.space(8)

          TextField {
            id: customMinutes
            width: Style.space(150)
            placeholderText: "Minutes"
            foreground: root.foreground
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 1; top: 1440 }
            onAccepted: root.applyCustomDuration()
          }

          Button {
            text: "Set duration"
            foreground: root.foreground
            accent: root.accent
            bordered: true
            onClicked: root.applyCustomDuration()
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(190)
          radius: Math.max(Style.cornerRadius, Style.space(8))
          color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
          border.width: 1
          border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.34)

          Column {
            anchors.centerIn: parent
            spacing: Style.space(12)

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.clockText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.space(66)
              font.bold: true
            }

            Button {
              anchors.horizontalCenter: parent.horizontalCenter
              width: Style.space(230)
              height: Style.space(48)
              text: root.timerRunning ? "PAUSE" : (root.timerCompleted ? "START AGAIN" : "START")
              foreground: root.foreground
              accent: root.accent
              background: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
              bordered: true
              fontSize: Style.font.heading
              onClicked: root.invoke(["toggle"])
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(2)

          Text {
            width: parent.width
            text: "#" + (root.sessions + 1)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            width: parent.width
            text: root.timerCompleted ? "Session complete!" : root.modeTitle
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            horizontalAlignment: Text.AlignHCenter
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(8)

          Button {
            text: "Reset"
            iconText: "󰑐"
            foreground: root.foreground
            accent: root.accent
            bordered: true
            onClicked: root.invoke(["reset"])
          }

          Button {
            text: "Stop"
            iconText: "󰓛"
            foreground: root.foreground
            accent: root.accent
            bordered: true
            onClicked: root.invoke(["stop"])
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.28)
        }

        Row {
          width: parent.width
          height: Style.space(26)

          Text {
            id: taskHeading
            anchors.verticalCenter: parent.verticalCenter
            text: "TASK"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            font.letterSpacing: 1
          }

          Item { width: parent.width - taskHeading.implicitWidth - editTaskButton.width; height: 1 }

          PanelActionButton {
            id: editTaskButton
            iconText: root.currentTask === "" ? "󰐕" : "󰏫"
            tooltipText: root.currentTask === "" ? "Add task" : "Edit task"
            foreground: root.foreground
            onClicked: root.showTaskEditor()
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(74)
          radius: Math.max(Style.cornerRadius, Style.space(6))
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.24)

          Button {
            visible: !root.editingTask && root.currentTask === ""
            anchors.fill: parent
            text: "Add Task"
            iconText: "󰐕"
            foreground: root.dim
            accent: root.accent
            onClicked: root.showTaskEditor()
          }

          RowLayout {
            visible: !root.editingTask && root.currentTask !== ""
            anchors.fill: parent
            anchors.leftMargin: Style.space(14)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            Text {
              Layout.fillWidth: true
              text: root.currentTask
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            PanelActionButton {
              iconText: "󰅖"
              tooltipText: "Clear task"
              foreground: root.foreground
              hoverColor: root.accent
              onClicked: root.invoke(["clear-task"])
            }
          }

          RowLayout {
            visible: root.editingTask
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(8)

            TextField {
              id: taskField
              Layout.fillWidth: true
              placeholderText: "What are you working on?"
              foreground: root.foreground
              onAccepted: root.saveTask()
            }

            Button {
              text: "Save"
              foreground: root.foreground
              accent: root.accent
              bordered: true
              onClicked: root.saveTask()
            }

            Button {
              text: "Cancel"
              foreground: root.foreground
              onClicked: root.editingTask = false
            }
          }
        }

        Text {
          visible: root.errorText !== ""
          width: parent.width
          text: root.errorText
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }

  Process {
    id: statusProc
    command: [root.backend, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyState(text)
    }
  }

  Process {
    id: actionProc
    onExited: function() {
      root.refresh()
      if (root.hostWidget && root.hostWidget.refresh) root.hostWidget.refresh()
    }
  }

  Timer {
    interval: 1000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  component ModeButton: Button {
    required property string label
    required property string modeKey
    property bool customButton: false

    width: (parent.width - parent.spacing * 3) / 4
    text: label
    selected: root.mode === modeKey
    foreground: root.foreground
    accent: root.accent
    fontSize: Style.font.bodySmall
    horizontalPadding: Style.space(7)
    onClicked: {
      if (customButton) root.showCustomEditor()
      else root.selectMode(modeKey)
    }
  }
}
