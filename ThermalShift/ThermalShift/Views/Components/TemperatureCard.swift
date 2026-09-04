import SwiftUI

extension ThermalLevel {
    var symbolName: String {
        switch self {
        case .cool: "snowflake"
        case .normal: "thermometer.medium"
        case .warm: "sun.max"
        case .hot: "flame.fill"
        case .critical: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .cool: .teal
        case .normal: .green
        case .warm: .yellow
        case .hot: .orange
        case .critical: .red
        }
    }
}

struct TemperatureCard: View {
    let temperature: Double
    let level: ThermalLevel
    let policy: TemperaturePolicy
    var onTap: (() -> Void)? = nil

    private var fraction: CGFloat {
        let low = 35.0
        let high = max(policy.hotMax + 5, low + 1)
        return CGFloat(min(max((temperature - low) / (high - low), 0), 1))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label("CPU Temperature", systemImage: "thermometer.medium")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                levelChip
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(temperature.rounded()))")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(level.tint)

                Text("°C")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(level.title)
                        .font(.headline)
                        .foregroundStyle(level.tint)

                    Text("for this CPU")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.10))

                    Capsule()
                        .fill(level.tint.gradient)
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 8)
        }
        .padding(20)
        .glassCard(radius: 22)
        .contentShape(Rectangle())
        .ifLet(onTap) { view, action in
            view.onTapGesture(perform: action)
        }
    }

    private var levelChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(level.tint)
                .frame(width: 7, height: 7)

            Text(level.title)
                .font(.caption.weight(.semibold))

            Image(systemName: level.symbolName)
                .font(.caption)
        }
        .foregroundStyle(level.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(level.tint.opacity(0.14))
        }
    }
}