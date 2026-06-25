import SwiftUI
import AppKit

@main
struct DiskLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()
    @AppStorage("appearance") private var appearance = "system"

    /// nil = follow the Mac's light/dark setting.
    private var scheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .tint(.brand)
                .preferredColorScheme(scheme)
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
            MenuBarView(model: model).preferredColorScheme(scheme)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().preferredColorScheme(scheme)
        }
    }
}

/// Ensures the app shows a Dock icon and a window even when launched from the
/// terminal via `swift run` (not just from the bundled .app).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DiskGaugeController.shared.restoreIfNeeded()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
