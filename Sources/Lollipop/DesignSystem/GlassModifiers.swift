import SwiftUI

struct LiquidGlassSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat
    var interactive: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    interactive ? .regular.interactive() : .regular,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            content
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 0.75)
                )
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        }
    }
}

struct LiquidGlassCapsuleModifier: ViewModifier {
    var interactive: Bool
    var tint: Color?

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            let base = tint.map { Glass.regular.tint($0) } ?? .regular
            content
                .glassEffect(interactive ? base.interactive() : base, in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.75))
        }
    }
}

extension View {
    func liquidGlassSurface(cornerRadius: CGFloat = 20, interactive: Bool = false) -> some View {
        modifier(LiquidGlassSurfaceModifier(cornerRadius: cornerRadius, interactive: interactive))
    }

    func liquidGlassCapsule(interactive: Bool = true, tint: Color? = nil) -> some View {
        modifier(LiquidGlassCapsuleModifier(interactive: interactive, tint: tint))
    }
}
