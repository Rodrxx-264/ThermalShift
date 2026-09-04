import SwiftUI
import Charts

struct MetricHistoryView: View {
    let kind: MetricKind
    let samples: [MetricSample]

    @Environment(\.dismiss) private var dismiss

    private var currentValue: Double? {
        samples.last?.value
    }

    private var maxValue: Double? {
        samples.map(\.value).max()
    }

    private var minValue: Double? {
        samples.map(\.value).min()
    }

    var body: some View {
        VStack(spacing: 18) {
            header

            if samples.count > 1 {
                chart
            } else {
                ContentUnavailableView(
                    "Collecting data…",
                    systemImage: kind.symbolName,
                    description: Text("History appears after a few seconds.")
                )
            }
        }
        .padding(24)
        .frame(width: 460, height: 420)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.16))

                Image(systemName: kind.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title)
                    .font(.title3.weight(.bold))

                if let currentValue {
                    Text("\(formatted(currentValue))\(kind.unit) · last 60 s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
            }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value(kind.title, sample.value)
                )
                .foregroundStyle(tint)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                AreaMark(
                    x: .value("Time", sample.date),
                    y: .value(kind.title, sample.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint.opacity(0.35), tint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.second())
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xDomain)
        .frame(height: 260)
        .padding(8)
        .glassCard(radius: 16)
    }

    private var yDomain: ClosedRange<Double> {
        guard let minValue, let maxValue else { return 0...100 }
        let pad = max((maxValue - minValue) * 0.15, 1)
        return (minValue - pad)...(maxValue + pad)
    }

    private var xDomain: ClosedRange<Date> {
        guard let first = samples.first?.date, let last = samples.last?.date else {
            return Date()...Date()
        }
        let range = max(last.timeIntervalSince(first), 60)
        return (last - range)...last
    }

    private var tint: Color {
        switch kind {
        case .temperature: .orange
        case .cpuUsage: .indigo
        case .power: .pink
        case .frequency: .teal
        }
    }

    private func formatted(_ value: Double) -> String {
        switch kind {
        case .frequency:
            String(format: "%.2f", value)
        default:
            String(format: "%.0f", value)
        }
    }
}