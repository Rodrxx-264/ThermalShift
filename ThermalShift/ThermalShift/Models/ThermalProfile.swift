import Foundation

nonisolated enum ThermalProfile: String, CaseIterable, Identifiable, Equatable {
    case quiet
    case balanced
    case performance
    case custom

    var id: Self { self }

    var title: String {
        rawValue.capitalized
    }

    var symbolName: String {
        switch self {
        case .quiet: "leaf"
        case .balanced: "scale.balanced"
        case .performance: "bolt.fill"
        case .custom: "slider.horizontal.3"
        }
    }

    var summary: String {
        switch self {
        case .quiet: "Silent. Cooler. Slower."
        case .balanced: "A good everyday balance."
        case .performance: "Maximum frequency for demanding work."
        case .custom: "Your own power limits and turbo."
        }
    }
}