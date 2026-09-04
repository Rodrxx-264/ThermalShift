import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.setupPhase {
            case .checking:
                SetupProgressView()
                    .task {
                        await appState.performSystemSetupCheck()
                    }
            case .fullSIP:
                OnboardingView()
            case .kextApproval:
                KextApprovalView()
            case .ready:
                DashboardView()
            }
        }
    }
}

private struct SetupProgressView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)

            Text("Checking system security…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(width: 560, height: 420)
    }
}