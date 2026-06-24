import SwiftUI
import AppKit

@main
struct DiskLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .tint(.brand)
                .frame(minWidth: 1000, minHeight: 640)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Choose Folder to Scan…") { model.chooseFolder() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Rescan") { if let u = model.scannedRoot { model.scan(u) } }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(model.scannedRoot == nil)
            }
        }

        MenuBarExtra("DiskLens", systemImage: "internaldrive") {
            MenuBarView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

/// Ensures the app shows a Dock icon and a window even when launched from the
/// terminal via `swift run` (not just from the bundled .app).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
