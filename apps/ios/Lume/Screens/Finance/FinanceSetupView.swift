import SwiftData
import SwiftUI

/// Onboarding financier immersif (plein écran, hors tab bar). Parcours thématique en 6 étapes
/// comptées (+ écran de bienvenue) : Revenus → Loyer → Charges fixes → Courses → Épargne → Récap.
/// Une décision par écran, progression épaisse, « Passer » sur les étapes non critiques, retour,
/// pré-remplissages intelligents (loyer ~30 %, épargne ~20 %), récap animé.
/// Modèle « enveloppe » : le profil (revenu, loyer, charges, épargne) est la source de vérité ;
/// seuls le salaire (revenu) et le budget global (= dépenses variables) en découlent. Loyer/charges/
/// épargne ne sont PAS matérialisés ; les courses deviennent un plafond de budget catégorie.
struct FinanceSetupView: View {
    @Environment(\.modelContext) private var ctx
    @AppStorage(FinanceSettings.globalBudgetKey) private var globalBudgetCents = 0
    @AppStorage(FinanceSettings.setupDoneKey) private var setupDone = false

    // Pour une reconfiguration propre (upsert / purge plutôt que doublons).
    @Query private var profiles: [FinanceProfile]
    @Query private var recurrings: [RecurringTransaction]
    @Query private var budgets: [CategoryBudget]
    @Query private var savedCharges: [FixedCharge]

    /// Étapes comptées dans la progression (la bienvenue = 0, non comptée).
    private let countedSteps = 6
    @State private var step = 0
    @State private var goingBack = false // sens de la dernière transition (pour l'animation)
    @State private var welcomeAppeared = false
    @FocusState private var keyboardActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Saisies
    @State private var annualMode = false
    @State private var incomeInputCents = 0
    @State private var rentCents = 0
    @State private var rentTouched = false
    @State private var charges: [DraftCharge] = []
    @State private var groceriesCents = 0
    @State private var savingCents = 0
    @State private var savingTouched = false

    private struct DraftCharge: Identifiable {
        let id = UUID()
        var label: String
        var category: ExpenseCategory
        var cents: Int
    }

    // MARK: Dérivés

    private var monthlyIncomeCents: Int {
        annualMode ? BudgetPlanner.monthly(fromAnnual: incomeInputCents) : incomeInputCents
    }

    private var totalChargesCents: Int {
        charges.reduce(0) { $0 + $1.cents }
    }

    /// Total de tout ce qui est « engagé » hors dépenses variables : loyer + charges + courses + épargne.
    private var committedCents: Int {
        rentCents + totalChargesCents + groceriesCents + savingCents
    }

    /// Reste à répartir affiché pendant la saisie (revenu − ce qui est déjà engagé).
    private var remainingToAllocate: Int {
        monthlyIncomeCents - committedCents
    }

    /// Reste à vivre final = revenu − loyer − charges − épargne (les courses sont une dépense variable
    /// budgétée, pas une « ponction » : elles restent dans le budget de dépenses).
    private var resteAVivre: Int {
        BudgetPlanner.resteAVivre(monthlyIncomeCents: monthlyIncomeCents,
                                  fixedMonthlyCents: rentCents + totalChargesCents + savingCents)
    }

    private var canAdvance: Bool {
        step == 1 ? monthlyIncomeCents > 0 : true // seul le revenu est obligatoire
    }

    /// Répartition 50/30/20 pour le récap : Besoins (loyer+charges+courses) / Envies (reste) / Épargne.
    private var needsCents: Int {
        rentCents + totalChargesCents + groceriesCents
    }

    private var wantsCents: Int {
        max(0, resteAVivre)
    }

    private var recapShare: (needs: Double, wants: Double, savings: Double) {
        let total = max(1, needsCents + wantsCents + savingCents)
        return (Double(needsCents) / Double(total),
                Double(wantsCents) / Double(total),
                Double(savingCents) / Double(total))
    }

    /// Le « Passer » est proposé sur les étapes non critiques (pas la bienvenue ni les revenus).
    private var canSkip: Bool {
        step >= 2 && step <= 5
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            // Navigation par boutons : un switch animé (pas un TabView pageable) → aucun conflit
            // swipe/scroll, et une transition de glissement propre à chaque étape.
            ZStack {
                stepView
                    .id(step)
                    // Transition directionnelle : Continuer → arrive par la droite ; Retour → par la gauche.
                    .transition(.asymmetric(
                        insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .opacity),
                        removal: .move(edge: goingBack ? .trailing : .leading).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(LumeMotion.smooth, value: step)

            ctaBar
        }
        .background(
            LumeColor.cream.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { keyboardActive = false } // tap hors champ → ferme le clavier
        )
        .sensoryFeedback(.selection, trigger: step)
        // Récompense au reveal final : haptique de succès en arrivant sur le récap.
        .sensoryFeedback(.success, trigger: step == countedSteps)
        // Reconfiguration : pré-remplit depuis le profil existant (au lieu de repartir de zéro).
        .onAppear(perform: prefillFromProfile)
    }

    /// Pré-remplit les saisies depuis le `FinanceProfile` existant (cas « Reconfigurer »).
    private func prefillFromProfile() {
        guard let p = profiles.first, incomeInputCents == 0, !rentTouched else { return }
        annualMode = false
        incomeInputCents = p.monthlyNetIncomeCents
        rentCents = p.rentCents
        rentTouched = p.rentCents > 0
        savingCents = p.monthlySavingCents
        savingTouched = p.monthlySavingCents > 0
        if let g = budgets.first(where: { $0.category == .groceries }) { groceriesCents = g.monthlyLimitCents }
        // Détail des charges conservé entre deux configurations : on restaure chaque ligne saisie
        // (label + catégorie + montant). Repli sur une ligne agrégée si seul un total historique existe.
        if !savedCharges.isEmpty {
            charges = savedCharges
                .sorted { $0.amountCents > $1.amountCents }
                .map { DraftCharge(label: $0.label, category: $0.category, cents: $0.amountCents) }
        } else if p.fixedChargesCents > 0 {
            charges = [DraftCharge(label: "Charges", category: .subscriptions, cents: p.fixedChargesCents)]
        }
    }

    @ViewBuilder private var stepView: some View {
        switch step {
        case 0: welcomeStep
        case 1: incomeStep
        case 2: rentStep
        case 3: chargesStep
        case 4: groceriesStep
        case 5: savingStep
        default: recapStep
        }
    }

    // MARK: Barres haut/bas

    private var topBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                if step > 1 {
                    Button { back() } label: {
                        Image(appIcon: .back).lumeIcon(16, weight: .semibold).foregroundStyle(LumeColor.ink)
                            .frame(width: 36, height: 36).background(LumeColor.surface, in: Circle()).lumeShadow(.soft)
                    }.buttonStyle(.lumePress)
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
                Spacer()
                if step == 0 {
                    Button("Passer") { complete() }
                        .font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                } else if canSkip {
                    Button("Passer") { advance() }
                        .font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                }
            }
            if step >= 1 {
                OnboardingProgress(step: step, total: countedSteps)
                    .animation(LumeMotion.snappy, value: step)
            }
        }
        .padding(.horizontal, Spacing.xl).padding(.top, Spacing.lg).padding(.bottom, Spacing.sm)
    }

    private var ctaBar: some View {
        PrimaryButton(title: step == countedSteps ? "Voir mon budget" : (step == 0 ? "Commencer" : "Continuer"),
                      icon: step == countedSteps ? .validate : .forward)
        {
            if step == countedSteps { finish() } else { advance() }
        }
        .disabled(!canAdvance).opacity(canAdvance ? 1 : 0.5)
        .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)
    }

    // MARK: Étapes

    private var welcomeStep: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            // Icône qui « pop » à l'arrivée (spring bouncy), sauf Reduce Motion.
            Image(appIcon: .money).lumeIcon(64, weight: .semibold).foregroundStyle(LumeColor.success)
                .scaleEffect(welcomeAppeared ? 1 : 0.5)
                .opacity(welcomeAppeared ? 1 : 0)
                .onAppear {
                    if reduceMotion { welcomeAppeared = true }
                    else { withAnimation(LumeMotion.bouncy) { welcomeAppeared = true } }
                }
            Text("Ton budget, simplement").font(.lumeNumberL).foregroundStyle(LumeColor.ink)
                .multilineTextAlignment(.center).lumeEntrance(1)
            Text("En 90 secondes : tes revenus, tes dépenses,\net ce qu'il te reste vraiment à vivre.")
                .multilineTextAlignment(.center).font(.lumeBody).foregroundStyle(LumeColor.textSecondary)
                .lumeEntrance(2)
            Spacer()
        }.padding(.horizontal, Spacing.xxl)
    }

    private var incomeStep: some View {
        stepScroll {
            stepHead("Tes revenus", "On calcule ton budget à partir de ton salaire net.")
            LumeCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SegmentedPicker(options: ["Mensuel net", "Annuel net"],
                                    selection: Binding(get: { annualMode ? 1 : 0 }, set: { annualMode = $0 == 1 }))
                    AmountStepper(cents: $incomeInputCents, tint: LumeColor.success)
                        .focused($keyboardActive)
                    if annualMode, monthlyIncomeCents > 0 {
                        Text("soit \(Money.format(monthlyIncomeCents)) net / mois")
                            .font(.lumeFootnote).foregroundStyle(LumeColor.muted).transition(.opacity)
                    }
                }
            }
        }
    }

    private var rentStep: some View {
        stepScroll {
            stepHead("Ton loyer", "Ta plus grosse dépense fixe du mois.")
            amountCard(cents: $rentCents, tint: LumeColor.ink, touched: $rentTouched,
                       prefill: BudgetPlanner.suggestedRent(monthlyIncomeCents: monthlyIncomeCents))
            remainingBanner
        }
    }

    private var chargesStep: some View {
        stepScroll {
            stepHead("Tes charges fixes", "Abonnements, assurances, factures… recréés chaque mois.")
            ForEach($charges) { $item in chargeCard($item) }
            Button { withAnimation(LumeMotion.snappy) { charges.append(DraftCharge(label: "", category: .subscriptions, cents: 0)) } } label: {
                HStack(spacing: Spacing.sm) {
                    Image(appIcon: .add).lumeIcon(14, weight: .semibold)
                    Text(charges.isEmpty ? "Ajouter une charge" : "Ajouter une autre charge").font(.lumeSubhead)
                }.foregroundStyle(LumeColor.ink)
            }.buttonStyle(.lumePress)
            if totalChargesCents > 0 {
                Text("Total charges : \(Money.format(totalChargesCents)) / mois")
                    .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).transition(.opacity)
            }
            remainingBanner
        }
    }

    private var groceriesStep: some View {
        stepScroll {
            stepHead("Tes courses", "Une estimation de ton budget courses & quotidien par mois.")
            amountCard(cents: $groceriesCents, tint: LumeColor.carbs, touched: .constant(true), prefill: 0)
        }
    }

    private var savingStep: some View {
        stepScroll {
            stepHead("Ton épargne", "Mets de côté avant de dépenser. Tu peux laisser 0 et l'ajuster plus tard.")
            amountCard(cents: $savingCents, tint: LumeColor.fat, touched: $savingTouched,
                       prefill: BudgetPlanner.suggestedSaving(monthlyIncomeCents: monthlyIncomeCents))
            remainingBanner
        }
    }

    private var recapStep: some View {
        stepScroll {
            stepHead("Ton budget est prêt", "Voici ce qu'il te reste pour vivre ce mois-ci.")
            LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
                VStack(spacing: Spacing.md) {
                    ProgressRing(progress: 1, color: resteAVivre >= 0 ? LumeColor.success : LumeColor.negative, lineWidth: 12) {
                        VStack(spacing: 2) {
                            CountUpAmount(targetCents: max(0, resteAVivre),
                                          tint: resteAVivre >= 0 ? LumeColor.ink : LumeColor.negative)
                            Text("à vivre / mois").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                        }.padding(.horizontal, Spacing.sm)
                    }.frame(width: 150, height: 150)
                }.frame(maxWidth: .infinity)
            }
            // Répartition 50/30/20 : Besoins / Envies / Épargne, en GoalBar avec % du revenu.
            LumeCard {
                VStack(spacing: Spacing.md) {
                    SectionHeader(title: "Ta répartition")
                    GoalBar(label: "Besoins (fixes + courses)",
                            value: Money.format(needsCents), progress: recapShare.needs, tint: LumeColor.ink)
                    GoalBar(label: "Envies (reste à vivre)",
                            value: Money.format(wantsCents), progress: recapShare.wants, tint: LumeColor.success)
                    GoalBar(label: "Épargne",
                            value: Money.format(savingCents), progress: recapShare.savings, tint: LumeColor.fat)
                }
            }
            LumeCard {
                VStack(spacing: Spacing.md) {
                    recapRow("Revenus", Money.format(monthlyIncomeCents), LumeColor.success)
                    recapRow("− Loyer", Money.format(rentCents), LumeColor.muted)
                    recapRow("− Charges fixes", Money.format(totalChargesCents), LumeColor.muted)
                    recapRow("− Épargne", Money.format(savingCents), LumeColor.fat)
                    Rectangle().fill(LumeColor.border).frame(height: 1)
                    recapRow("Reste à vivre", Money.format(max(0, resteAVivre)),
                             resteAVivre >= 0 ? LumeColor.ink : LumeColor.negative, bold: true)
                }
            }
            if resteAVivre < 0 {
                Text("Tes dépenses fixes + épargne dépassent tes revenus. Ajuste un montant avec le bouton Retour.")
                    .font(.lumeFootnote).foregroundStyle(LumeColor.negative)
            }
        }
    }

    // MARK: Composants d'étape

    /// Carte de saisie d'un montant unique, avec pré-remplissage intelligent et chips d'ajustement.
    private func amountCard(cents: Binding<Int>, tint: Color, touched: Binding<Bool>, prefill: Int) -> some View {
        LumeCard {
            VStack(spacing: Spacing.md) {
                AmountStepper(cents: cents, tint: tint).focused($keyboardActive)
                HStack(spacing: Spacing.sm) {
                    ForEach([5000, 10000, 25000], id: \.self) { inc in
                        Button("+\(inc / 100) €") {
                            touched.wrappedValue = true
                            cents.wrappedValue += inc
                        }
                        .font(.lumeFootnote.weight(.semibold)).foregroundStyle(LumeColor.ink)
                        .padding(.vertical, Spacing.xs).frame(maxWidth: .infinity)
                        .background(LumeColor.faint, in: Capsule())
                    }
                }
            }
        }
        // Dès que l'utilisateur ouvre le clavier sur ce champ, on considère qu'il l'a « touché » :
        // taper 0 puis revenir en arrière ne ré-écrase plus avec le pré-remplissage.
        .onChange(of: keyboardActive) { _, active in if active { touched.wrappedValue = true } }
        .onAppear {
            // Pré-remplit une suggestion seulement si jamais touché et encore vide.
            if !touched.wrappedValue, cents.wrappedValue == 0, prefill > 0 { cents.wrappedValue = prefill }
        }
    }

    private func chargeCard(_ item: Binding<DraftCharge>) -> some View {
        LumeCard {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    Image(appIcon: item.wrappedValue.category.icon).lumeIcon(16, weight: .semibold)
                        .foregroundStyle(item.wrappedValue.category.tint)
                        .frame(width: 36, height: 36).background(item.wrappedValue.category.tint.opacity(0.14), in: Circle())
                    TextField("Nom (ex. Assurance)", text: item.label).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                    Spacer()
                    Button { withAnimation(LumeMotion.snappy) { charges.removeAll { $0.id == item.wrappedValue.id } } } label: {
                        Image(appIcon: .minusCircle).lumeIcon(20).foregroundStyle(LumeColor.muted)
                    }.buttonStyle(.lumePress)
                }
                inlineAmountField(item.cents)
                CategoryPicker(selection: item.category)
            }
        }
    }

    private func inlineAmountField(_ cents: Binding<Int>) -> some View {
        let text = Binding<String>(
            get: { cents.wrappedValue == 0 ? "" : Money.plainDecimal(cents.wrappedValue) },
            set: { cents.wrappedValue = Money.parse($0) ?? 0 }
        )
        return HStack {
            Text("Montant / mois").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($keyboardActive)
                .font(.lumeCallout).foregroundStyle(LumeColor.ink).monospacedDigit().frame(width: 90)
            Text("€").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
        }
    }

    /// Bandeau « reste à répartir » qui roule à chaque saisie (contentTransition numérique).
    @ViewBuilder private var remainingBanner: some View {
        if monthlyIncomeCents > 0 {
            HStack {
                Text("Reste à répartir").font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary)
                Spacer()
                Text(Money.format(remainingToAllocate))
                    .font(.lumeCallout.weight(.bold)).monospacedDigit()
                    .foregroundStyle(remainingToAllocate >= 0 ? LumeColor.ink : LumeColor.negative)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.md)
            .background(LumeColor.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .lumeShadow(.soft)
            .animation(LumeMotion.snappy, value: remainingToAllocate)
        }
    }

    // MARK: Helpers

    private func stepScroll<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) { content() }
                .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func stepHead(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.lumeTitle).foregroundStyle(LumeColor.ink)
            Text(subtitle).font(.lumeSubhead).foregroundStyle(LumeColor.muted)
        }.padding(.top, Spacing.sm)
    }

    private func recapRow(_ label: String, _ value: String, _ tint: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(bold ? .lumeHeadline : .lumeBodyMed).foregroundStyle(bold ? LumeColor.ink : LumeColor.textSecondary)
            Spacer()
            Text(value).font(bold ? .lumeHeadline : .lumeCallout).foregroundStyle(tint).monospacedDigit()
        }
    }

    // MARK: Navigation & persistance

    private func advance() {
        keyboardActive = false
        goingBack = false
        withAnimation(LumeMotion.smooth) { step = min(countedSteps, step + 1) }
    }

    private func back() {
        keyboardActive = false
        goingBack = true
        withAnimation(LumeMotion.smooth) { step = max(0, step - 1) }
    }

    /// Modèle enveloppe : on upsert le profil (source de vérité), on ne matérialise QUE le salaire
    /// (revenu, pour le solde), les courses deviennent un budget catégorie, et le budget global =
    /// dépenses variables. Loyer/charges/épargne ne sont PAS matérialisés (déjà déduits du budget).
    /// Reconfiguration : on purge ce qu'on avait posé (pas de doublons).
    private func finish() {
        // 1. Upsert du profil (source de vérité).
        let profile = profiles.first ?? {
            let p = FinanceProfile(); ctx.insert(p); return p
        }()
        profile.monthlyNetIncomeCents = monthlyIncomeCents
        profile.rentCents = rentCents
        profile.fixedChargesCents = totalChargesCents
        profile.monthlySavingCents = savingCents

        // 1b. Détail des charges : on remplace l'ensemble (purge + réinsertion) pour un reconfig fidèle.
        // Le total reste dans le profil (déduit du budget) ; ce détail ne sert qu'à ré-afficher la saisie.
        for c in savedCharges {
            ctx.delete(c)
        }
        for c in charges where c.cents > 0 {
            ctx.insert(FixedCharge(label: c.label, amountCents: c.cents, category: c.category))
        }

        // 2. Salaire : une seule récurrente revenu (purge les anciennes salaires avant de recréer).
        for r in recurrings where r.kind == .income && r.category == .salary {
            ctx.delete(r)
        }
        if monthlyIncomeCents > 0 {
            ctx.insert(RecurringTransaction(label: "Salaire", amountCents: monthlyIncomeCents,
                                            kind: .income, category: .salary, frequency: .monthly, dayOfMonth: 1))
        }

        // 3. Courses : plafond de budget catégorie (pas une transaction). Upsert.
        if groceriesCents > 0 {
            if let b = budgets.first(where: { $0.category == .groceries }) {
                b.monthlyLimitCents = groceriesCents
            } else {
                ctx.insert(CategoryBudget(category: .groceries, monthlyLimitCents: groceriesCents))
            }
        }

        // 4. Budget global = dépenses variables (revenu − fixes − épargne).
        globalBudgetCents = profile.variableBudgetCents
        complete()
    }

    private func complete() {
        setupDone = true
    }
}

#Preview {
    FinanceSetupView().modelContainer(LumeStore.preview)
}
