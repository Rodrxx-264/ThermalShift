import SwiftUI
import ServiceManagement

@main
struct ThermalShiftApp: App {
    @State private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 560, height: 900)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environment(appState)
        }
    }

    private var colorScheme: ColorScheme? {
        switch UserDefaults.standard.string(forKey: "colorScheme") ?? "system" {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let appState = AppState()
        MenuBarManager.shared.setup(appState: appState)

        if MenuBarManager.shared.isLaunchAtLoginEnabled {
            MenuBarManager.shared.setLaunchAtLogin(true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}