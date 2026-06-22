import SwiftUI

/// Feuille détaillant la série (streak) : grande flamme animée, explication, record.
struct StreakDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let streak: Int
    let record: Int

    @State private var burst = false

    private var subtitle: String {
        switch streak {
        case 0: "Logue un repas aujourd'hui pour démarrer ta série."
        case 1: "Premier jour ! Reviens demain pour l'entretenir."
        case 2 ..< 7: "Belle régularité, continue comme ça."
        case 7 ..< 30: "Une semaine et plus — tu tiens le rythme !"
        default: "En feu 🔥 Une série impressionnante."
        }
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Grande flamme, qui « jaillit » à l'ouverture.
            StreakFlame(streak: streak, size: 88)
                .scaleEffect(burst ? 1 : 0.5)
                .frame(height: 130)
                .padding(.top, Spacing.xxl)

            VStack(spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(streak)").font(.lumeNumberXL).foregroundStyle(LumeColor.ink).monospacedDigit()
                    Text(streak > 1 ? "jours" : "jour").font(.lumeTitle).foregroundStyle(LumeColor.muted)
                }
                Text("Série en cours").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
            }

            Text(subtitle).font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, Spacing.lg)

            // Explication + record.
            VStack(spacing: Spacing.md) {
                infoRow(icon: .streak, tint: LumeColor.protein,
                        title: "Comment ça marche",
                        value: "Chaque jour avec au moins un repas logué prolonge ta série.")
                Divider().background(LumeColor.border)
                infoRow(icon: .pr, tint: LumeColor.warning,
                        title: "Ton record",
                        value: "\(record) jour\(record > 1 ? "s" : "") consécutif\(record > 1 ? "s" : "")")
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

#Preview { StreakDetailView(streak: 12, record: 21) }
