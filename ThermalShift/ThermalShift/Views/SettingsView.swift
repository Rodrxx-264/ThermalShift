import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = true
    @AppStorage("showTempInMenuBar") private var showTempInMenuBar: Bool = true
    @AppStorage("updateInterval") private var updateInterval: Double = 2.0

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            advancedTab
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 400)
    }

    private var generalTab: some View {
        Form {
            Section("Application") {
                Toggle("Show in Menu Bar", isOn: $showInMenuBar)
                    .onChange(of: showInMenuBar) { _, newValue in
                        MenuBarManager.shared.setMenuBarVisible(newValue)
                    }

                Toggle("Show Temperature in Menu Bar", isOn: $showTempInMenuBar)
                    .onChange(of: showTempInMenuBar) { _, newValue in
                        MenuBarManager.shared.showTemperatureInMenuBar = newValue
                        MenuBarManager.shared.updateMenuBarTitle()
                    }

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        MenuBarManager.shared.setLaunchAtLogin(newValue)
                    }

                Divider()

                HStack {
                    Text("Update Interval")
                    Spacer()
                    Picker("", selection: $updateInterval) {
                        Text("1 second").tag(1.0)
                        Text("2 seconds").tag(2.0)
                        Text("3 seconds").tag(3.0)
                        Text("5 seconds").tag(5.0)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    .onChange(of: updateInterval) { _, newValue in
                        appState.updateMonitoringInterval(newValue)
                    }
                }
            }

            Section("CPU Profiles") {
                Picker("Default Profile", selection: Binding(
                    get: { appState.profile },
                    set: { appState.profile = $0 }
                )) {
                    ForEach(ThermalProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var appearanceTab: some View {
        Form {
            Section("Theme") {
                Picker("Color Scheme", selection: $colorScheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("Menu Bar") {
                Toggle("Show Temperature", isOn: $showTempInMenuBar)
                    .onChange(of: showTempInMenuBar) { _, newValue in
                        MenuBarManager.shared.showTemperatureInMenuBar = newValue
                        MenuBarManager.shared.updateMenuBarTitle()
                    }

                Picker("Display Style", selection: $showTempInMenuBar) {
                    Text("Temperature + Turbo").tag(true)
                    Text("Icon Only").tag(false)
                }
                .pickerStyle(.segmented)
            }

            Section("Dashboard") {
                Toggle("Show Temperature Graph", isOn: .constant(true))
                Toggle("Show Power Graph", isOn: .constant(true))
                Toggle("Show Frequency Graph", isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var advancedTab: some View {
        Form {
            Section("Kext Management") {
                HStack {
                    Text("VoltageShift Kext")
                    Spacer()
                    StatusBadge(phase: appState.kextStatus == .kextLoaded ? .ready : .error(""))
                }

                Button("Reinstall Kext") {
                    Task { await reinstallKext() }
                }
                .disabled(appState.phase == .applying)

                Button("Open Privacy & Security") {
                    MenuBarManager.shared.appState?.openSystemSettings()
                }
            }

            Section("Debug") {
                HStack {
                    Text("Data Source")
                    Spacer()
                    Text(appState.dataDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Copy Debug Info") {
                    copyDebugInfo()
                }

                Button("Reset All Settings") {
                    resetSettings()
                }
                .foregroundStyle(.red)
            }

            Section("Danger Zone") {
                Button("Uninstall Kext") {
                    uninstallKext()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("ThermalShift")
                .font(.largeTitle.weight(.bold))

            Text("Version 1.0")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Intel Mac thermal management using VoltageShift kernel extension")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Divider()
                .frame(width: 200)

            VStack(spacing: 8) {
                Link("GitHub Repository", destination: URL(string: "https://github.com/")!)
                Link("VoltageShift Project", destination: URL(string: "https://github.com/sicreative/VoltageShift")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/")!)
            }
            .font(.callout)

            Spacer()

            Text("© 2025 ThermalShift. Built for Intel Macs.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reinstallKext() async {
        do {
            try await appState.installKext()
        } catch {
            print("Kext reinstall failed: \(error)")
        }
    }

    private func copyDebugInfo() {
        let info = """
        ThermalShift Debug Info
        ======================
        CPU: \(appState.cpu.modelName)
        TDP: \(appState.cpu.tdpWatts)W
        Base Freq: \(appState.cpu.baseFrequencyGHz)GHz
        Max Turbo: \(appState.cpu.maxTurboGHz)GHz
        Kext Status: \(appState.kextStatus)
        Data Source: \(appState.dataDetail)
        Temperature: \(appState.state.temperature)°C
        CPU Usage: \(appState.state.cpuUsage)%
        Power: \(appState.state.powerWatts)W
        Frequency: \(appState.state.frequencyGHz)GHz
        Turbo: \(appState.turboEnabled ? "On" : "Off")
        PL1: \(appState.pl1)W
        PL2: \(appState.pl2)W
        Profile: \(appState.profile.title)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }

    private func resetSettings() {
        colorScheme = "system"
        launchAtLogin = false
        showInMenuBar = true
        showTempInMenuBar = true
        updateInterval = 2.0
        appState.profile = .balanced
        appState.pl1 = appState.cpu.tdpWatts * 0.69
        appState.pl2 = appState.cpu.tdpWatts
        appState.turboEnabled = true
    }

    private func uninstallKext() {
        let script = """
        /bin/rm -rf "/Library/Extensions/VoltageShift.kext"
        /usr/bin/touch "/System/Library/Extensions"
        exit 0
        """

        let escapedScript = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        let osascript = """
        do shell script "\(escapedScript)" with administrator privileges
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", osascript]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Uninstall failed: \(error)")
        }

        Task {
            await appState.refreshKextStatus()
        }
    }
}

private struct StatusBadge: View {
    let phase: AppState.ServicePhase

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(label)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
    }

    private var tint: Color {
        switch phase {
        case .ready: .green
        case .applying: .orange
        case .error: .red
        }
    }

    private var label: String {
        switch phase {
        case .ready: "Loaded"
        case .applying: "Working…"
        case .error: "Error"
        }
    }
}