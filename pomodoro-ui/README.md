# Omarchy Pomodoro popup

Native Omarchy 4 Quickshell popup with:

- Pomodoro, short-break, long-break, and custom-duration modes
- large countdown with Start/Pause, Reset, and Stop controls
- task entry, editing, and clearing inside the popup
- persistent state and desktop completion notifications
- compact task and countdown status in the top bar

## Install

From the repository root:

```bash
mkdir -p ~/.config/omarchy/bar/scripts
install -m755 pomodoro-timer ~/.config/omarchy/bar/scripts/pomodoro

mkdir -p ~/.config/omarchy/plugins
cp -r pomodoro-ui/ayush.pomodoro ~/.config/omarchy/plugins/
```

Add this widget entry to `bar.layout.center` in
`~/.config/omarchy/shell.json`, ideally immediately after
`omarchy.indicators`:

```json
{
  "id": "ayush.pomodoro"
}
```

Remove the previous command-style `pomodoro` entry if it exists, then apply
the plugin:

```bash
omarchy-shell shell rescanPlugins
omarchy restart shell
```

Click the timer in the bar to open all controls. No right-click, middle-click,
or double-click actions are required.
