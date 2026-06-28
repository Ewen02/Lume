import SwiftUI

struct MacroCard: View {
    var letter: String
    var value: Int
    var goal: Int
    var color: Color
    var label: LocalizedStringKey
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// L'objectif vient-il d'être atteint (≥ 100 %) ? Déclenche le « claquement » de l'anneau.
    @State private var reached = false

    private var isReached: Bool { goal > 0 && value >= goal }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(value)").font(.lumeCallout.weight(.heavy)).foregroundStyle(LumeColor.ink)
                    .monospacedDigit().contentTransition(.numericText(value: Double(value)))
                Text("/\(goal)").font(.lumeCaption).foregroundStyle(LumeColor.muted)
            }
            .animation(LumeMotion.snappy, value: value)
            ProgressRing(progress: Double(value) / Double(max(goal, 1)), color: color, lineWidth: 5) {
                // Coche de validation quand la cible est atteinte, sinon la lettre de la macro.
                Group {
                    if isReached {
                        Image(appIcon: .validate).lumeIcon(15, weight: .bold).foregroundStyle(color)
                    } else {
                        Text(letter).font(.lumeSubhead.weight(.bold)).foregroundStyle(color)
                    }
                }
                .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 46, height: 46)
            // « Claquement » : l'anneau gonfle brièvement et un halo coloré pulse à l'atteinte.
            .scaleEffect(reached ? 1.12 : 1)
            .lumeGlow(color, active: reached)
            Text(label).font(.lumeCaption).foregroundStyle(LumeColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .lumeShadow(.soft)
        // Détecte le passage (montant) à 100 % et joue le claquement + haptique, une fois par franchissement.
        // Repli auto via `.delay` (pas de DispatchQueue : survivrait à la disparition de la cellule).
        .onChange(of: isReached) { _, nowReached in
            guard nowReached, !reduceMotion else { return }
            withAnimation(LumeMotion.celebrate) { reached = true }
            withAnimation(LumeMotion.smooth.delay(0.5)) { reached = false }
        }
        .sensoryFeedback(.success, trigger: isReached) { old, new in !old && new }
    }
}

/// Grand bloc calories (chiffre + anneau).
struct CalorieCard: View {
    var consumed: Int
    var goal: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// L'objectif calorique du jour vient-il d'être atteint ? Déclenche le « claquement » de l'anneau.
    @State private var reached = false

    private var isReached: Bool { goal > 0 && consumed >= goal }

    var body: some View {
        let remaining = max(0, goal - consumed)
        LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(remaining)").font(.lumeNumberXL).foregroundStyle(LumeColor.ink)
                            .monospacedDigit().contentTransition(.numericText(value: Double(remaining)))
                        Text("/ \(goal)").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                    }
                    .animation(LumeMotion.snappy, value: remaining)
                    // À l'atteinte, on bascule le sous-titre : l'objectif est rempli, pas « 0 restantes ».
                    Text(isReached ? "Objectif atteint 🎉" : "Calories restantes")
                        .font(.lumeSubhead).foregroundStyle(isReached ? LumeColor.success : LumeColor.muted)
                }
                Spacer()
                ProgressRing(progress: Double(consumed) / Double(max(goal, 1)),
                             color: isReached ? LumeColor.success : LumeColor.ink, lineWidth: 9)
                {
                    Image(appIcon: isReached ? .validate : .calories)
                        .lumeIcon(24, weight: .semibold)
                        .foregroundStyle(isReached ? LumeColor.success : LumeColor.ink)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 86, height: 86)
                // « Claquement » de l'anneau central au franchissement de la cible.
                .scaleEffect(reached ? 1.12 : 1)
                .lumeGlow(LumeColor.success, active: reached)
            }
        }
        .onChange(of: isReached) { _, nowReached in
            guard nowReached, !reduceMotion else { return }
            withAnimation(LumeMotion.celebrate) { reached = true }
            withAnimation(LumeMotion.smooth.delay(0.5)) { reached = false }
        }
        .sensoryFeedback(.success, trigger: isReached) { old, new in !old && new }
    }
}
