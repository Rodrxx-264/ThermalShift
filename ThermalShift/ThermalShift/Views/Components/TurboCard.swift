import SwiftUI

struct TurboCard: View {
    @Binding var enabled: Bool
    let maxTurboGHz: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.green)

                Text("Turbo Boost")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(.green)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(enabled ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)

                Text(enabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("up to \(String(format: "%.2f", maxTurboGHz)) GHz")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(radius: 14)
    }
}