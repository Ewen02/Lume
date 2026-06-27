import SwiftUI

/// Barre de progression fine et arrondie, conçue pour vivre sur un fond coloré (hero Budget) :
/// piste translucide + remplissage opaque. Le remplissage s'anime à l'apparition et au changement
/// de valeur (Reduce Motion respecté). `progress` est borné [0, 1] par l'appelant (FinanceCalculator).
struct BudgetProgressBar: View {
    var progress: Double
    /// Couleur du remplissage (ex. surface/blanc sur fond encre, ou une teinte d'état).
    var fill: Color = LumeColor.surface
    /// Couleur de la piste (sous le remplissage) — surface translucide sur le fond coloré.
    var track: Color = LumeColor.surface.opacity(LumeOpacity.track)
    var height: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    private var clamped: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill)
                    .frame(width: max(height, animatedProgress * geo.size.width))
            }
        }
        .frame(height: height)
        .onAppear { animate(to: clamped) }
        .onChange(of: clamped) { _, new in animate(to: new) }
    }

    private func animate(to value: Double) {
        if reduceMotion { animatedProgress = value }
        else { withAnimation(LumeMotion.smooth) { animatedProgress = value } }
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        BudgetProgressBar(progress: 0)
        BudgetProgressBar(progress: 0.45)
        BudgetProgressBar(progress: 0.9, fill: LumeColor.warning)
    }
    .padding(Spacing.xxl)
    .background(LumeColor.ink)
}
