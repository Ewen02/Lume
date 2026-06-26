import SwiftData
import SwiftUI

/// Édition rapide du profil budget (revenu / loyer / charges / épargne) sans refaire l'onboarding.
/// Recalcule le budget de dépenses variables et la récurrente salaire à l'enregistrement.
/// Synthèse vivante du « reste à vivre » en haut (count-up + ligne par poste).
struct FinanceProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @AppStorage(FinanceSettings.globalBudgetKey) private var globalBudgetCents = 0
    @Query private var profiles: [FinanceProfile]
    @Query private var recurrings: [RecurringTransaction]
    @Query private var savedCharges: [FixedCharge]

    @State private var income = 0
    @State private var rent = 0
    @State private var charges = 0
    @State private var saving = 0
    @State private var loaded = false

    private var reste: Int {
        BudgetPlanner.resteAVivre(monthlyIncomeCents: income, fixedMonthlyCents: rent + charges + saving)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Synthèse : le reste à vivre se recalcule en direct à chaque modification.
                LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
                    VStack(spacing: Spacing.sm) {
                        Text("Reste à vivre / mois").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                        CountUpAmount(targetCents: max(0, reste), font: .lumeNumberXL,
                                      tint: reste >= 0 ? LumeColor.ink : LumeColor.negative)
                        if reste < 0 {
                            Text("Tes engagements dépassent tes revenus de \(Money.format(-reste)).")
                                .font(.lumeFootnote).foregroundStyle(LumeColor.negative)
                                .multilineTextAlignment(.center)
                        }
                    }.frame(maxWidth: .infinity)
                }

                field("Revenu net / mois", icon: .salary, tint: LumeColor.success, cents: $income)
                field("Loyer", icon: .housing, tint: LumeColor.ink, cents: $rent)
                field("Charges fixes", icon: .subscription, tint: LumeColor.fat, cents: $charges)
                field("Épargne", icon: .savings, tint: LumeColor.fat, cents: $saving)

                PrimaryButton(title: "Enregistrer", icon: .validate) { save() }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
            .animation(LumeMotion.smooth, value: reste)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Mon budget", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .onAppear {
            guard !loaded, let p = profiles.first else { loaded = true; return }
            income = p.monthlyNetIncomeCents; rent = p.rentCents
            charges = p.fixedChargesCents; saving = p.monthlySavingCents
            loaded = true
        }
    }

    private func field(_ label: String, icon: AppIcon, tint: Color, cents: Binding<Int>) -> some View {
        let text = Binding<String>(
            get: { cents.wrappedValue == 0 ? "" : Money.plainDecimal(cents.wrappedValue) },
            set: { cents.wrappedValue = Money.parse($0) ?? 0 }
        )
        return LumeCard {
            HStack(spacing: Spacing.md) {
                Image(appIcon: icon).lumeIcon(16, weight: .semibold).foregroundStyle(tint)
                    .frame(width: 38, height: 38).background(tint.opacity(0.14), in: Circle())
                Text(label).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                Spacer()
                TextField("0", text: text)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .font(.lumeCallout.weight(.semibold)).foregroundStyle(LumeColor.ink).monospacedDigit().frame(width: 90)
                Text("€").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }
        }
    }

    private func save() {
        let profile = profiles.first ?? {
            let p = FinanceProfile(); ctx.insert(p); return p
        }()
        // Si le total des charges change ici (édition rapide, sans le détail), le détail conservé
        // deviendrait incohérent : on le consolide en une ligne unique reflétant le nouveau total.
        if charges != profile.fixedChargesCents {
            for c in savedCharges {
                ctx.delete(c)
            }
            if charges > 0 {
                ctx.insert(FixedCharge(label: "Charges", amountCents: charges, category: .subscriptions))
            }
        }

        profile.monthlyNetIncomeCents = income
        profile.rentCents = rent
        profile.fixedChargesCents = charges
        profile.monthlySavingCents = saving

        // Récurrente salaire : upsert (purge l'ancienne avant de recréer, pas de doublon).
        for r in recurrings where r.kind == .income && r.category == .salary {
            ctx.delete(r)
        }
        if income > 0 {
            ctx.insert(RecurringTransaction(label: "Salaire", amountCents: income, kind: .income,
                                            category: .salary, frequency: .monthly, dayOfMonth: 1))
        }
        globalBudgetCents = profile.variableBudgetCents
        dismiss()
    }
}

#Preview {
    FinanceProfileView().modelContainer(LumeStore.preview)
}
