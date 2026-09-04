import SwiftUI
import AppKit

struct AboutWindow: View {
    @Environment(\.dismiss) private var dismiss
    let appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            VStack(spacing: 6) {
                Text("ThermalShift")
                    .font(.largeTitle.weight(.bold))

                Text("Version 1.0")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("Intel Mac thermal management using VoltageShift kernel extension")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Divider()
                .frame(width: 160)

            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    InfoItem(label: "CPU", value: appState.cpu.modelName)
                    InfoItem(label: "TDP", value: "\(Int(appState.cpu.tdpWatts))W")
                }

                HStack(spacing: 24) {
                    InfoItem(label: "Base Freq", value: "\(String(format: "%.2f", appState.cpu.baseFrequencyGHz)) GHz")
                    InfoItem(label: "Max Turbo", value: "\(String(format: "%.2f", appState.cpu.maxTurboGHz)) GHz")
                }

                HStack(spacing: 24) {
                    InfoItem(label: "Kext Status", value: kextStatusText)
                    InfoItem(label: "Data Source", value: dataSourceText)
                }
            }
            .padding(.vertical, 8)

            Divider()
                .frame(width: 160)

            VStack(spacing: 10) {
                Link("GitHub Repository", destination: URL(string: "https://github.com/")!)
                Link("VoltageShift Project", destination: URL(string: "https://github.com/sicreative/VoltageShift")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/")!)
            }
            .font(.callout)

            Spacer()

            HStack(spacing: 12) {
                Button("System Report…") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.general")!)
                }
                .buttonStyle(.bordered)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.cancelAction)
            }

            Text("© 2025 ThermalShift. Built for Intel Macs.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(width: 460, height: 520)
    }

    private var kextStatusText: String {
        switch appState.kextStatus {
        case .kextLoaded: "Loaded ✓"
        case .kextNotLoaded: "Not Loaded"
        case .binaryNotFound: "Binary Missing"
        }
    }

    private var dataSourceText: String {
        if appState.dataDetail.contains("VoltageShift") {
            return "VoltageShift (MSR)"
        } else if appState.dataDetail.contains("PECI") {
            return "SMC (PECI)"
        }
        return "Simulated"
    }
}

private struct InfoItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.5))
        }
    }
}

struct AboutWindowController {
    static func show(appState: AppState) {
        let hostingController = NSHostingController(rootView: AboutWindow(appState: appState))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "About ThermalShift"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("AboutWindow")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}