import SwiftUI

/// Ligne d'objectif : libellé + valeur + barre de progression horizontale.
/// Utilisé pour les objectifs hebdomadaires (jours suivis, séances…).
struct GoalBar: View {
    var label: String
    var value: String
    /// Progression 0...1 (plafonnée à l'affichage).
    var progress: Double
    var tint: Color = LumeColor.ink
    /// Icône optionnelle en fin de libellé (ex. coche verte « catégorie sous budget »).
    var trailingAccessory: AppIcon? = nil
    var accessoryTint: Color = LumeColor.success

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fill: Double = 0

    private var clamped: Double {
        max(0, min(1, progress))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text(label).font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary)
                if let trailingAccessory {
                    Image(appIcon: trailingAccessory).lumeIcon(12, weight: .bold).foregroundStyle(accessoryTint)
                }
                Spacer()
                Text(value).font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LumeColor.faint)
                    // Remplissage animé à l'apparition / au changement ; teinte fondue (under→near→over).
                    Capsule().fill(tint)
                        .frame(width: fill * geo.size.width)
                        .animation(reduceMotion ? nil : LumeMotion.smooth, value: tint)
                }
            }
            .frame(height: 8)
        }
        .onAppear { apply(clamped) }
        .onChange(of: progress) { _, _ in apply(clamped) }
    }

    private func apply(_ value: Double) {
        if reduceMotion { fill = value }
        else { withAnimation(LumeMotion.smooth) { fill = value } }
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
