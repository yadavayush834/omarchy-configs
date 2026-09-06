# SpaceLens Disk Usage

A native, local disk-usage explorer for Omarchy. SpaceLens scans real files in
the background and groups storage into applications, documents, images,
videos, audio, archives, code, temporary files, and other data.

## Features

- Scans the home folder automatically
- Optional full-system or custom-folder scans
- Largest-file and largest-folder views
- Category filters, search, file details, and file-manager integration
- Runs entirely on-device; no server and no uploads

## Install

```bash
./install.sh
```

Then open the Omarchy application launcher and search for **SpaceLens Disk
Usage**.

The app uses GTK 3, WebKitGTK 4.1, and Python GObject bindings. These are
already present on a standard Omarchy installation. If needed:

```bash
omarchy pkg add gtk3 webkit2gtk-4.1 python-gobject
```

## Uninstall

```bash
./uninstall.sh
```
