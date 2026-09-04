import Foundation

nonisolated struct ThermalState: Equatable {
    var temperature: Double
    var cpuUsage: Double
    var frequencyGHz: Double
    var powerWatts: Double
    var timestamp: Date

    static let placeholder = ThermalState(
        temperature: 0,
        cpuUsage: 0,
        frequencyGHz: 0,
        powerWatts: 0,
        timestamp: .distantPast
    )
}

nonisolated enum ThermalLevel: String, CaseIterable, Equatable {
    case cool
    case normal
    case warm
    case hot
    case critical

    init(temperature: Double, policy: TemperaturePolicy) {
        switch temperature {
        case ..<policy.coolMax: self = .cool
        case ..<policy.normalMax: self = .normal
        case ..<policy.warmMax: self = .warm
        case ..<policy.hotMax: self = .hot
        default: self = .critical
        }
    }

    var title: String {
        rawValue.capitalized
    }

    var order: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

extension ThermalLevel: Comparable {
    static func < (lhs: ThermalLevel, rhs: ThermalLevel) -> Bool {
        lhs.order < rhs.order
    }
}