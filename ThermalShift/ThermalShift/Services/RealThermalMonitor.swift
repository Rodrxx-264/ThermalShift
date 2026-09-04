import Foundation

/// Real system monitor.
///
/// Value sources (always real when available):
///   - CPU usage  – Mach host processor counters (`host_processor_info`)
///   - Temperature– Apple SMC key `TC0P` (CPU PECI reference) on Intel
///   - Frequency / Power – `voltageshift mon` (reads MSR/RAPL) when the
///     VoltageShift kext is loaded; otherwise estimated from usage.
///
/// All sampling runs on a background task so the main thread is never blocked
/// by SMC reads, `kextstat` or the `voltageshift` subprocess.
@MainActor
final class RealThermalMonitor: ThermalMonitoring {

    private var task: Task<Void, Never>?
    nonisolated private let cpu: CPUInfo
    private(set) var current: ThermalState
    var onUpdate: ((ThermalState) -> Void)?
    private(set) var dataDetail = "Starting…"

    nonisolated init(
        cpu: CPUInfo = MockData.cpu,
        initialState: ThermalState = MockData.initialState
    ) {
        self.cpu = cpu
        self.current = initialState
    }

    func start(interval: Double) {
        guard task == nil else { return }
        let cpu = self.cpu
        let initial = self.current

        task = Task.detached(priority: .utility) { [weak self] in
            var sampler = CPUUsageSampler()
            var kextLoaded = false
            var kextCheckCounter = 0
            var frame = 0
            var current = initial

            let sleepInterval = UInt64(interval * 1_000_000_000)

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: sleepInterval)
                guard let self, !Task.isCancelled else { return }

                frame += 1
                kextCheckCounter += 1
                if frame == 1 || kextCheckCounter >= 30 {
                    kextLoaded = VoltageShiftCommand.kextLoaded()
                    kextCheckCounter = 0
                }

                var vs: VoltageShiftSample?
                if kextLoaded, frame % 5 == 0 {
                    vs = VoltageShiftCommand.monitorSample()
                }

                let usage = sampler.sample()
                let peciTemp = SMCAccess.readTemperature()

                let detail: String
                if kextLoaded, let vs {
                    current.frequencyGHz = vs.frequencyGHz
                    current.powerWatts = vs.powerWatts
                    if vs.temperature > 0 {
                        current.temperature = vs.temperature
                    }
                    detail = "VoltageShift · MSR + PECI"
                } else {
                    let load = usage ?? current.cpuUsage
                    current.frequencyGHz = cpu.baseFrequencyGHz
                        + (cpu.maxTurboGHz - cpu.baseFrequencyGHz) * (load / 100.0)
                    current.powerWatts = cpu.tdpWatts * (0.25 + 0.75 * (load / 100.0))
                    detail = kextLoaded
                        ? "VoltageShift"
                        : "PECI probe · estimated freq/power"
                }

                if let usage {
                    current.cpuUsage = usage
                }
                if let peciTemp, (10...125).contains(peciTemp) {
                    current.temperature = peciTemp
                }
                current.timestamp = Date()
                let snapshot = current

                await MainActor.run { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    self.current = snapshot
                    self.dataDetail = detail
                    self.onUpdate?(snapshot)
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}