import SwiftUI

/// Écran de récap gratifiant après une séance (durée, volume, séries, meilleur 1RM).
struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    var onClose: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            // Médaille animée à l'apparition.
            Image(appIcon: .pr)
                .lumeIcon(56, weight: .bold).foregroundStyle(LumeColor.warning)
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -25))

            VStack(spacing: Spacing.xs) {
                Text("Séance terminée").font(.lumeTitle).foregroundStyle(LumeColor.ink)
                Text("Beau boulot 💪").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
            }

            HStack(spacing: Spacing.md) {
                StatTile(icon: .restTimer, tint: LumeColor.fat, value: summary.durationLabel, label: "Durée")
                StatTile(icon: .workout, tint: LumeColor.protein,
                         value: "\(summary.setCount)", label: "Séries")
            }
            HStack(spacing: Spacing.md) {
                StatTile(icon: .oneRepMax, tint: LumeColor.carbs,
                         value: "\(summary.totalVolume) kg", label: "Volume total")
                StatTile(icon: .pr, tint: LumeColor.success,
                         value: summary.bestOneRM > 0 ? "\(summary.bestOneRM) kg" : "—",
                         label: "Meilleur 1RM")
            }

            if let ex = summary.bestExercise, summary.bestOneRM > 0 {
                Text("Top exercice : \(ex)").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }
            Spacer()
            PrimaryButton(title: "Terminer", icon: .validate) { onClose() }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xl)
        .background(LumeColor.cream.ignoresSafeArea())
        .interactiveDismissDisabled()
        .onAppear { withAnimation(LumeMotion.celebrate.delay(0.1)) { appeared = true } }
        .sensoryFeedback(.success, trigger: appeared)
    }
}

#Preview {
    WorkoutSummaryView(
        summary: WorkoutSummary(
            from: [ExerciseSession(exercise: Exercise(name: "Développé couché", primary: .chest, equipment: "Barre"),
                                   sets: [SetEntry(reps: 8, weight: 80, rpe: nil), SetEntry(reps: 6, weight: 85, rpe: nil)])],
            durationSec: 2535)
    ) {}
}
