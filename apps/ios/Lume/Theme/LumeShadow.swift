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

/// Halo coloré pour les moments de célébration (anneau qui « claque », record qui apparaît).
/// Distinct de `lumeShadow` (ombre de profondeur) : ici c'est une lueur teintée, animable via
/// `active`. Le rayon vit dans le token (pas de valeur magique dans les écrans).
private struct LumeGlow: ViewModifier {
    let color: Color
    let active: Bool
    /// Intensité du halo (opacité à pleine puissance).
    var intensity: Double = 0.6
    func body(content: Content) -> some View {
        content.shadow(color: color.opacity(active ? intensity : 0), radius: active ? 16 : 0)
    }
}

extension View {
    /// Lueur teintée de célébration (s'allume quand `active`). Voir `LumeGlow`.
    func lumeGlow(_ color: Color, active: Bool, intensity: Double = 0.6) -> some View {
        modifier(LumeGlow(color: color, active: active, intensity: intensity))
    }
}
