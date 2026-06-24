# DiskLens

A native macOS app that scans a folder and shows you what's eating your disk — then helps you reclaim it. Built with SwiftUI, no Xcode required.

![DiskLens](docs/screenshot.png)

## Features

- **Breakdown** — drill-down tree of folders and files, sorted largest-first, with size bars.
- **Treemap** — squarified treemap where rectangle area = disk usage. Click to zoom in, breadcrumb to climb back out.
- **Duplicates** — finds byte-identical files (size bucket → SHA-256), shows reclaimable space, and trashes extra copies with one click.
- **Cleanup** — flags caches, build artifacts (`node_modules`, `.next`, `target`, …), junk (`.DS_Store`, `.crdownload`), and large archives/installers. Select and move to Trash (recoverable).

Everything deleted goes to the **Trash**, never an unrecoverable delete.

## Build & run

```bash
./build-app.sh        # produces DiskLens.app
open DiskLens.app
```

Or run it straight from source without bundling:

```bash
./run.sh
```

## Requirements

- macOS 14+
- Swift toolchain (Command Line Tools is enough — `xcode-select --install`)

## Why `swiftc` and not `swift build`?

This machine's Command Line Tools ships a broken SwiftPM `ManifestAPI` (the
`PackageDescription` dylib is missing the `Package` initializer symbol), so
`swift build` fails to link *any* `Package.swift`. DiskLens has no external
dependencies — only Apple system frameworks — so `build-app.sh` compiles the
sources directly with `swiftc`. `Package.swift` is kept for editor/tooling
support and in case you later build under full Xcode.

## How sizes are measured

DiskLens sums **allocated** size (`totalFileAllocatedSize`) — the space a file
actually occupies on disk — and never follows symlinks, so nothing is
double-counted. Folders you don't have permission to read are skipped silently.

## Project layout

```
Sources/DiskLens/
  DiskLensApp.swift        # @main entry + AppDelegate (Dock/activation)
  AppModel.swift           # @Observable state: scanning, duplicates, cleanup, trashing
  Models/
    FileNode.swift         # the scanned tree node
    ScanEngine.swift       # recursive, cancellable directory walk
    DuplicateFinder.swift  # size-bucket + streaming SHA-256
    CleanupRules.swift     # rule-based reclaim suggestions
  Views/                   # ContentView, Welcome, Breakdown, Treemap, Duplicates, Cleanup
  Utilities/               # ByteFormat, TrashHelper, FileColor, Squarify (treemap layout)
```
