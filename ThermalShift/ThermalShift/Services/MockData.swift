import Foundation

nonisolated enum MockData {
    static let cpu = CPUInfo(
        modelName: "Intel Core i7-8700B",
        marketingName: "Mac mini (2018)",
        coreCount: 6,
        threadCount: 12,
        architecture: "x86_64",
        baseFrequencyGHz: 3.20,
        maxTurboGHz: 4.60,
        tdpWatts: 65,
        temperaturePolicy: .defaultIntel
    )

    static let initialState = ThermalState(
        temperature: 67,
        cpuUsage: 34,
        frequencyGHz: 3.42,
        powerWatts: 24,
        timestamp: Date()
    )
}

@MainActor
final class MockThermalMonitor: ThermalMonitoring {

    private var task: Task<Void, Never>?
    private let cpu: CPUInfo
    private(set) var current: ThermalState
    var onUpdate: ((ThermalState) -> Void)?
    var dataDetail: String { "Simulated" }

    nonisolated init(
        cpu: CPUInfo = MockData.cpu,
        initialState: ThermalState = MockData.initialState
    ) {
        self.cpu = cpu
        self.current = initialState
    }

    func start(interval: Double) {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self else { return }
                self.tick()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func tick() {
        var next = current
        next.temperature = walk(current.temperature, step: 2.4, in: 46...93)
        next.cpuUsage = walk(current.cpuUsage, step: 9, in: 4...100)
        next.frequencyGHz = walk(
            current.frequencyGHz,
            step: 0.42,
            in: cpu.baseFrequencyGHz...cpu.maxTurboGHz
        )
        next.powerWatts = walk(current.powerWatts, step: 5, in: 2...95)
        next.timestamp = Date()
        current = next
        onUpdate?(next)
    }

    private func walk(_ value: Double, step: Double, in range: ClosedRange<Double>) -> Double {
        let delta = Double.random(in: -step...step)
        return min(max(value + delta, range.lowerBound), range.upperBound)
    }
}