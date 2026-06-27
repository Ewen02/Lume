import SwiftData
import SwiftUI

/// Édition des PLAFONDS PAR CATÉGORIE. Le budget global n'est PAS éditable ici : c'est une valeur
/// dérivée (revenu − loyer − charges − épargne) gérée dans « Mon budget » (source unique de vérité).
struct BudgetsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @AppStorage(FinanceSettings.globalBudgetKey) private var globalBudgetCents = 0
    @AppStorage(FinanceSettings.setupDoneKey) private var setupDone = false
    @Query private var budgets: [CategoryBudget]

    /// Ouvre la sheet « Mon budget » (édition revenu/loyer/charges/épargne).
    var onEditProfile: () -> Void = {}

    /// État local des plafonds par catégorie (centimes), édité puis persisté à l'enregistrement.
    @State private var limits: [ExpenseCategory: Int] = [:]
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Budget global : lecture seule, dérivé du profil. On renvoie vers « Mon budget ».
                Button { onEditProfile() } label: {
                    LumeCard {
                        HStack(spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Budget mensuel").font(.lumeCallout).foregroundStyle(LumeColor.ink)
                                Text("Calculé depuis tes revenus et tes dépenses fixes")
                                    .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                            }
                            Spacer()
                            Text(Money.format(globalBudgetCents)).font(.lumeHeadline).foregroundStyle(LumeColor.ink).monospacedDigit()
                            Image(appIcon: .forward).lumeIcon(12, weight: .semibold).foregroundStyle(LumeColor.muted)
                        }
                    }
                }.buttonStyle(.lumePress)
                SectionHeader(title: "Plafonds par catégorie (facultatif)")
                ForEach(ExpenseCategory.categoryBudgetCases) { cat in
                    LumeCard {
                        HStack(spacing: Spacing.md) {
                            Image(appIcon: cat.icon).lumeIcon(16, weight: .semibold).foregroundStyle(cat.tint)
                                .frame(width: 38, height: 38).background(cat.tint.opacity(0.14), in: Circle())
                            Text(cat.title).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                            Spacer()
                            categoryField(cat)
                        }
                    }
                }
                PrimaryButton(title: "Enregistrer", icon: .validate) { save() }
                SecondaryButton(title: "Reconfigurer mon budget", icon: .recurring) {
                    // Relance le parcours d'onboarding (revenus → fixes → reste à vivre).
                    setupDone = false
                    dismiss()
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Budgets", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .onAppear {
            guard !loaded else { return }
            for b in budgets where b.monthlyLimitCents > 0 {
                limits[b.category] = b.monthlyLimitCents
            }
            loaded = true
        }
    }

    private func categoryField(_ cat: ExpenseCategory) -> some View {
        let binding = Binding<String>(
            get: { (limits[cat] ?? 0) == 0 ? "" : Money.plainDecimal(limits[cat] ?? 0) },
            set: { limits[cat] = Money.parse($0) ?? 0 }
        )
        return HStack(spacing: 2) {
            TextField("—", text: binding)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).monospacedDigit()
                .frame(width: 70)
            Text("€").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
        }
    }

    private func save() {
        // Le budget global n'est PAS touché ici (dérivé du profil). On ne gère que les plafonds.
        // Met à jour / crée les CategoryBudget. Un plafond à 0 vide le budget existant.
        var existing: [ExpenseCategory: CategoryBudget] = [:]
        for b in budgets {
            existing[b.category] = b
        }
        for cat in ExpenseCategory.categoryBudgetCases {
            let limit = limits[cat] ?? 0
            if let b = existing[cat] {
                b.monthlyLimitCents = limit
            } else if limit > 0 {
                ctx.insert(CategoryBudget(category: cat, monthlyLimitCents: limit))
            }
        }
        // Purge un éventuel plafond « Logement » orphelin (créé avant l'exclusion du loyer des plafonds) :
        // le loyer ne se gère QUE dans « Mon budget » → on supprime tout doublon pour éviter la désynchro.
        if let stray = existing[.housing] { ctx.delete(stray) }
        dismiss()
    }
}

#Preview {
    BudgetsEditorView().modelContainer(LumeStore.preview)
}
