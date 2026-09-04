import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var showingHistory = false
    @State private var historyKind: MetricKind?
    @State private var showingSettings = false

    var body: some View {
        @Bindable var app = appState

        ZStack {
            background

            VStack(spacing: 20) {
                header

                TemperatureCard(
                    temperature: app.state.temperature,
                    level: level(for: app.state.temperature),
                    policy: app.cpu.temperaturePolicy
                ) {
                    historyKind = .temperature
                    showingHistory = true
                }

                HStack(spacing: 14) {
                    MetricCard(
                        title: "CPU Usage",
                        value: app.state.cpuUsage,
                        format: .percent,
                        symbolName: "cpu",
                        tint: .indigo
                    ) {
                        historyKind = .cpuUsage
                        showingHistory = true
                    }

                    MetricCard(
                        title: "Power",
                        value: app.state.powerWatts,
                        format: .watts,
                        symbolName: "bolt.fill",
                        tint: .orange
                    ) {
                        historyKind = .power
                        showingHistory = true
                    }
                }

                HStack(spacing: 14) {
                    MetricCard(
                        title: "Frequency",
                        value: app.state.frequencyGHz,
                        format: .gigahertz,
                        symbolName: "speedometer",
                        tint: .teal
                    ) {
                        historyKind = .frequency
                        showingHistory = true
                    }

                    TurboCard(
                        enabled: $app.turboEnabled,
                        maxTurboGHz: app.cpu.maxTurboGHz
                    )
                }

                PowerLimitControl(
                    pl1: $app.pl1,
                    pl2: $app.pl2,
                    maxValue: AppState.maxPowerWatts
                )

                VStack(spacing: 10) {
                    ProfileSelector(selection: $app.profile) { profile in
                        appState.applyPreset(profile)
                    }

                    Text(app.profile.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .frame(width: 560)
        .task {
            appState.startMonitoring()
        }
        .sheet(isPresented: $showingHistory) {
            if let kind = historyKind {
                MetricHistoryView(
                    kind: kind,
                    samples: historySamples(for: kind)
                )
                .environment(appState)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(appState)
        }
    }

    private var background: some View {
        ZStack {
            WindowBackground()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.05),
                    .clear,
                    Color.accentColor.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "cpu")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)
            .glassCard(radius: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text("ThermalShift")
                    .font(.title2.weight(.bold))

                Text(appState.cpu.modelName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            .help("Settings")

            StatusBadge(phase: appState.phase)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(live ? Color.green : Color.orange)
                .frame(width: 6, height: 6)

            Text(appState.dataDetail)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.bottom, 2)
    }

    private var live: Bool {
        !appState.dataDetail.contains("Simulated")
            && !appState.dataDetail.contains("estimated")
    }

    private func level(for temperature: Double) -> ThermalLevel {
        ThermalLevel(temperature: temperature, policy: appState.cpu.temperaturePolicy)
    }

    private func historySamples(for kind: MetricKind) -> [MetricSample] {
        switch kind {
        case .temperature: return appState.temperatureHistory
        case .cpuUsage: return appState.cpuUsageHistory
        case .power: return appState.powerHistory
        case .frequency: return appState.frequencyHistory
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
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
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
        case .ready: "Active"
        case .applying: "Applying…"
        case .error: "Error"
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
        .frame(width: 560)
}