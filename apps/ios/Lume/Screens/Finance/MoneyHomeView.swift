import SwiftData
import SwiftUI

/// Écran principal du module Argent : KPIs du mois, anneau budget global, budgets par catégorie,
/// graphe mensuel, transactions récentes. Borne sa requête au mois courant (cf. TodayView/7 j).
struct MoneyHomeView: View {
    @Environment(\.modelContext) private var ctx
    @AppStorage(FinanceSettings.setupDoneKey) private var setupDone = false
    @AppStorage(FinanceSettings.globalBudgetKey) private var globalBudgetCents = 0

    // Toutes les transactions (volume mensuel faible) ; on filtre par mois sélectionné en mémoire,
    // ce qui permet de naviguer entre les mois passés sans re-paramétrer un @Query.
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var allTx: [FinanceTransaction]
    @Query private var budgets: [CategoryBudget]
    @Query private var recurrings: [RecurringTransaction]
    @Query private var profiles: [FinanceProfile]

    /// Change quand l'utilisateur vient de logger une dépense → pulse de l'anneau + haptique.
    var highlightTrigger: UUID = .init()

    @State private var route: Route?
    @State private var ringPulse = false
    @State private var monthRecap: MonthRecapData?
    @State private var selectedMonth = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// Données de la célébration « mois bouclé sous budget » (mois précédent).
    private struct MonthRecapData: Identifiable {
        let id = UUID()
        let label: String
        let spent: Int
        let budget: Int
    }

    private enum Route: Identifiable {
        case add, history, recurring, budgets, profile
        case edit(FinanceTransaction)
        var id: String {
            switch self {
            case .add: "add"; case .history: "history"; case .recurring: "recurring"
            case .budgets: "budgets"; case .profile: "profile"
            case let .edit(t): "edit-\(t.id)"
            }
        }
    }

    init(highlightTrigger: UUID = .init()) {
        self.highlightTrigger = highlightTrigger
    }

    var body: some View {
        home
            // Onboarding présenté en PLEIN ÉCRAN (couvre la tab bar) → parcours immersif, pas un
            // écran « parmi les onglets ». `setupDone` est la seule source de vérité, donc
            // « Reconfigurer mon budget » (qui le repasse à false) relance le cover.
            .fullScreenCover(isPresented: Binding(get: { !setupDone }, set: { setupDone = !$0 })) {
                FinanceSetupView()
            }
            // Matérialise les récurrentes dues à l'ouverture (idempotent).
            .task(id: recurrings.count) { RecurrenceEngine.materializeDue(in: ctx) }
            // Dépense loggée : on revient d'abord au mois courant (la transaction est datée aujourd'hui ;
            // sinon on pulserait un mois passé où elle n'apparaît pas), puis pulse bref de l'anneau.
            .onChange(of: highlightTrigger) { _, _ in
                if !isCurrentMonth {
                    withAnimation(reduceMotion ? nil : LumeMotion.snappy) { selectedMonth = Date() }
                }
                guard !reduceMotion else { return }
                withAnimation(LumeMotion.celebrate) { ringPulse = true }
                withAnimation(LumeMotion.smooth.delay(0.45)) { ringPulse = false }
            }
            // Haptique : succès si on reste sous le budget, alerte si dépassé.
            .sensoryFeedback(trigger: highlightTrigger) { _, _ in
                BudgetStatus.of(spent: spent, budget: globalBudgetCents) == .over ? .warning : .success
            }
            // Célébration « mois bouclé sous budget » (1×/mois) : à l'ouverture ET au retour au
            // premier plan (couvre le passage de minuit / changement de mois app restée ouverte).
            .task(id: setupDone) { evaluateMonthRecap() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { evaluateMonthRecap() } }
            .sheet(item: $monthRecap) { r in
                MonthRecapSheet(monthLabel: r.label, spentCents: r.spent, budgetCents: r.budget)
            }
    }

    /// Si le mois PRÉCÉDENT s'est terminé sous le budget et qu'on ne l'a pas déjà fêté ce mois,
    /// prépare la feuille de célébration (puis marque le ledger pour ne pas la rejouer).
    private func evaluateMonthRecap() {
        // Enregistre le budget courant pour le mois en cours (référence historique des mois passés).
        if globalBudgetCents > 0 { FinanceSettings.recordBudget(globalBudgetCents, forMonth: Date()) }

        let id = "monthClosed"
        guard globalBudgetCents > 0, setupDone, CelebrationLedger.shouldCelebrate(id) else { return }
        let cal = Calendar.current
        guard let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) else { return }
        // Budget du mois passé (historique) si connu, sinon le courant.
        let lastBudget = FinanceSettings.budget(forMonth: lastMonth) ?? globalBudgetCents
        let lastSpent = FinanceCalculator.totalSpent(allTx.map(\.data), in: lastMonth)
        // Mois précédent réellement écoulé avec des dépenses et resté sous SON budget.
        guard lastSpent > 0, lastSpent < lastBudget else { return }
        monthRecap = MonthRecapData(label: Formatters.monthYearFR(lastMonth),
                                    spent: lastSpent, budget: lastBudget)
        CelebrationLedger.markCelebrated(id)
    }

    // MARK: Données dérivées (mois SÉLECTIONNÉ, via FinanceCalculator)

    /// Le mois affiché est-il le mois courant ? (les célébrations/pulse ne valent que pour lui).
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    /// Transactions du mois sélectionné (filtre en mémoire sur `allTx`, déjà trié décroissant).
    private var monthTx: [FinanceTransaction] {
        let (start, end) = FinanceCalculator.monthBounds(of: selectedMonth)
        return allTx.filter { $0.date >= start && $0.date < end }
    }

    private var data: [TransactionData] {
        monthTx.map(\.data)
    }

    private var spent: Int {
        FinanceCalculator.totalSpent(data, in: selectedMonth)
    }

    private var income: Int {
        FinanceCalculator.totalIncome(data, in: selectedMonth)
    }

    /// Engagements fixes du profil (loyer + charges + épargne), déduits du solde réel.
    /// Ne s'applique qu'au mois courant : un mois passé n'a pas de profil historique fiable.
    private var committedOutflow: Int {
        guard isCurrentMonth, let p = profiles.first else { return 0 }
        return FinanceCalculator.committedOutflow(rentCents: p.rentCents,
                                                  fixedChargesCents: p.fixedChargesCents,
                                                  savingCents: p.monthlySavingCents)
    }

    /// Solde RÉEL « à vivre » : revenus − dépenses variables − engagements fixes (loyer/charges/épargne).
    /// C'est le chiffre honnête, cohérent avec l'anneau (qui travaille déjà net des fixes).
    private var balance: Int {
        FinanceCalculator.realBalance(data, in: selectedMonth, committed: committedOutflow)
    }

    private var byCategory: [ExpenseCategory: Int] {
        FinanceCalculator.spentByCategory(data, in: selectedMonth)
    }

    private var series: [ChartPoint] {
        FinanceCalculator.monthlySeries(allTx.map(\.data), months: 6, reference: selectedMonth)
    }

    private var savedThisMonth: Int {
        FinanceCalculator.totalSaved(data, in: selectedMonth)
    }

    private var savedTotal: Int {
        FinanceCalculator.cumulativeSaved(allTx.map(\.data))
    }

    private var budgetStatusColor: Color {
        switch BudgetStatus.of(spent: spent, budget: displayedBudgetCents) {
        case .under: LumeColor.success
        case .near: LumeColor.warning
        case .over: LumeColor.negative
        }
    }

    /// Alerte contextuelle sous l'anneau (B1 + B5), par ordre de gravité.
    private enum BudgetAlert { case overCommitted(Int), over(Int), near(Int) }
    private var budgetAlert: BudgetAlert? {
        // B1 : engagements fixes > revenus (budget intenable structurellement).
        if let p = profiles.first, p.isOverCommitted { return .overCommitted(p.overCommitCents) }
        guard hasBudget else { return nil }
        // B5 : dépassement / quasi-dépassement du budget de dépenses variables (du mois affiché).
        switch BudgetStatus.of(spent: spent, budget: displayedBudgetCents) {
        case .over: return .over(spent - displayedBudgetCents)
        case .near: return .near(max(0, displayedBudgetCents - spent))
        case .under: return nil
        }
    }

    @ViewBuilder private func alertBanner(_ alert: BudgetAlert) -> some View {
        let (icon, tint, text): (AppIcon, Color, String) = {
            switch alert {
            case let .overCommitted(c):
                (.warning, LumeColor.negative, "Tes charges fixes dépassent tes revenus de \(Money.format(c)). Ajuste un poste.")
            case let .over(c):
                (.warning, LumeColor.negative, "Budget dépassé de \(Money.format(c)) ce mois-ci.")
            case let .near(c):
                (.warning, LumeColor.warning, "Plus que \(Money.format(c)) avant d'atteindre ton budget.")
            }
        }()
        // Charges > revenus → on envoie vers « Mon budget » (ajuster un poste/revenu) ; dépassement de
        // budget variable → vers les plafonds par catégorie (là où on agit sur les dépenses).
        let destination: Route = { if case .overCommitted = alert { return .profile } else { return .budgets } }()
        return Button { route = destination } label: {
            LumeCard {
                HStack(spacing: Spacing.md) {
                    Image(appIcon: icon).lumeIcon(18, weight: .semibold).foregroundStyle(tint)
                    Text(text).font(.lumeFootnote).foregroundStyle(LumeColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(appIcon: .forward).lumeIcon(12, weight: .semibold).foregroundStyle(LumeColor.muted)
                }
            }
        }.buttonStyle(.lumePress)
    }

    private var home: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                budgetCard.lumeEntrance(0)
                if let alert = budgetAlert { alertBanner(alert).lumeEntrance(1) }
                statsRow.lumeEntrance(1)
                if savedTotal > 0 { savingsCard.lumeEntrance(2) }
                if !activeBudgets.isEmpty { budgetsSection.lumeEntrance(3) }
                if series.contains(where: { $0.value > 0 }) { chartSection.lumeEntrance(4) }
                recentSection.lumeEntrance(5)
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, 130)
        }
        .background(LumeColor.cream)
        .safeAreaInset(edge: .top) { header }
        .sheet(item: $route) { dest in
            switch dest {
            case .add: TransactionEditorView()
            case .history: TransactionListView(month: selectedMonth)
            case .recurring: RecurringListView()
            case .budgets: BudgetsEditorView { route = .profile }
            case .profile: FinanceProfileView()
            case let .edit(t): TransactionEditorView(entry: t)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Budget").font(.lumeDisplay).foregroundStyle(LumeColor.ink)
            Spacer()
            Button { route = .profile } label: {
                Image(appIcon: .salary).lumeIcon(20, weight: .semibold).foregroundStyle(LumeColor.ink)
            }.buttonStyle(.lumePress).accessibilityLabel("Mon budget")
            Button { route = .recurring } label: {
                Image(appIcon: .recurring).lumeIcon(20, weight: .semibold).foregroundStyle(LumeColor.ink)
            }.buttonStyle(.lumePress).accessibilityLabel("Récurrentes")
            Button { route = .budgets } label: {
                Image(appIcon: .settings).lumeIcon(20, weight: .semibold).foregroundStyle(LumeColor.ink)
            }.buttonStyle(.lumePress).accessibilityLabel("Budgets")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
    }

    /// Budget appliqué au MOIS AFFICHÉ : l'historique pour un mois passé (budget de l'époque),
    /// sinon le budget courant. Évite d'afficher un mois passé avec le budget d'aujourd'hui.
    private var displayedBudgetCents: Int {
        if isCurrentMonth { return globalBudgetCents }
        return FinanceSettings.budget(forMonth: selectedMonth) ?? globalBudgetCents
    }

    /// Un budget est-il défini pour le mois affiché ?
    private var hasBudget: Bool {
        displayedBudgetCents > 0
    }

    private var budgetCard: some View {
        LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
            VStack(spacing: Spacing.md) {
                MonthStepper(month: $selectedMonth)
                ProgressRing(progress: hasBudget ? FinanceCalculator.progress(spent: spent, budget: displayedBudgetCents) : 0,
                             color: hasBudget ? budgetStatusColor : LumeColor.faint, lineWidth: 12)
                {
                    VStack(spacing: 2) {
                        // Le montant central « monte » à l'apparition et se ré-anime à chaque dépense du
                        // mois courant. En navigation vers un mois passé, on saute la valeur (pas de
                        // count-up « slot-machine » sans rapport avec une vraie variation).
                        CountUpAmount(targetCents: hasBudget ? max(0, displayedBudgetCents - spent) : spent,
                                      animatesOnChange: isCurrentMonth)
                        Text(hasBudget ? "Reste" : "dépensé")
                            .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                    }
                    .padding(.horizontal, Spacing.sm)
                }
                .frame(width: 130, height: 130)
                .scaleEffect(ringPulse ? 1.04 : 1)

                if hasBudget, spent == 0, isCurrentMonth {
                    // Premier jour du mois / aucune dépense : message positif, pas un « 0 % » anxiogène.
                    Text("Tout ton budget t'attend ce mois-ci.")
                        .font(.lumeFootnote).foregroundStyle(LumeColor.success)
                } else if hasBudget {
                    Text("\(Money.format(spent)) sur \(Money.format(displayedBudgetCents)) · \(Int(FinanceCalculator.progress(spent: spent, budget: displayedBudgetCents) * 100)) %")
                        .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                } else {
                    // Le budget global est DÉRIVÉ du profil (revenu − fixes − épargne) : on envoie donc
                    // vers « Mon budget » (revenu), pas vers les plafonds par catégorie.
                    Button { route = .profile } label: {
                        Text("Définir mon budget").font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.success)
                    }.buttonStyle(.lumePress)
                }
            }.frame(maxWidth: .infinity)
        }
    }

    /// Objectif d'épargne mensuel (depuis le profil) atteint ce mois ?
    private var savingGoal: Int {
        profiles.first?.monthlySavingCents ?? 0
    }

    private var savingGoalReached: Bool {
        savingGoal > 0 && savedThisMonth >= savingGoal
    }

    /// Épargne : mise de côté du mois + capital cumulé (n'apparaît qu'une fois qu'on a épargné).
    private var savingsCard: some View {
        LumeCard {
            HStack(spacing: Spacing.md) {
                Image(appIcon: .savings).lumeIcon(18, weight: .semibold)
                    .foregroundStyle(savingGoalReached ? LumeColor.success : LumeColor.fat)
                    .frame(width: 40, height: 40)
                    .background((savingGoalReached ? LumeColor.success : LumeColor.fat).opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text("Épargne").font(.lumeCallout).foregroundStyle(LumeColor.ink)
                        if savingGoalReached {
                            Text("Objectif atteint").font(.lumeCaption.weight(.bold)).foregroundStyle(LumeColor.success)
                                .padding(.horizontal, Spacing.sm).padding(.vertical, 2)
                                .background(LumeColor.success.opacity(0.14), in: Capsule())
                        }
                    }
                    Text("\(Money.format(savedThisMonth)) ce mois").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.format(savedTotal)).font(.lumeHeadline).foregroundStyle(LumeColor.ink).monospacedDigit()
                    Text("cumulé").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }
            }
        }
        .scaleEffect(savingGoalReached && ringPulse ? 1.02 : 1)
    }

    /// 2 tuiles larges (au lieu de 3 étroites) → les montants en euros ne wrappent plus.
    /// Les valeurs « roulent » (numericText) quand une dépense est ajoutée.
    private var statsRow: some View {
        HStack(spacing: Spacing.md) {
            StatTile(icon: .expenseArrow, tint: LumeColor.ink, value: Money.format(spent), label: "Dépensé")
            StatTile(icon: .money, tint: balance >= 0 ? LumeColor.success : LumeColor.negative,
                     value: Money.format(balance, showSign: true), label: "Solde")
        }
        .animation(reduceMotion ? nil : LumeMotion.smooth, value: spent)
    }

    /// Catégories ayant un budget défini (> 0), triées par dépense décroissante.
    private var activeBudgets: [(category: ExpenseCategory, spent: Int, limit: Int)] {
        budgets.filter { $0.monthlyLimitCents > 0 }
            .map { (category: $0.category, spent: byCategory[$0.category] ?? 0, limit: $0.monthlyLimitCents) }
            .sorted { $0.spent > $1.spent }
    }

    private var budgetsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Budgets par catégorie", actionTitle: "Gérer") { route = .budgets }
            LumeCard {
                VStack(spacing: Spacing.md) {
                    ForEach(activeBudgets, id: \.category) { b in
                        GoalBar(label: b.category.title,
                                value: "\(Money.format(b.spent)) / \(Money.format(b.limit))",
                                progress: FinanceCalculator.progress(spent: b.spent, budget: b.limit),
                                tint: tint(for: b.spent, b.limit, b.category),
                                // Coche verte calme sur les enveloppes qui tiennent (sous 85 %).
                                trailingAccessory: BudgetStatus.of(spent: b.spent, budget: b.limit) == .under ? .validate : nil)
                    }
                }
            }
        }
    }

    private func tint(for spent: Int, _ limit: Int, _ cat: ExpenseCategory) -> Color {
        switch BudgetStatus.of(spent: spent, budget: limit) {
        case .under: cat.tint
        case .near: LumeColor.warning
        case .over: LumeColor.negative
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Dépenses par mois")
            LumeCard {
                InteractiveBarChart(points: series, tint: LumeColor.ink,
                                    format: { Money.format($0) })
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Transactions récentes", actionTitle: "Tout voir") { route = .history }
            if monthTx.isEmpty {
                // Mois courant : on invite à ajouter ; mois passé : simple état vide neutre.
                if isCurrentMonth {
                    LumeEmptyState(icon: .money, title: "Aucune dépense pour l'instant",
                                   message: "Tu es pile dans ton budget. Note ta première dépense quand elle arrive.",
                                   actionTitle: "Ajouter une dépense") { route = .add }
                } else {
                    LumeEmptyState(icon: .money, title: "Aucune dépense ce mois-ci",
                                   message: "Rien n'a été enregistré pour ce mois.")
                }
            } else {
                ForEach(monthTx.prefix(6)) { t in
                    TransactionRow(category: t.category, title: t.note, detail: Formatters.relative(t.date),
                                   amountCents: t.amountCents, kind: t.kind,
                                   isRecurring: t.recurringID != nil) { route = .edit(t) }
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                removal: .opacity))
                }
            }
        }
        // Une nouvelle dépense glisse en haut de la liste ; suppression en fondu.
        .animation(reduceMotion ? nil : LumeMotion.snappy, value: monthTx.count)
    }
}

#Preview {
    MoneyHomeView().modelContainer(LumeStore.preview)
}
