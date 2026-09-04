import SwiftUI
import AppKit

struct KextApprovalView: View {
    @Environment(AppState.self) private var appState
    @State private var isInstalling = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            WindowBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    statusCard
                    installSection
                    if errorMessage != nil {
                        errorCard
                    }
                    manualSteps
                    footnote
                }
                .padding(28)
                .frame(maxWidth: 480)
            }
        }
        .frame(width: 560)
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
            .frame(width: 80, height: 80)

            Text("Kernel Extension")
                .font(.largeTitle.weight(.bold))

            Text("ThermalShift reads real sensor data through VoltageShift, a kernel extension bundled with the app.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                    .foregroundStyle(statusColor)

                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isInstalling {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var installSection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await install() }
            } label: {
                Label(
                    isInstalling ? "Installing…" : "Install & Load",
                    systemImage: isInstalling ? "gearshape.2" : "bolt.badge.a"
                )
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(isInstalling)

            Text("macOS will ask for permission — enter your password to install the extension.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }

    private var errorCard: some View {
        Group {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.red.opacity(0.08))
                    }
            }
        }
    }

    private var manualSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("If it still doesn't load, allow it manually:")
                .font(.subheadline.weight(.semibold))

            step(1, "Open System Settings", "Go to Privacy & Security. The extension may appear as blocked.")
            step(2, "Allow the developer", "Tap Allow next to the blocked system software message.")
            step(3, "Check again", "Return here and the dashboard activates automatically.")

            Button {
                appState.openSystemSettings()
            } label: {
                Label("Open System Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(16)
        .glassCard(radius: 16)
    }

    private var footnote: some View {
        Button("Continue to Dashboard") {
            appState.skipSetup()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.callout.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.tint))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func install() async {
        isInstalling = true
        errorMessage = nil
        do {
            _ = try await appState.installKext()
        } catch {
            errorMessage = error.localizedDescription
            await appState.performSystemSetupCheck()
        }
        isInstalling = false

        if appState.kextStatus == .kextLoaded {
            await appState.refreshKextStatus()
        }
    }

    private var statusTitle: String {
        switch appState.kextStatus {
        case .kextLoaded: "Extension running"
        case .kextNotLoaded: "Extension not loaded"
        case .binaryNotFound: "Files not bundled"
        }
    }

    private var statusDetail: String {
        switch appState.kextStatus {
        case .kextLoaded: "Real sensor data is now available."
        case .kextNotLoaded: "Install it below or approve it in System Settings."
        case .binaryNotFound: "The extension files could not be located."
        }
    }

    private var statusColor: Color {
        switch appState.kextStatus {
        case .kextLoaded: .green
        case .kextNotLoaded: .orange
        case .binaryNotFound: .red
        }
    }
}

#Preview {
    KextApprovalView()
        .environment(AppState())
        .frame(width: 560)
}