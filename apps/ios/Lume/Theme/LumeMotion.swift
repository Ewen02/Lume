import SwiftUI

/// Tokens de mouvement — spring-first, comme les apps Apple (les springs sont l'animation par défaut du système).
enum LumeMotion {
    static let snappy: Animation = .snappy(duration: 0.3)
    static let smooth: Animation = .smooth(duration: 0.45)
    static let bouncy: Animation = .spring(response: 0.42, dampingFraction: 0.72)
    static let press: Animation = .spring(response: 0.25, dampingFraction: 0.7)
    /// Rebond marqué pour les moments de récompense (ajout repas, objectif atteint).
    static let celebrate: Animation = .spring(response: 0.35, dampingFraction: 0.5)
    /// Apparition/disparition rapide du flash d'obturateur.
    static let flashIn: Animation = .easeOut(duration: 0.08)
    static let flashOut: Animation = .easeIn(duration: 0.18)
}

/// Effet d'appui réutilisable (léger scale + atténuation), respectant Reduce Motion.
/// À utiliser via `.buttonStyle(.lumePress)`.
struct LumePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(LumeMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LumePressStyle {
    static var lumePress: LumePressStyle {
        LumePressStyle()
    }
}
