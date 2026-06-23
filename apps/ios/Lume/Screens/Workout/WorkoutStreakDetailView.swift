import SwiftData
import SwiftUI

/// Feuille détaillant la série d'entraînement (streak HEBDOMADAIRE) : grande flamme, explication,
/// record, et réglage de l'objectif de séances/semaine.
struct WorkoutStreakDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var profiles: [ProfileRecord]
    let streak: Int
    let record: Int
    let goal: Int

    @State private var burst = false

    /// Objectif courant lu depuis le profil (fallback sur la valeur passée à l'ouverture).
    private var currentGoal: Int { profiles.first?.weeklyWorkoutGoal ?? goal }

    private func setGoal(_ value: Int) {
        let clamped = min(7, max(1, value))
        if let r = profiles.first {
            r.weeklyWorkoutGoal = clamped
        } else {
            let r = ProfileRecord(name: "")
            r.weeklyWorkoutGoal = clamped
            ctx.insert(r)
        }
    }

    private var subtitle: String {
        switch streak {
        case 0: "Atteins ton objectif de séances cette semaine pour démarrer ta série."
        case 1: "Première semaine bouclée ! Recommence la semaine prochaine."
        case 2 ..< 4: "Belle régularité, semaine après semaine."
        case 4 ..< 12: "Plus d'un mois de régularité — tu tiens le rythme !"
        default: "En feu 🔥 Une régularité impressionnante."
        }
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            StreakFlame(streak: streak, size: 88)
                .scaleEffect(burst ? 1 : 0.5)
                .frame(height: 130)
                .padding(.top, Spacing.xxl)

            VStack(spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(streak)").font(.lumeNumberXL).foregroundStyle(LumeColor.ink).monospacedDigit()
                    Text(streak > 1 ? "semaines" : "semaine").font(.lumeTitle).foregroundStyle(LumeColor.muted)
                }
                Text("Série d'entraînement").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
            }

            Text(subtitle).font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, Spacing.lg)

            VStack(spacing: Spacing.md) {
                infoRow(icon: .streak, tint: LumeColor.protein,
                        title: "Comment ça marche",
                        value: "Chaque semaine où tu atteins ton objectif de \(goal) séances prolonge ta série.")
                Divider().background(LumeColor.border)
                infoRow(icon: .pr, tint: LumeColor.warning,
                        title: "Ton record",
                        value: "\(record) semaine\(record > 1 ? "s" : "") consécutive\(record > 1 ? "s" : "")")
            }
            .padding(Spacing.lg)
            .background(LumeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .lumeShadow(.soft)

            // Réglage de l'objectif hebdomadaire.
            HStack {
                Text("Objectif hebdomadaire").font(.lumeCallout).foregroundStyle(LumeColor.ink)
                Spacer()
                Stepper("\(currentGoal) séance\(currentGoal > 1 ? "s" : "")", value: Binding(
                    get: { currentGoal },
                    set: { setGoal($0) }
                ), in: 1 ... 7)
                .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).fixedSize()
            }
            .padding(Spacing.lg)
            .background(LumeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .lumeShadow(.soft)

            Spacer(minLength: 0)
            SecondaryButton(title: "Continuer") { dismiss() }
                .padding(.bottom, Spacing.lg)
        }
        .padding(.horizontal, Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(LumeColor.cream.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.xxl + 6)
        .onAppear { withAnimation(LumeMotion.celebrate.delay(0.05)) { burst = true } }
        .sensoryFeedback(.success, trigger: burst)
    }

    private func infoRow(icon: AppIcon, tint: Color, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(appIcon: icon).lumeIcon(16, weight: .semibold).foregroundStyle(tint)
                .frame(width: 36, height: 36).background(tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.lumeCallout.weight(.semibold)).foregroundStyle(LumeColor.ink)
                Text(value).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }
            Spacer()
        }
    }
}

#Preview { WorkoutStreakDetailView(streak: 5, record: 8, goal: 3) }
