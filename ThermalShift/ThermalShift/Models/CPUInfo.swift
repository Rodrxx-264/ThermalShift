import Foundation

nonisolated struct TemperaturePolicy: Equatable {
    let coolMax: Double
    let normalMax: Double
    let warmMax: Double
    let hotMax: Double

    static let defaultIntel = TemperaturePolicy(
        coolMax: 60,
        normalMax: 72,
        warmMax: 82,
        hotMax: 90
    )
}

nonisolated struct CPUInfo: Equatable {
    let modelName: String
    let marketingName: String
    let coreCount: Int
    let threadCount: Int
    let architecture: String
    let baseFrequencyGHz: Double
    let maxTurboGHz: Double
    let tdpWatts: Double
    let temperaturePolicy: TemperaturePolicy
}