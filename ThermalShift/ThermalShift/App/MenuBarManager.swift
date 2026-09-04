import SwiftUI
import AppKit
import Combine
import ServiceManagement

@MainActor
final class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()

    @Published var isMenuBarVisible = true
    @Published var showTemperatureInMenuBar = true

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

    var appState: AppState?

    private init() {}

    func setup(appState: AppState) {
        self.appState = appState
        createStatusItem()
        observeAppState()
        setupMainMenu()
    }

    func setMenuBarVisible(_ visible: Bool) {
        isMenuBarVisible = visible
        statusItem?.isVisible = visible
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        updateMenuBarTitle()
        button.action = #selector(statusItemClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupMainMenu() {
        let mainMenu = NSApp.mainMenu ?? NSMenu()
        
        // Find or create the app menu (first menu)
        let appMenuItem = mainMenu.item(at: 0) ?? {
            let item = NSMenuItem()
            mainMenu.addItem(item)
            return item
        }()
        
        let appMenu = appMenuItem.submenu ?? NSMenu()
        appMenuItem.submenu = appMenu
        
        // Add About item to app menu
        let aboutItem = NSMenuItem(title: "About ThermalShift", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.insertItem(aboutItem, at: 1) // After "About App" if exists
        
        NSApp.mainMenu = mainMenu
    }

    private func observeAppState() {
        guard let appState = appState else { return }

        appState.addStateObserver { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarTitle()
            }
        }
    }

    func updateMenuBarTitle() {
        guard let appState = appState,
              let button = statusItem?.button else { return }

        let temp = Int(appState.state.temperature.rounded())
        let turbo = appState.turboEnabled ? "↑" : "⬇"

        if showTemperatureInMenuBar {
            button.title = "\(temp)° \(turbo)"
            button.font = .systemFont(ofSize: 11, weight: .medium)
        } else {
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "ThermalShift")
            button.title = ""
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        guard let appState = appState,
              let button = statusItem?.button else { return }

        let menu = NSMenu()

        let tempItem = NSMenuItem(title: "CPU: \(Int(appState.state.temperature.rounded()))°C", action: nil, keyEquivalent: "")
        tempItem.isEnabled = false
        menu.addItem(tempItem)

        let usageItem = NSMenuItem(title: "Usage: \(Int(appState.state.cpuUsage.rounded()))%", action: nil, keyEquivalent: "")
        usageItem.isEnabled = false
        menu.addItem(usageItem)

        let powerItem = NSMenuItem(title: "Power: \(Int(appState.state.powerWatts.rounded()))W", action: nil, keyEquivalent: "")
        powerItem.isEnabled = false
        menu.addItem(powerItem)

        menu.addItem(NSMenuItem.separator())

        let turboItem = NSMenuItem(
            title: appState.turboEnabled ? "Disable Turbo Boost" : "Enable Turbo Boost",
            action: #selector(toggleTurboBoost),
            keyEquivalent: "t"
        )
        turboItem.target = self
        turboItem.keyEquivalentModifierMask = [.command]
        menu.addItem(turboItem)

        menu.addItem(NSMenuItem.separator())

        let dashboardItem = NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "d")
        dashboardItem.target = self
        dashboardItem.keyEquivalentModifierMask = [.command]
        menu.addItem(dashboardItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About ThermalShift", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit ThermalShift", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    private func togglePopover() {
        if popover == nil {
            let contentView = MenuBarPopoverView()
                .environment(appState!)

            popover = NSPopover()
            popover?.contentSize = NSSize(width: 280, height: 360)
            popover?.behavior = .transient
            popover?.contentViewController = NSHostingController(rootView: contentView)
        }

        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func toggleTurboBoost() {
        appState?.setTurbo(!(appState?.turboEnabled ?? true))
    }

    @objc private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window.isVisible {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window.isVisible && window.title.contains("Settings") || window.contentViewController?.view is NSHostingView<SettingsView> {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        // Open via Settings scene
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func showAbout() {
        guard let appState = appState else { return }
        AboutWindowController.show(appState: appState)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }

    var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}

struct MenuBarPopoverView: View {
    @Environment(AppState.self) private var appState
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            metricsSection
            Divider()
            controlsSection
            Divider()
            footerSection
        }
        .frame(width: 280)
        .background(.regularMaterial)
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "cpu")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("ThermalShift")
                    .font(.headline)
                Text(appState.cpu.modelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(appState.phase == .ready ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
        }
        .padding(14)
    }

    private var metricsSection: some View {
        HStack(spacing: 20) {
            MetricItem(
                icon: "thermometer.medium",
                value: "\(Int(appState.state.temperature.rounded()))°",
                label: "Temp",
                color: thermalColor
            )

            MetricItem(
                icon: "cpu",
                value: "\(Int(appState.state.cpuUsage.rounded()))%",
                label: "CPU",
                color: .indigo
            )

            MetricItem(
                icon: "bolt.fill",
                value: "\(Int(appState.state.powerWatts.rounded()))W",
                label: "Power",
                color: .orange
            )

            MetricItem(
                icon: "speedometer",
                value: String(format: "%.1f", appState.state.frequencyGHz),
                label: "Freq",
                color: .teal
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var thermalColor: Color {
        let temp = appState.state.temperature
        switch temp {
        case ..<60: return .teal
        case ..<72: return .green
        case ..<82: return .yellow
        case ..<90: return .orange
        default: return .red
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { appState.turboEnabled },
                set: { appState.setTurbo($0) }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.green)
                    Text("Turbo Boost")
                        .font(.subheadline)
                    Spacer()
                    Text(appState.turboEnabled ? "On" : "Off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .tint(.green)

            HStack(spacing: 12) {
                Button {
                    openDashboard()
                } label: {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
    }

    private var footerSection: some View {
        HStack {
            Text("v1.0")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window.isVisible {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
}

private struct MetricItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}