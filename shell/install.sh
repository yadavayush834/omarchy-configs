#!/usr/bin/env bash

# Install productivity and background-app widgets into the top Omarchy bar.

set -Eeuo pipefail

readonly source_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly config_root="${HOME}/.config/omarchy"
readonly plugins_root="${config_root}/plugins"
readonly scripts_root="${config_root}/bar/scripts"
readonly shell_config="${config_root}/shell.json"

for command_name in jq omarchy; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'Error: %s is required.\n' "${command_name}" >&2
    exit 1
  }
done

mkdir -p -- "${plugins_root}" "${scripts_root}"
cp -a -- "${source_root}/plugins/ayush.todo" "${plugins_root}/"
cp -a -- "${source_root}/plugins/ayush.pomodoro" "${plugins_root}/"
cp -a -- "${source_root}/plugins/ayush.background-apps" "${plugins_root}/"
install -m 0755 -- "${source_root}/scripts/todo" "${scripts_root}/todo"
install -m 0755 -- "${source_root}/scripts/pomodoro" "${scripts_root}/pomodoro"
install -m 0755 -- "${source_root}/scripts/background-apps" "${scripts_root}/background-apps"

if [[ -f "${shell_config}" ]]; then
  cp -- "${shell_config}" "${shell_config}.backup.$(date +%Y%m%d-%H%M%S)"
else
  cp -- "/usr/share/omarchy/config/omarchy/shell.json" "${shell_config}"
fi

temporary="$(mktemp "${config_root}/shell.json.XXXXXX")"
jq '
  .bar.position = "top"
  | .bar.layout.left = ([.bar.layout.left[] | select(.id != "ayush.todo")] + [{"id":"ayush.todo"}])
  | .bar.layout.center = (
      [.bar.layout.center[] | select(.id != "ayush.pomodoro")]
      | (map(.id) | index("omarchy.clock")) as $clock
      | if $clock == null then . + [{"id":"ayush.pomodoro"}]
        else .[0:$clock] + [{"id":"ayush.pomodoro"}] + .[$clock:]
        end
    )
  | .bar.layout.right = (
      [.bar.layout.right[] | select(.id != "ayush.background-apps")]
      | (map(.id) | index("omarchy.tray")) as $tray
      | if $tray == null then [{"id":"ayush.background-apps"}] + .
        else .[0:($tray + 1)] + [{"id":"ayush.background-apps"}] + .[($tray + 1):]
        end
    )
' "${shell_config}" > "${temporary}"
mv -- "${temporary}" "${shell_config}"

omarchy restart shell
printf 'Todo, Pomodoro, and Background Apps are installed in the top bar.\n'
