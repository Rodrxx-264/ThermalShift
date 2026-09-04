import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {

    enum ServicePhase: Equatable {
        case ready
        case applying
        case error(String)
    }

    enum SetupPhase: Equatable {
        case checking
        case fullSIP
        case kextApproval
        case ready
    }

    let cpu: CPUInfo

    private(set) var state: ThermalState
    private(set) var setupPhase: SetupPhase = .checking
    // Four separate history arrays (capped at 60 samples each)
    var temperatureHistory: [MetricSample] = []
    var cpuUsageHistory: [MetricSample] = []
    var powerHistory: [MetricSample] = []
    var frequencyHistory: [MetricSample] = []
    private(set) var systemInfo: SystemInfo?
    var profile: ThermalProfile = .balanced
    var pl1: Double
    var pl2: Double
    var turboEnabled: Bool
    private(set) var phase: ServicePhase = .ready
    private(set) var kextStatus: VoltageShiftStatus = .binaryNotFound

    private let monitor: any ThermalMonitoring
    private var monitoringTask: Task<Void, Never>?
    var monitoringInterval: Double = 2.0

    static let minPowerWatts = 5.0
    static let maxPowerWatts = 150.0

    init(
        cpu: CPUInfo = MockData.cpu,
        initialState: ThermalState = MockData.initialState,
        monitor: any ThermalMonitoring = RealThermalMonitor()
    ) {
        self.cpu = cpu
        self.state = initialState
        self.monitor = monitor
        self.pl1 = MockData.cpu.tdpWatts * 0.69
        self.pl2 = MockData.cpu.tdpWatts
        self.turboEnabled = true
        self.systemInfo = SystemInfoProvider.syncInfo()

        monitor.onUpdate = { [weak self] snapshot in
            guard let self else { return }
            self.state = snapshot
            // Append to the appropriate history array
            if snapshot.temperature.isFinite {
                self.temperatureHistory.append(MetricSample(date: snapshot.timestamp, value: snapshot.temperature))
                if self.temperatureHistory.count > 60 { self.temperatureHistory.removeFirst() }
            }
            if snapshot.cpuUsage.isFinite {
                self.cpuUsageHistory.append(MetricSample(date: snapshot.timestamp, value: snapshot.cpuUsage))
                if self.cpuUsageHistory.count > 60 { self.cpuUsageHistory.removeFirst() }
            }
            if snapshot.powerWatts.isFinite {
                self.powerHistory.append(MetricSample(date: snapshot.timestamp, value: snapshot.powerWatts))
                if self.powerHistory.count > 60 { self.powerHistory.removeFirst() }
            }
            if snapshot.frequencyGHz.isFinite {
                self.frequencyHistory.append(MetricSample(date: snapshot.timestamp, value: snapshot.frequencyGHz))
                if self.frequencyHistory.count > 60 { self.frequencyHistory.removeFirst() }
            }
        }
    }

    var dataDetail: String {
        monitor.dataDetail
    }

    func startMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.monitor.start(interval: self.monitoringInterval)
        }
    }

    func updateMonitoringInterval(_ interval: Double) {
        monitoringInterval = interval
        startMonitoring()
    }

    func addStateObserver(_ callback: @escaping (ThermalState) -> Void) {
        let originalOnUpdate = monitor.onUpdate
        monitor.onUpdate = { snapshot in
            originalOnUpdate?(snapshot)
            callback(snapshot)
        }
    }

    // MARK: - Setup

    func performSystemSetupCheck() async {
        setupPhase = .checking
        let result = await Task.detached(operation: {
            (SystemIntegrityChecker.status(), VoltageShiftCommand.status())
        }).value

        kextStatus = result.1

        switch result.0 {
        case .kextsAllowed, .sipDisabled:
            setupPhase = result.1 == .kextLoaded ? .ready : .kextApproval
        case .fullSIP, .unknown:
            setupPhase = .fullSIP
        }
    }

    func skipSetup() {
        setupPhase = .ready
    }

    func refreshKextStatus() async {
        kextStatus = await Task.detached(operation: {
            VoltageShiftCommand.status()
        }).value
        if kextStatus == .kextLoaded {
            setupPhase = .ready
        }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    func installKext() async throws -> Bool {
        try await KextInstaller.install()

        kextStatus = await Task.detached(operation: {
            VoltageShiftCommand.status()
        }).value
        if kextStatus == .kextLoaded {
            setupPhase = .ready
        }
        return kextStatus == .kextLoaded
    }

    // MARK: - Control

    func applyPreset(_ profile: ThermalProfile) {
        guard profile != .custom else { return }
        let limits = limits(for: profile)
        let pl1Int = Int(limits.pl1.rounded())
        let pl2Int = Int(limits.pl2.rounded())

        phase = .applying
        withAnimation(.snappy(duration: 0.5)) {
            self.profile = profile
            self.pl1 = limits.pl1
            self.pl2 = limits.pl2
            self.turboEnabled = limits.turbo
        }

        // Execute the voltageshift commands
        Task.detached(priority: .utility) { @MainActor [weak self] in
            guard let self else { return }
            let pl1Success = VoltageShiftCommand.setPL1(pl1Int)
            let pl2Success = VoltageShiftCommand.setPL2(pl2Int)
            let turboSuccess = VoltageShiftCommand.setTurbo(limits.turbo)

            if !pl1Success || !pl2Success || !turboSuccess {
                self.phase = .error("Failed to apply profile")
                try? await Task.sleep(for: .seconds(2))
                if self.phase == .error("Failed to apply profile") {
                    self.phase = .ready
                }
            } else {
                self.phase = .ready
            }
        }
    }

    func setPL1(_ value: Double) {
        let clamped = min(max(value, Self.minPowerWatts), Self.maxPowerWatts)
        let intValue = Int(clamped.rounded())
        guard intValue != Int(pl1.rounded()) else { return }
        withAnimation(.snappy(duration: 0.4)) {
            pl1 = clamped
            if pl2 < clamped {
                pl2 = clamped
            }
            if profile != .custom {
                profile = .custom
            }
        }

        Task.detached(priority: .utility) { @MainActor [weak self] in
            guard let self else { return }
            let success = VoltageShiftCommand.setPL1(intValue)
            if !success {
                self.phase = .error("Failed to set PL1")
                try? await Task.sleep(for: .seconds(2))
                if self.phase == .error("Failed to set PL1") {
                    self.phase = .ready
                }
            }
        }
    }

    func setPL2(_ value: Double) {
        let clamped = min(max(value, pl1), Self.maxPowerWatts)
        let intValue = Int(clamped.rounded())
        guard intValue != Int(pl2.rounded()) else { return }
        withAnimation(.snappy(duration: 0.4)) {
            pl2 = clamped
            if profile != .custom {
                profile = .custom
            }
        }

        Task.detached(priority: .utility) { @MainActor [weak self] in
            guard let self else { return }
            let success = VoltageShiftCommand.setPL2(intValue)
            if !success {
                self.phase = .error("Failed to set PL2")
                try? await Task.sleep(for: .seconds(2))
                if self.phase == .error("Failed to set PL2") {
                    self.phase = .ready
                }
            }
        }
    }

    func setTurbo(_ enabled: Bool) {
        guard enabled != turboEnabled else { return }
        withAnimation(.snappy(duration: 0.4)) {
            turboEnabled = enabled
            if profile != .custom {
                profile = .custom
            }
        }

        Task.detached(priority: .utility) { @MainActor [weak self] in
            guard let self else { return }
            let success = VoltageShiftCommand.setTurbo(enabled)
            if !success {
                self.phase = .error("Failed to set turbo boost")
                self.turboEnabled = !enabled
                try? await Task.sleep(for: .seconds(2))
                if self.phase == .error("Failed to set turbo boost") {
                    self.phase = .ready
                }
            }
        }
    }

    func limits(for profile: ThermalProfile) -> (pl1: Double, pl2: Double, turbo: Bool) {
        let tdp = cpu.tdpWatts
        switch profile {
        case .quiet:
            return (tdp * 0.38, tdp * 0.52, false)
        case .balanced:
            return (tdp * 0.69, tdp, true)
        case .performance:
            return (tdp * 0.85, tdp * 1.4, true)
        case .custom:
            return (pl1, pl2, turboEnabled)
        }
    }
}