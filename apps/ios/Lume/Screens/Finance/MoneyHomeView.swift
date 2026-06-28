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
            // Purge les récurrentes incohérentes (revenu/épargne/loyer gérés par le profil) et les
            // doublons hérités, PUIS matérialise les récurrentes (dépenses fixes) dues. Idempotent.
            .task(id: recurrings.count) {
                RecurringCleaner.purge(in: ctx)
                RecurrenceEngine.materializeDue(in: ctx)
            }
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
        monthRecap = MonthRecapData(label: Formatters.monthYearLabel(lastMonth),
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

    /// Revenu du mois = revenu fixe du profil (mois courant) + revenus PONCTUELS saisis (prime, extra).
    /// Le revenu fixe n'est plus matérialisé en récurrente (modèle enveloppe) : on le lit du profil.
    private var income: Int {
        let punctual = FinanceCalculator.totalIncome(data, in: selectedMonth)
        let fixed = (isCurrentMonth ? profiles.first?.monthlyNetIncomeCents : nil) ?? 0
        return fixed + punctual
    }

    private var byCategory: [ExpenseCategory: Int] {
        FinanceCalculator.spentByCategory(data, in: selectedMonth)
    }

    private var series: [ChartPoint] {
        FinanceCalculator.monthlySeries(allTx.map(\.data), months: 6, reference: selectedMonth)
    }

    /// Épargne du mois = épargne fixe du profil (mois courant) + épargnes PONCTUELLES saisies.
    /// L'épargne fixe n'est plus matérialisée (modèle enveloppe) : on la lit du profil.
    private var savedThisMonth: Int {
        let punctual = FinanceCalculator.totalSaved(data, in: selectedMonth)
        let fixed = (isCurrentMonth ? profiles.first?.monthlySavingCents : nil) ?? 0
        return fixed + punctual
    }

    private var savedTotal: Int {
        FinanceCalculator.cumulativeSaved(allTx.map(\.data))
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

    private func alertBanner(_ alert: BudgetAlert) -> some View {
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

    /// Couleur d'état (teinte la barre + le point) selon le statut budgétaire du mois affiché.
    private var heroAccent: Color {
        guard hasBudget else { return LumeColor.muted }
        switch BudgetStatus.of(spent: spent, budget: displayedBudgetCents) {
        case .under: return LumeColor.success
        case .near: return LumeColor.warning
        case .over: return LumeColor.negative
        }
    }

    /// Hero coloré plein : grande carte encre, montant blanc, barre fine. Remplace l'anneau (qui
    /// « criait vide » à 0 %). Le mois se change DANS la carte ; l'état budgétaire teinte la barre.
    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Mois (blanc sur fond sombre) + pastille d'état à droite.
            HStack {
                MonthStepper(month: $selectedMonth,
                             labelTint: LumeColor.surface,
                             controlTint: LumeColor.surface.opacity(LumeOpacity.strong),
                             disabledTint: LumeColor.surface.opacity(LumeOpacity.disabled))
                Spacer()
                if hasBudget { heroStatusChip }
            }

            // Chiffre clé : le RESTE (ou le dépensé si pas de budget), blanc, qui monte.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                CountUpAmount(targetCents: hasBudget ? max(0, displayedBudgetCents - spent) : spent,
                              font: .lumeNumberXL, tint: LumeColor.surface,
                              animatesOnChange: isCurrentMonth)
                    .scaleEffect(ringPulse ? 1.03 : 1, anchor: .leading)
                    .animation(reduceMotion ? nil : LumeMotion.celebrate, value: ringPulse)
                Text(hasBudget ? "reste à dépenser" : "dépensé ce mois")
                    .font(.lumeSubhead).foregroundStyle(LumeColor.surface.opacity(LumeOpacity.secondary))
            }

            if hasBudget {
                BudgetProgressBar(progress: FinanceCalculator.progress(spent: spent, budget: displayedBudgetCents),
                                  fill: heroAccent)
                HStack {
                    if spent == 0, isCurrentMonth {
                        Text("Tout ton budget t'attend.")
                            .font(.lumeFootnote).foregroundStyle(LumeColor.surface.opacity(LumeOpacity.secondary))
                    } else {
                        Text("\(Money.format(spent)) sur \(Money.format(displayedBudgetCents))")
                            .font(.lumeFootnote).foregroundStyle(LumeColor.surface.opacity(LumeOpacity.secondary))
                    }
                    Spacer()
                    Text("\(Int(FinanceCalculator.progress(spent: spent, budget: displayedBudgetCents) * 100)) %")
                        .font(.lumeFootnote.weight(.bold)).foregroundStyle(LumeColor.surface)
                        .monospacedDigit().contentTransition(.numericText())
                }
            } else {
                // Pas de budget → CTA blanc plein vers « Mon budget » (revenu, source du budget dérivé).
                Button { route = .profile } label: {
                    HStack(spacing: Spacing.sm) {
                        Text("Définir mon budget").font(.lumeCallout)
                        Image(appIcon: .forward).lumeIcon(12, weight: .bold)
                    }
                    .foregroundStyle(LumeColor.ink)
                    .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(LumeColor.surface, in: Capsule())
                }.buttonStyle(.lumePress)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LumeColor.ink, in: RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .lumeShadow(.card)
    }

    /// Petite pastille d'état (vert/ambre/rouge) en haut à droite du hero.
    private var heroStatusChip: some View {
        let label: String = {
            switch BudgetStatus.of(spent: spent, budget: displayedBudgetCents) {
            case .under: return "Dans les clous"
            case .near: return "Bientôt limite"
            case .over: return "Dépassé"
            }
        }()
        return HStack(spacing: Spacing.xs) {
            Circle().fill(heroAccent).frame(width: 7, height: 7)
            Text(label).font(.lumeCaption).foregroundStyle(LumeColor.surface.opacity(LumeOpacity.strong))
        }
        .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
        .background(LumeColor.surface.opacity(LumeOpacity.pill), in: Capsule())
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
                    .background((savingGoalReached ? LumeColor.success : LumeColor.fat).opacity(LumeOpacity.pill), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text("Épargne").font(.lumeCallout).foregroundStyle(LumeColor.ink)
                        if savingGoalReached {
                            Text("Objectif atteint").font(.lumeCaption.weight(.bold)).foregroundStyle(LumeColor.success)
                                .padding(.horizontal, Spacing.sm).padding(.vertical, 2)
                                .background(LumeColor.success.opacity(LumeOpacity.pill), in: Capsule())
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
        .animation(reduceMotion ? nil : LumeMotion.celebrate, value: ringPulse)
    }

    /// 2 tuiles « Revenus / Épargné » (icônes en pastille), lues du profil.
    /// Pas de « solde réel à vivre » ici : c'est exactement le « reste à dépenser » du hero (revenu −
    /// loyer − charges − épargne − dépenses), donc l'afficher en double était redondant et trompeur.
    private var statsRow: some View {
        HStack(spacing: Spacing.md) {
            StatTile(icon: .salary, tint: LumeColor.success, value: Money.format(income),
                     label: "Revenus du mois", iconInPill: true)
            StatTile(icon: .savings, tint: LumeColor.fat, value: Money.format(savedThisMonth),
                     label: "Épargné ce mois", iconInPill: true)
        }
        .animation(reduceMotion ? nil : LumeMotion.smooth, value: income)
    }

    /// Catégories ayant un budget défini (> 0), triées par dépense décroissante.
    /// On masque `housing` : le loyer est géré dans « Mon budget » (jamais un plafond catégorie) —
    /// défense en profondeur contre un éventuel plafond Logement orphelin créé avant le fix.
    private var activeBudgets: [(category: ExpenseCategory, spent: Int, limit: Int)] {
        budgets.filter { $0.monthlyLimitCents > 0 && $0.category != .housing }
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
