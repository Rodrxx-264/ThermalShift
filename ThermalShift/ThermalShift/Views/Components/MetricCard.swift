import SwiftUI

enum MetricFormat {
    case percent
    case watts
    case gigahertz

    func text(for value: Double) -> String {
        switch self {
        case .percent: "\(Int(value.rounded()))"
        case .watts: "\(Int(value.rounded()))"
        case .gigahertz: String(format: "%.2f", value)
        }
    }

    var unit: String {
        switch self {
        case .percent: "%"
        case .watts: "W"
        case .gigahertz: "GHz"
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: Double
    let format: MetricFormat
    let symbolName: String
    let tint: Color
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            content
            if onTap != nil {
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .glassCard(radius: 14)
        .contentShape(Rectangle())
        .ifLet(onTap) { view, action in
            view.onTapGesture(perform: action)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(format.text(for: value))
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text(format.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}