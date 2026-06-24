# Contributing to DiskLens

Thanks for your interest in improving DiskLens! Issues and pull requests are
welcome. This guide gets you from clone to green CI.

## Ground rules

- **No third-party runtime dependencies in the app.** DiskLens is intentionally
  pure SwiftUI on Apple system frameworks only (`SwiftUI`, `AppKit`, `Charts`,
  `CryptoKit`, `Foundation`, `Quartz`). PRs that add a Swift package dependency
  will be declined unless there's a very strong reason.
- **Cleanup must stay safe.** Anything that removes files must move them to the
  **Trash** (recoverable), never delete in place.
- **Nothing leaves the device.** No telemetry, network calls, or analytics.
- Be kind — see our [Code of Conduct](CODE_OF_CONDUCT.md).

## Project layout

```
app/   # native macOS app (SwiftUI) — Sources/DiskLens/{App,Models,Views,Utilities}, Tests/
web/   # Next.js landing site (deployed to Vercel)
docs/  # images used by the README
```

## Building the app

Requires macOS 14+ and the Swift toolchain (`xcode-select --install` — no full
Xcode required for building/running).

```bash
cd app
./run.sh          # compile & run from source
./build-app.sh    # bundle DiskLens.app
./make-dmg.sh     # package a distributable .dmg
```

## Running the tests

Unit + integration tests live in `app/Tests/DiskLensTests/` and use Swift's
modern **swift-testing** framework.

```bash
cd app
./run-tests.sh            # runs the whole suite
./run-tests.sh --filter Squarify   # a subset
```

`run-tests.sh` auto-detects your toolchain: with full Xcode it's just
`swift test`; on a Command Line Tools–only setup it injects the swift-testing
framework search path for you. **CI runs this same script**, so if it's green
locally it'll be green in CI.

Please add or update tests for any behavior change to the scan engine,
duplicate finder, cleanup rules, insights, or treemap layout.

## Working on the website

```bash
cd web
npm install
npm run dev       # http://localhost:3000
npm run build     # production build (what CI checks)
```

## Pull request process

1. Fork and create a topic branch off `main` (or open against `dev` for WIP).
2. Make your change; keep commits focused and messages descriptive.
3. Ensure **`./run-tests.sh` passes** and, for web changes, **`npm run build` passes**.
4. Open a PR using the template. Describe *what* and *why*, and how you tested.
5. CI must be green (tests, web build, CodeQL, secret scan, dependency review)
   before a maintainer merges.

## Commit / branch conventions

- Short, imperative commit subjects ("Add old-and-large filter to Files view").
- One logical change per PR where possible.

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
