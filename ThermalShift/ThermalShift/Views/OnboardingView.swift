import SwiftUI
import AppKit

struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    private let command = "csrutil enable --without kext"

    var body: some View {
        ZStack {
            WindowBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    steps
                    commandBox
                    actions
                    footnote
                }
                .padding(32)
            }
        }
        .frame(width: 560)
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "lock.shield")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)

            Text("One security step")
                .font(.largeTitle.weight(.bold))

            Text("ThermalShift controls the CPU through VoltageShift, a kernel extension. macOS blocks it while System Integrity Protection is fully enabled.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: .infinity)
        }
    }

    private var steps: some View {
        VStack(spacing: 14) {
            step(
                index: 1,
                title: "Restart your Mac",
                detail: "Press and hold ⌘ Command + R the moment it starts up, until the Recovery screen appears."
            )
            step(
                index: 2,
                title: "Open Terminal",
                detail: "From the menu bar choose Utilities → Terminal."
            )
            step(
                index: 3,
                title: "Run the command",
                detail: "Type the command below, press Return, then restart your Mac normally."
            )
        }
    }

    private var commandBox: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .foregroundStyle(.secondary)

            Text(command)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .glassCard(radius: 12)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await appState.performSystemSetupCheck()
                }
            } label: {
                Label("I restarted — Check again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Button("Continue to Dashboard") {
                appState.skipSetup()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var footnote: some View {
        Text("This check only reads your system and changes nothing. VoltageShift needs a weakened SIP setting so its kernel extension can load; the next step will ask you to approve it in System Settings.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
    }

    private func step(index: Int, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Text("\(index)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(.tint))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(radius: 16)
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
        .frame(width: 560)
}