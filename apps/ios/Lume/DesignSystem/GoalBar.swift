import SwiftUI

/// Ligne d'objectif : libellé + valeur + barre de progression horizontale.
/// Utilisé pour les objectifs hebdomadaires (jours suivis, séances…).
struct GoalBar: View {
    var label: String
    var value: String
    /// Progression 0...1 (plafonnée à l'affichage).
    var progress: Double
    var tint: Color = LumeColor.ink

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(label).font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary)
                Spacer()
                Text(value).font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LumeColor.faint)
                    Capsule().fill(tint)
                        .frame(width: max(0, min(1, progress)) * geo.size.width)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        GoalBar(label: "Jours suivis", value: "5/7", progress: 5.0 / 7, tint: LumeColor.protein)
        GoalBar(label: "Séances muscu", value: "2/3", progress: 2.0 / 3, tint: LumeColor.success)
    }
    .padding()
    .background(LumeColor.cream)
}
