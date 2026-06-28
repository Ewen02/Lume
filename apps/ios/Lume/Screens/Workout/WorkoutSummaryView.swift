import SwiftUI

/// Écran de récap gratifiant après une séance (durée, volume, séries, meilleur 1RM).
struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    var newBadges: [Badge] = []
    var newPRs: [PRBeaten] = []
    var onClose: () -> Void
    @AppStorage(WeightFormat.defaultsKey) private var useImperial = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    /// Révélation différée du record : il a SON instant à lui, juste après la médaille, avant les stats.
    @State private var prRevealed = false

    private var hasPR: Bool { !newPRs.isEmpty }

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

            // Le record est mis en scène EN PREMIER (avant les stats) : c'est la dopamine n°1 en muscu.
            if hasPR { prsCard }

            HStack(spacing: Spacing.md) {
                StatTile(icon: .restTimer, tint: LumeColor.fat, value: summary.durationLabel, label: "Durée")
                StatTile(icon: .workout, tint: LumeColor.protein,
                         value: "\(summary.setCount)", label: "Séries")
            }
            HStack(spacing: Spacing.md) {
                StatTile(icon: .oneRepMax, tint: LumeColor.carbs,
                         value: WeightFormat.load(summary.totalVolume, imperial: useImperial), label: "Volume total")
                StatTile(icon: .pr, tint: LumeColor.success,
                         value: summary.bestOneRM > 0 ? WeightFormat.load(summary.bestOneRM, imperial: useImperial) : "—",
                         label: "Meilleur 1RM")
            }

            if let ex = summary.bestExercise, summary.bestOneRM > 0, newPRs.isEmpty {
                Text("Top exercice : \(ex)").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }

            if !newBadges.isEmpty { badgesCard }

            Spacer()
            PrimaryButton(title: "Terminer", icon: .validate) { onClose() }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xl)
        .background(LumeColor.cream.ignoresSafeArea())
        .interactiveDismissDisabled()
        .onAppear {
            withAnimation(reduceMotion ? nil : LumeMotion.celebrate.delay(0.1)) { appeared = true }
            // Le record entre en scène juste après la médaille, pour ne pas se noyer dans les stats.
            if hasPR { withAnimation(reduceMotion ? nil : LumeMotion.celebrate.delay(0.45)) { prRevealed = true } }
        }
        .sensoryFeedback(.success, trigger: appeared)
        // Haptique dédiée au record (distincte du succès de fin de séance), au moment de sa révélation.
        .sensoryFeedback(.increase, trigger: prRevealed)
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
                    Text(WeightFormat.load(pr.oneRM, imperial: useImperial)).font(.lumeSubhead.weight(.bold)).foregroundStyle(LumeColor.ink).monospacedDigit()
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
        // Entrée différée et appuyée (scale + halo doré) : le record « claque » à son propre instant.
        .scaleEffect(prRevealed ? 1 : 0.7)
        .opacity(prRevealed ? 1 : 0)
        .lumeGlow(LumeColor.warning, active: prRevealed, intensity: 0.35)
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
