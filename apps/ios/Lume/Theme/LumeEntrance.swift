import SwiftUI

/// Animation d'entrée réutilisable : fondu + léger glissement vers le haut,
/// décalé (stagger) selon `index`. Respecte Reduce Motion (apparition immédiate, sans mouvement).
struct LumeEntrance: ViewModifier {
    var index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: (appeared || reduceMotion) ? 0 : 14)
            .onAppear {
                if reduceMotion { appeared = true }
                else { withAnimation(LumeMotion.smooth.delay(Double(index) * 0.06)) { appeared = true } }
            }
    }
}

extension View {
    /// Fondu + glissement d'entrée, décalé selon `index` (0 = premier bloc).
    func lumeEntrance(_ index: Int = 0) -> some View {
        modifier(LumeEntrance(index: index))
    }
}
