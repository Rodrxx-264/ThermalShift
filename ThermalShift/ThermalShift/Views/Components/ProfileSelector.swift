import SwiftUI

struct ProfileSelector: View {
    @Binding var selection: ThermalProfile
    var onSelect: (ThermalProfile) -> Void

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ThermalProfile.allCases) { profile in
                Button {
                    selection = profile
                    onSelect(profile)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: profile.symbolName)
                            .font(.system(size: 14, weight: .medium))

                        Text(profile.title)
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .foregroundStyle(selection == profile ? .white : .primary)
                    .background {
                        if selection == profile {
                            Capsule()
                                .fill(.tint)
                                .matchedGeometryEffect(id: "profile-pill", in: pill)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
        .animation(.snappy(duration: 0.3), value: selection)
    }
}