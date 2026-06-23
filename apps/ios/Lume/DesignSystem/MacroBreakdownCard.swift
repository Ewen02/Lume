import SwiftUI

/// Carte de répartition des macros du jour : barre empilée P/G/L (proportions de calories)
/// + reste à manger par macro vs cible.
struct MacroBreakdownCard: View {
    let consumed: Macros
    let target: Macros

    private var split: (protein: Double, carbs: Double, fat: Double) {
        consumed.split
    }

    var body: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Répartition du jour").font(.lumeHeadline).foregroundStyle(LumeColor.ink)

                // Barre empilée des proportions caloriques.
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        segment(width: split.protein * geo.size.width, color: LumeColor.protein)
                        segment(width: split.carbs * geo.size.width, color: LumeColor.carbs)
                        segment(width: split.fat * geo.size.width, color: LumeColor.fat)
                        if consumed.macroKcal == 0 {
                            Capsule().fill(LumeColor.faint).frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: 12)

                // Reste à manger par macro.
                HStack(spacing: Spacing.md) {
                    remaining("P", consumed.protein, target.protein, LumeColor.protein)
                    remaining("G", consumed.carbs, target.carbs, LumeColor.carbs)
                    remaining("L", consumed.fat, target.fat, LumeColor.fat)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func segment(width: CGFloat, color: Color) -> some View {
        if width > 0 {
            Capsule().fill(color).frame(width: max(0, width))
        }
    }

    private func remaining(_ letter: String, _ value: Int, _ goal: Int, _ color: Color) -> some View {
        let left = max(0, goal - value)
        return VStack(spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(letter).font(.lumeCaption.weight(.bold)).foregroundStyle(LumeColor.ink)
            }
            Text(left > 0 ? "\(left) g" : "✓").font(.lumeSubhead.weight(.semibold))
                .foregroundStyle(left > 0 ? LumeColor.ink : LumeColor.success).monospacedDigit()
            Text(left > 0 ? "restants" : "atteint").font(.lumeCaption).foregroundStyle(LumeColor.muted)
        }.frame(maxWidth: .infinity)
    }
}

#Preview {
    MacroBreakdownCard(consumed: Macros(kcal: 1450, protein: 88, carbs: 165, fat: 48),
                       target: Macros(kcal: 2400, protein: 150, carbs: 270, fat: 80))
        .padding()
        .background(LumeColor.cream)
}
