## zig-dialog
Cross-platform dialog library in Zig (work in progress)

An example implementation can be found over at `./example`.

Supported dialog types:
- Various file choosers (normal and multiple file/directory open, file save)

Supported OSes:
- Linux / BSDs: GTK3 (requires dev headers), Zenity (requires Zenity to be present the user's computer)
- Windows