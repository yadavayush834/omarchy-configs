import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "ayush.todo"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property string backend: Quickshell.env("HOME") + "/.config/omarchy/bar/scripts/todo"
  property var tasks: []
  property int pendingCount: 0
  property int completedCount: 0
  property string errorText: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.6)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    refresh()
    root.controller.show()
    Qt.callLater(function() { taskField.forceActiveFocus() })
  }

  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }
  function refresh() { if (!statusProc.running) statusProc.running = true }

  function applyState(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      tasks = data.tasks || []
      pendingCount = Number(data.pending || 0)
      completedCount = Number(data.completed || 0)
      errorText = ""
    } catch (e) {
      errorText = "Could not read todo list"
    }
  }

  function invoke(args) {
    if (actionProc.running) return
    actionProc.command = [backend].concat(args)
    actionProc.running = true
  }

  function addTask() {
    var value = taskField.text.trim()
    if (value === "") return
    taskField.text = ""
    invoke(["add", value])
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: content
    contentWidth: popup.fittedContentWidth(Style.space(480))
    contentHeight: popup.cappedContentHeight(Style.space(500))

    Item {
      id: content
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.close()

      Column {
        anchors.fill: parent
        spacing: Style.space(10)

        RowLayout {
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: "TODO"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
            font.letterSpacing: 1
          }

          Item { Layout.fillWidth: true }

          Text {
            text: root.pendingCount + " pending"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        RowLayout {
          width: parent.width
          spacing: Style.space(8)

          TextField {
            id: taskField
            Layout.fillWidth: true
            placeholderText: "Add a task..."
            foreground: root.foreground
            onAccepted: root.addTask()
          }

          Button {
            text: "Add"
            iconText: "󰐕"
            foreground: root.foreground
            accent: root.accent
            bordered: true
            onClicked: root.addTask()
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(340)
          radius: Math.max(Style.cornerRadius, Style.space(7))
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)

          Text {
            visible: root.tasks.length === 0
            anchors.centerIn: parent
            text: "Nothing to do — enjoy the quiet."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          ListView {
            id: taskList
            visible: root.tasks.length > 0
            anchors.fill: parent
            anchors.margins: Style.space(8)
            clip: true
            spacing: Style.space(5)
            model: root.tasks

            delegate: Rectangle {
              required property var modelData
              width: taskList.width
              height: Style.space(52)
              radius: Math.max(Style.cornerRadius, Style.space(5))
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.045)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(6)
                spacing: Style.space(8)

                PanelActionButton {
                  iconText: modelData.done === true ? "󰄲" : "󰄱"
                  tooltipText: modelData.done === true ? "Mark pending" : "Mark complete"
                  foreground: modelData.done === true ? root.dim : root.foreground
                  hoverColor: root.accent
                  onClicked: root.invoke(["toggle", String(modelData.id)])
                }

                Text {
                  Layout.fillWidth: true
                  text: String(modelData.text || "")
                  color: modelData.done === true ? root.dim : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.strikeout: modelData.done === true
                  elide: Text.ElideRight
                }

                PanelActionButton {
                  iconText: "󰆴"
                  tooltipText: "Delete task"
                  foreground: root.dim
                  hoverColor: root.accent
                  onClicked: root.invoke(["delete", String(modelData.id)])
                }
              }
            }
          }
        }

        RowLayout {
          width: parent.width

          Text {
            text: root.completedCount + " completed"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Item { Layout.fillWidth: true }

          Button {
            visible: root.completedCount > 0
            text: "Clear completed"
            foreground: root.foreground
            bordered: true
            onClicked: root.invoke(["clear-completed"])
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
    interval: 2000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }
}
