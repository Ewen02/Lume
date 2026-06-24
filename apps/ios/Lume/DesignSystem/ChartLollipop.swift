import SwiftUI

/// Bulle d'annotation affichée au-dessus d'un graphe quand on touche un point (scrub) :
/// valeur principale + date, avec un emplacement d'actions optionnel (ex. éditer/supprimer).
/// Généralise le motif inline de l'ancien graphe poids pour tous les graphes interactifs.
struct ChartLollipop<Actions: View>: View {
    var title: String
    var subtitle: String
    var tint: Color = LumeColor.ink
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                Text(title).font(.lumeSubhead.weight(.bold)).foregroundStyle(tint).monospacedDigit()
                Text(subtitle).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }
            actions()
        }
        .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
        .background(LumeColor.surface, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .lumeShadow(.soft)
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        ChartLollipop(title: "1 850 kcal", subtitle: "22 juin")
        ChartLollipop(title: "−350 kcal", subtitle: "23 juin", tint: LumeColor.success)
    }
    .padding()
    .background(LumeColor.cream)
}

extension ChartLollipop where Actions == EmptyView {
    /// Variante lecture seule (valeur + date, sans actions).
    init(title: String, subtitle: String, tint: Color = LumeColor.ink) {
        self.init(title: title, subtitle: subtitle, tint: tint) { EmptyView() }
    }
}
