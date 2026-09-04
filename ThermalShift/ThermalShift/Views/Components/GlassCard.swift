import SwiftUI

struct GlassCardModifier: ViewModifier {
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.regularMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func glassCard(radius: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(radius: radius))
    }
}