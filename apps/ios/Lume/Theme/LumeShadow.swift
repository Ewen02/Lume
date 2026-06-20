import SwiftUI

enum LumeShadowStyle { case soft, card, elevated, fab }

private struct LumeShadow: ViewModifier {
    let style: LumeShadowStyle
    func body(content: Content) -> some View {
        switch style {
        case .soft: content.shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        case .card: content.shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
        case .elevated: content.shadow(color: .black.opacity(0.10), radius: 28, x: 0, y: 14)
        case .fab: content.shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 10)
        }
    }
}

extension View {
    func lumeShadow(_ style: LumeShadowStyle = .card) -> some View {
        modifier(LumeShadow(style: style))
    }
}
