import SwiftUI

struct SettingsView: View {
    @AppStorage("useBinaryUnits") private var useBinary = false
    @AppStorage("archiveMinMB") private var archiveMinMB = 100
    @AppStorage("checkForUpdates") private var checkForUpdates = true

    var body: some View {
        Form {
            Section("Units") {
                Toggle("Use binary units (1024-based)", isOn: $useBinary)
                Text("Off: 1 GB = 1,000 MB (macOS default). On: 1 GB = 1,024 MB.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Cleanup") {
                Stepper(value: $archiveMinMB, in: 10...2000, step: 10) {
                    Text("Flag archives larger than **\(archiveMinMB) MB**")
                }
            }
            Section("Updates") {
                Toggle("Check for updates on launch", isOn: $checkForUpdates)
                Text("Pings GitHub Releases for a newer version. It's the only network request DiskLens makes, and your files never leave your Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Keyboard shortcuts") {
                shortcut("Choose folder to scan", "⌘O")
                shortcut("Rescan current folder", "⌘R")
                shortcut("Quick Look a file", "click a row in Files")
                shortcut("Preferences", "⌘,")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 470)
    }

    private func shortcut(_ label: String, _ key: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(key).font(.callout.monospaced()).foregroundStyle(.secondary)
        }
    }
}
