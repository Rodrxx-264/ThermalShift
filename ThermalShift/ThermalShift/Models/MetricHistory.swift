import Foundation

nonisolated struct MetricSample: Equatable, Identifiable {
    var date: Date
    var value: Double

    var id: Date { date }
}

nonisolated struct MetricHistory: Equatable {
    var temperature: [MetricSample]
    var cpuUsage: [MetricSample]
    var power: [MetricSample]
    var frequency: [MetricSample]

    var isEmpty: Bool {
        temperature.isEmpty && cpuUsage.isEmpty && power.isEmpty && frequency.isEmpty
    }

    static let sampleWindow = 60

    mutating func append(_ state: ThermalState) {
        let sample = MetricSample(date: state.timestamp, value: state.temperature)
        temperature.append(sample)
        if temperature.count > Self.sampleWindow {
            temperature.removeFirst()
        }

        let usage = MetricSample(date: state.timestamp, value: state.cpuUsage)
        cpuUsage.append(usage)
        if cpuUsage.count > Self.sampleWindow {
            cpuUsage.removeFirst()
        }

        let energy = MetricSample(date: state.timestamp, value: state.powerWatts)
        power.append(energy)
        if power.count > Self.sampleWindow {
            power.removeFirst()
        }

        let speed = MetricSample(date: state.timestamp, value: state.frequencyGHz)
        frequency.append(speed)
        if frequency.count > Self.sampleWindow {
            frequency.removeFirst()
        }
    }
}

nonisolated enum MetricKind: String, CaseIterable, Identifiable {
    case temperature
    case cpuUsage
    case power
    case frequency

    var id: Self { self }

    var title: String {
        switch self {
        case .temperature: "Temperature"
        case .cpuUsage: "CPU Usage"
        case .power: "Power"
        case .frequency: "Frequency"
        }
    }

    var symbolName: String {
        switch self {
        case .temperature: "thermometer.medium"
        case .cpuUsage: "cpu"
        case .power: "bolt.fill"
        case .frequency: "speedometer"
        }
    }

    var unit: String {
        switch self {
        case .temperature: "°C"
        case .cpuUsage: "%"
        case .power: "W"
        case .frequency: "GHz"
        }
    }

    func history(in history: MetricHistory) -> [MetricSample] {
        switch self {
        case .temperature: history.temperature
        case .cpuUsage: history.cpuUsage
        case .power: history.power
        case .frequency: history.frequency
        }
    }
}