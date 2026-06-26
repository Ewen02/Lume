import SwiftUI

/// Feuille de célébration « mois bouclé sous budget » : affichée une fois par mois (via
/// `CelebrationLedger`) quand le mois précédent s'est terminé sous le budget de dépenses variables.
struct MonthRecapSheet: View {
    @Environment(\.dismiss) private var dismiss
    let monthLabel: String
    let spentCents: Int
    let budgetCents: Int

    private var savedCents: Int {
        max(0, budgetCents - spentCents)
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(appIcon: .pr).lumeIcon(48, weight: .bold).foregroundStyle(LumeColor.success)
            Text("Mois bouclé sous budget 🎉").font(.lumeTitle).foregroundStyle(LumeColor.ink)
                .multilineTextAlignment(.center)
            Text("En \(monthLabel), tu es resté·e dans ton budget.")
                .font(.lumeSubhead).foregroundStyle(LumeColor.muted).multilineTextAlignment(.center)

            LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
                VStack(spacing: Spacing.sm) {
                    Text("Économisé vs budget").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                    CountUpAmount(targetCents: savedCents, font: .lumeNumberXL, tint: LumeColor.success)
                    Text("\(Money.format(spentCents)) dépensés sur \(Money.format(budgetCents))")
                        .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }.frame(maxWidth: .infinity)
            }.padding(.horizontal, Spacing.xl)

            Spacer()
            PrimaryButton(title: "Continuer", icon: .validate) { dismiss() }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .background(LumeColor.cream.ignoresSafeArea())
        .presentationDetents([.medium])
        .sensoryFeedback(.success, trigger: monthLabel)
    }
}

#Preview {
    MonthRecapSheet(monthLabel: "mai 2026", spentCents: 124_000, budgetCents: 160_000)
}
