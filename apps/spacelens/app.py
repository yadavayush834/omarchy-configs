#!/usr/bin/env /usr/bin/python3
"""SpaceLens — local disk usage explorer for Omarchy."""

from __future__ import annotations

import heapq
import json
import mimetypes
import os
import shutil
import subprocess
import sys
import threading
from datetime import datetime
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("WebKit2", "4.1")
from gi.repository import GLib, Gtk, WebKit2  # noqa: E402

APP_ID = "com.ayush.SpaceLens"
APP_DIR = Path(__file__).resolve().parent
HOME = Path.home()
SKIP_ROOTS = {"/proc", "/sys", "/dev", "/run"}
MAX_FILES = 1200

EXTENSIONS = {
    "Images": {"jpg", "jpeg", "png", "gif", "webp", "svg", "heic", "raw", "bmp", "tiff"},
    "Videos": {"mp4", "mov", "mkv", "avi", "webm", "m4v", "mpeg", "mpg"},
    "Audio": {"mp3", "wav", "m4a", "flac", "aac", "ogg", "opus"},
    "Archives": {"zip", "rar", "7z", "tar", "gz", "bz2", "xz", "zst", "iso", "dmg"},
    "Code": {"js", "jsx", "ts", "tsx", "py", "go", "rs", "java", "c", "cpp", "h", "css", "html", "sh", "sql", "json", "toml", "yaml", "yml"},
    "Documents": {"pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "txt", "md", "odt", "ods", "epub", "fig"},
    "Applications": {"appimage", "desktop", "exe", "msi", "apk", "flatpak"},
}


def classify(path: str) -> str:
    lower = path.lower()
    if any(part in lower for part in ("/.cache/", "/cache/", "/tmp/", "/.local/share/trash/", "/var/tmp/")):
        return "Temporary"
    if any(lower.startswith(prefix) for prefix in ("/usr/bin/", "/usr/lib/", "/opt/", "/var/lib/flatpak/")) or "/.local/share/flatpak/" in lower:
        return "Applications"
    ext = Path(lower).suffix.lstrip(".")
    for category, extensions in EXTENSIONS.items():
        if ext in extensions:
            return category
    return "Other"


def disk_bytes(stat_result: os.stat_result) -> int:
    blocks = getattr(stat_result, "st_blocks", 0)
    return blocks * 512 if blocks else stat_result.st_size


class SpaceLensWindow(Gtk.ApplicationWindow):
    def __init__(self, app: Gtk.Application):
        super().__init__(application=app, title="SpaceLens Disk Usage")
        self.set_default_size(1420, 860)
        self.set_size_request(860, 560)
        self.scan_generation = 0
        self.current_root = str(HOME)
        manager = WebKit2.UserContentManager()
        manager.register_script_message_handler("spacelens")
        manager.connect("script-message-received::spacelens", self.on_message)
        self.webview = WebKit2.WebView(user_content_manager=manager)
        settings = self.webview.get_settings()
        settings.set_enable_developer_extras(False)
        settings.set_enable_write_console_messages_to_stdout(False)
        self.webview.load_uri((APP_DIR / "index.html").as_uri())
        self.add(self.webview)
        self.webview.show()

    def send(self, event: str, payload: dict) -> bool:
        message = json.dumps({"event": event, "payload": payload}, ensure_ascii=False)
        script = f"window.SpaceLens && window.SpaceLens.receive({message});"
        self.webview.evaluate_javascript(script, -1, None, None, None, None, None)
        return False

    def emit(self, event: str, payload: dict) -> None:
        GLib.idle_add(self.send, event, payload)

    def on_message(self, _manager, result) -> None:
        try:
            data = json.loads(result.get_js_value().to_json(0))
            if isinstance(data, str):
                data = json.loads(data)
        except Exception:
            return
        command = data.get("command")
        if command == "ready":
            self.start_scan(str(HOME))
        elif command == "scan-home":
            self.start_scan(str(HOME))
        elif command == "scan-root":
            self.start_scan("/")
        elif command == "choose-folder":
            self.choose_folder()
        elif command == "open-path":
            self.open_path(data.get("path", ""))
        elif command == "cancel-scan":
            self.scan_generation += 1
            self.send("cancelled", {"root": self.current_root})

    def choose_folder(self) -> None:
        chooser = Gtk.FileChooserNative(
            title="Choose a folder to scan",
            transient_for=self,
            action=Gtk.FileChooserAction.SELECT_FOLDER,
            accept_label="Scan folder",
            cancel_label="Cancel",
        )
        chooser.connect("response", self.on_folder_response)
        chooser.show()

    def on_folder_response(self, chooser, response: int) -> None:
        if response == Gtk.ResponseType.ACCEPT:
            selected = chooser.get_file()
            path = selected.get_path() if selected else None
            if path:
                self.start_scan(path)
        chooser.destroy()

    def open_path(self, target: str) -> None:
        path = Path(target)
        destination = path if path.is_dir() else path.parent
        if destination.exists():
            subprocess.Popen(["xdg-open", str(destination)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def start_scan(self, root: str) -> None:
        root = os.path.abspath(os.path.expanduser(root))
        if not os.path.exists(root):
            self.send("scan-error", {"message": f"Folder not found: {root}"})
            return
        self.scan_generation += 1
        generation = self.scan_generation
        self.current_root = root
        self.send("scan-start", {"root": root})
        threading.Thread(target=self.scan_worker, args=(root, generation), daemon=True).start()

    def scan_worker(self, root: str, generation: int) -> None:
        largest: list[tuple[int, int, dict]] = []
        folder_totals: dict[str, int] = {}
        category_totals: dict[str, int] = {name: 0 for name in [*EXTENSIONS, "Temporary", "Other"]}
        file_count = folder_count = errors = total_used = sequence = last_update = 0
        for current, dirs, names in os.walk(root, topdown=True, followlinks=False):
            if generation != self.scan_generation:
                return
            dirs[:] = [d for d in dirs if os.path.join(current, d) not in SKIP_ROOTS]
            folder_count += len(dirs)
            for name in names:
                path = os.path.join(current, name)
                try:
                    stat_result = os.stat(path, follow_symlinks=False)
                    if not os.path.isfile(path) or os.path.islink(path):
                        continue
                    file_size = disk_bytes(stat_result)
                except (OSError, PermissionError):
                    errors += 1
                    continue
                file_count += 1
                total_used += file_size
                category = classify(path)
                category_totals[category] += file_size
                relative = os.path.relpath(path, root)
                if os.sep in relative:
                    first = relative.split(os.sep, 1)[0]
                    folder_totals[first] = folder_totals.get(first, 0) + file_size
                mime = mimetypes.guess_type(path)[0]
                item = {
                    "name": name, "path": path, "size": file_size, "category": category,
                    "modified": datetime.fromtimestamp(stat_result.st_mtime).strftime("%d %b %Y"),
                    "kind": mime or (Path(name).suffix[1:].upper() + " file" if Path(name).suffix else "File"),
                }
                sequence += 1
                candidate = (file_size, sequence, item)
                if len(largest) < MAX_FILES:
                    heapq.heappush(largest, candidate)
                elif file_size > largest[0][0]:
                    heapq.heapreplace(largest, candidate)
                if file_count - last_update >= 2000:
                    last_update = file_count
                    self.emit("scan-progress", {"files": file_count, "folders": folder_count, "bytes": total_used, "current": current})
        try:
            usage = shutil.disk_usage(root)
            capacity = {"total": usage.total, "used": usage.used, "free": usage.free}
        except OSError:
            capacity = {"total": total_used, "used": total_used, "free": 0}
        files = [entry[2] for entry in sorted(largest, reverse=True)]
        folders = [
            {"name": name, "path": os.path.join(root, name), "size": value, "category": "Folders", "modified": "—", "kind": "Folder total"}
            for name, value in sorted(folder_totals.items(), key=lambda pair: pair[1], reverse=True)
        ]
        self.emit("scan-complete", {
            "root": root, "files": files, "folders": folders, "categories": category_totals,
            "fileCount": file_count, "folderCount": folder_count, "errors": errors,
            "scannedBytes": total_used, "capacity": capacity,
        })


class SpaceLensApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID)

    def do_activate(self):
        window = self.props.active_window
        if not window:
            window = SpaceLensWindow(self)
        window.present()


def self_test() -> int:
    assert classify("/home/user/Pictures/photo.png") == "Images"
    assert classify("/home/user/.cache/browser/data.bin") == "Temporary"
    assert classify("/usr/bin/tool") == "Applications"
    assert APP_DIR.joinpath("index.html").exists()
    print("SpaceLens self-test passed")
    return 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        raise SystemExit(self_test())
    raise SystemExit(SpaceLensApp().run(sys.argv))
