import SwiftUI

/// Écran de récap gratifiant après une séance (durée, volume, séries, meilleur 1RM).
struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    var newBadges: [Badge] = []
    var newPRs: [PRBeaten] = []
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

            if let ex = summary.bestExercise, summary.bestOneRM > 0, newPRs.isEmpty {
                Text("Top exercice : \(ex)").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }

            if !newPRs.isEmpty { prsCard }
            if !newBadges.isEmpty { badgesCard }

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

    private var prsCard: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(appIcon: .pr).lumeIcon(16, weight: .bold).foregroundStyle(LumeColor.warning)
                Text(newPRs.count > 1 ? "Nouveaux records !" : "Nouveau record !")
                    .font(.lumeCallout.weight(.bold)).foregroundStyle(LumeColor.ink)
            }
            ForEach(newPRs) { pr in
                HStack {
                    Text(pr.exercise).font(.lumeSubhead).foregroundStyle(LumeColor.ink).lineLimit(1)
                    Spacer()
                    Text("\(pr.oneRM) kg").font(.lumeSubhead.weight(.bold)).foregroundStyle(LumeColor.ink).monospacedDigit()
                    if pr.previous > 0 {
                        Text("+\(pr.oneRM - pr.previous)").font(.lumeCaption.weight(.semibold))
                            .foregroundStyle(LumeColor.success).monospacedDigit()
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(LumeColor.warning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(LumeColor.warning.opacity(0.3), lineWidth: 1))
        .scaleEffect(appeared ? 1 : 0.8)
    }

    private var badgesCard: some View {
        VStack(spacing: Spacing.sm) {
            Text(newBadges.count > 1 ? "Nouveaux badges débloqués !" : "Nouveau badge débloqué !")
                .font(.lumeCallout.weight(.semibold)).foregroundStyle(LumeColor.ink)
            HStack(spacing: Spacing.md) {
                ForEach(newBadges) { badge in
                    VStack(spacing: Spacing.xs) {
                        Image(appIcon: badge.icon).lumeIcon(22, weight: .bold).foregroundStyle(badge.tint)
                            .frame(width: 56, height: 56).background(badge.tint.opacity(0.14), in: Circle())
                        Text(badge.title).font(.lumeCaption).foregroundStyle(LumeColor.muted)
                            .multilineTextAlignment(.center).lineLimit(2)
                    }.frame(maxWidth: 90)
                }
            }
        }
        .padding(Spacing.lg)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .lumeShadow(.soft)
        .scaleEffect(appeared ? 1 : 0.8)
    }
}

#Preview {
    WorkoutSummaryView(
        summary: WorkoutSummary(
            from: [ExerciseSession(exercise: Exercise(name: "Développé couché", primary: .chest, equipment: "Barre"),
                                   sets: [SetEntry(reps: 8, weight: 80, rpe: nil), SetEntry(reps: 6, weight: 85, rpe: nil)])],
            durationSec: 2535
        )
    ) {}
}
