import SwiftUI

struct PowerLimitControl: View {
    @Binding var pl1: Double
    @Binding var pl2: Double
    var maxValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Power Limits", systemImage: "gauge.with.dots.needle.bottom.50percent")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            row(
                title: "PL1",
                subtitle: "Long term power",
                value: $pl1,
                range: AppState.minPowerWatts...maxValue,
                tint: .indigo,
                symbol: "clock"
            )
            .onChange(of: pl1) { _, newValue in
                if pl2 < newValue {
                    pl2 = newValue
                }
            }

            row(
                title: "PL2",
                subtitle: "Short burst power",
                value: $pl2,
                range: pl1...maxValue,
                tint: .orange,
                symbol: "bolt"
            )
        }
        .padding(16)
        .glassCard(radius: 14)
    }

    private func row(
        title: String,
        subtitle: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        tint: Color,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(value.wrappedValue.rounded()))")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)

                Text("W")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range, step: 1)
                .tint(tint)
        }
    }
}