import Charts
import SwiftData
import SwiftUI

struct ProgressDashboardView: View {
    @Environment(HealthManager.self) private var health
    @Environment(\.modelContext) private var ctx
    @Query private var weekFoods: [LoggedFood] // borné aux 7 derniers jours
    @Query(sort: \LoggedFood.date, order: .reverse) private var allFoods: [LoggedFood]
    @Query(sort: \WeightSample.date) private var weightSamples: [WeightSample]
    @Query(sort: \WorkoutSessionModel.date, order: .reverse) private var sessions: [WorkoutSessionModel]
    @Query private var profiles: [ProfileRecord]
    @AppStorage(WeightFormat.defaultsKey) private var useImperial = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showStreak = false
    @State private var showWeightEntry = false
    @State private var showPRHistory = false
    @State private var editingSample: WeightSample?
    @State private var deletingSample: WeightSample?
    /// Date sélectionnée sur le graphe poids (tap) → lollipop + point d'entrée à l'édition.
    @State private var selectedDate: Date?
    @State private var period: ChartPeriod = .week
    /// Anime les barres du graphe calories à l'apparition (montée de 0 → valeur).
    @State private var chartGrow: Double = 0
    /// Affiche brièvement la pastille de célébration quand l'objectif de poids est atteint.
    @State private var showGoalBurst = false

    init() {
        // `weekFoods` reste borné à 7 j pour la carte « Cette semaine » (jours suivis, kcal vs cible).
        let weekStart = Calendar.current.date(byAdding: .day, value: -6,
                                              to: Calendar.current.startOfDay(for: Date()))!
        _weekFoods = Query(filter: #Predicate<LoggedFood> { $0.date >= weekStart },
                           sort: \LoggedFood.date, order: .reverse)
    }

    /// Fusion HealthKit + pesées locales, dédupliquée par jour (HealthKit prioritaire).
    /// Plus de perte de points (l'ancien « HealthKit sinon local » masquait l'historique local).
    private var allWeights: [WeightEntry] {
        WeightMerge.merge(healthKit: health.weightSeries,
                          local: weightSamples.map { WeightEntry(date: $0.date, kg: $0.kg) })
    }

    /// Pesées filtrées sur la période sélectionnée (pour les graphes).
    private var weights: [WeightEntry] {
        guard let start = period.start() else { return allWeights }
        return allWeights.filter { $0.date >= start }
    }

    private var hasWeightData: Bool {
        !weights.isEmpty
    }

    /// Série de poids lissée (moyenne glissante) pour une tendance lisible.
    private var smoothedWeights: [WeightEntry] {
        WeightTrend.smoothed(weights)
    }

    /// Calories selon la période : par jour (≤ 7 j) ou agrégées par semaine (> 7 j).
    private var week: [DayCalories] {
        if period.aggregatesByWeek, let start = period.start() {
            return WeeklyCalories.byWeek(from: allFoods, since: start)
        }
        return allFoods.isEmpty ? [] : WeeklyCalories.lastSevenDays(from: allFoods)
    }

    private var hasWeekData: Bool {
        week.contains { $0.kcal > 0 }
    }

    /// Comparaison kcal moyenne semaine courante vs précédente.
    private var weekComparison: (thisWeek: Int, lastWeek: Int, deltaPct: Double?) {
        WeeklyCalories.weekOverWeek(from: allFoods)
    }

    private var targetWeightKg: Double {
        profiles.first?.targetWeightKg ?? 0
    }

    private var streak: Int {
        StreakCalculator.currentStreak(from: allFoods.map(\.date))
    }

    private var streakRecord: Int {
        StreakCalculator.longestStreak(from: allFoods.map(\.date))
    }

    /// Poids actuel = dernière pesée absolue (indépendant de la période des graphes).
    private var current: Double {
        allWeights.last?.kg ?? 0
    }

    /// Variation sur 7 jours basée sur la tendance lissée (plus honnête que dernier−premier).
    /// `nil` tant qu'il n'y a pas assez de points pour une tendance. Calculée sur l'historique complet.
    private var delta: Double? {
        WeightTrend.movingAverageDelta(allWeights)
    }

    /// Moyenne kcal/jour sur la période sélectionnée (cohérente avec le graphe calories).
    private var avgKcal: Int {
        let active = caloriesPoints.filter { $0.value > 0 }
        return active.isEmpty ? 0 : active.map(\.value).reduce(0, +) / active.count
    }

    /// Macros moyennes (P/G/L) sur 7 j, pour les chips sous le graphe calories.
    private var weeklyMacros: Macros? {
        WeeklyMacros.average(from: weekFoods)
    }

    /// Filtre une série datée (pas, énergie active) sur la période sélectionnée.
    private func forPeriod(_ series: [DayValue]) -> [DayValue] {
        guard let start = period.start() else { return series }
        return series.filter { $0.date >= start }
    }

    private var stepsForPeriod: [DayValue] {
        forPeriod(health.stepsSeries)
    }

    /// Cible kcal cohérente avec l'écran Aujourd'hui : dynamique (BMR + calories actives
    /// réelles) si Santé est autorisé, sinon TDEE fixe.
    private var targetKcal: Int {
        guard let p = profiles.first?.profile else { return Mock.target.kcal }
        let active = health.isAuthorized && health.activeEnergyToday > 0 ? health.activeEnergyToday : nil
        return EnergyBudget.targetKcal(p, activeKcal: active, healthAuthorized: health.isAuthorized)
    }

    private var weekly: WeeklyGoals {
        WeeklyGoals.compute(foods: weekFoods, sessions: sessions, targetKcal: targetKcal,
                            workoutGoal: profiles.first?.weeklyWorkoutGoal ?? 3)
    }

    private var weeklyVolume: [VolumePoint] {
        WorkoutStats.weeklyVolume(from: sessions)
    }

    private var bestOneRM: Int {
        sessions.flatMap { $0.orderedExercises.map(\.bestOneRM) }.max() ?? 0
    }

    /// Bornes de l'axe Y du graphe poids. Inclut l'objectif s'il est défini (pour que la
    /// ligne pointillée reste visible). Défensif si la série venait à être vide.
    private var weightDomain: ClosedRange<Double> {
        var kgs = weights.map(\.kg)
        if targetWeightKg > 0 { kgs.append(targetWeightKg) }
        guard let lo = kgs.min(), let hi = kgs.max() else { return 0 ... 1 }
        return (lo - 1) ... (hi + 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.md) {
                    Button { showWeightEntry = true } label: {
                        StatTile(icon: .weight, tint: LumeColor.fat,
                                 value: allWeights.isEmpty ? "—" : WeightFormat.body(current, imperial: useImperial),
                                 label: "Poids actuel")
                    }.buttonStyle(.lumePress)
                    StatTile(icon: .progress,
                             tint: delta.map { $0 <= 0 ? LumeColor.success : LumeColor.protein } ?? LumeColor.muted,
                             value: delta.map { WeightFormat.bodyDelta($0, imperial: useImperial) } ?? "—",
                             label: "Variation")
                }
                .lumeEntrance(0)
                HStack(spacing: Spacing.md) {
                    StatTile(icon: .calories, tint: LumeColor.carbs, value: avgKcal > 0 ? "\(avgKcal)" : "—", label: "Moy. kcal / jour")
                    Button { if streak > 0 { showStreak = true } } label: {
                        StatTile(icon: .streak, tint: LumeColor.protein, value: streak > 0 ? "\(streak) j" : "—", label: "Série en cours")
                    }.buttonStyle(.lumePress)
                }
                .lumeEntrance(1)
                weeklyGoalsCard.lumeEntrance(2)
                periodPicker.lumeEntrance(3)
                weightCard.lumeEntrance(4)
                caloriesCard.lumeEntrance(5)
                if hasBalanceData { energyBalanceCard.lumeEntrance(6) }
                if health.isAuthorized, !stepsForPeriod.isEmpty { activityCard.lumeEntrance(7) }
                if !sessions.isEmpty { muscleCard.lumeEntrance(8) }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, 130)
        }
        .background(LumeColor.cream)
        .safeAreaInset(edge: .top) {
            Text("Progrès").font(.lumeDisplay).foregroundStyle(LumeColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm)
                .background(LumeColor.cream)
        }
        .task { await health.requestAuthorization() }
        .onAppear { withAnimation(reduceMotion ? nil : LumeMotion.smooth.delay(0.25)) { chartGrow = 1 } }
        // Transition douce des graphes au changement de période.
        .animation(LumeMotion.smooth, value: period)
        // Jalon léger : petite fête quand l'objectif de poids est atteint.
        .sensoryFeedback(.success, trigger: goalReached)
        .overlay(alignment: .top) {
            if goalReached, showGoalBurst {
                goalBurst.transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .onChange(of: goalReached) { _, reached in
            guard reached else { return }
            withAnimation(LumeMotion.celebrate) { showGoalBurst = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(LumeMotion.smooth) { showGoalBurst = false }
            }
        }
        .sheet(isPresented: $showStreak) {
            StreakDetailView(streak: streak, record: streakRecord)
        }
        .sheet(isPresented: $showWeightEntry) {
            WeightEntryView(current: allWeights.last?.kg)
        }
        .sheet(item: $editingSample) { sample in
            WeightEntryView(editing: sample)
        }
        .sheet(item: $deletingSample) { sample in
            LumeConfirmSheet(icon: .minusCircle, tint: LumeColor.negative,
                             title: "Supprimer cette pesée ?",
                             message: "\(WeightFormat.body(sample.kg, imperial: useImperial)) le \(Formatters.dayMonthFR.string(from: sample.date)). Gère tes données Apple Santé depuis l'app Santé.",
                             confirmTitle: "Supprimer")
            {
                ctx.delete(sample)
            }
        }
        .sheet(isPresented: $showPRHistory) {
            PRHistoryView()
        }
    }

    private var weeklyGoalsCard: some View {
        let w = weekly
        return LumeCard {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Cette semaine").font(.lumeHeadline).foregroundStyle(LumeColor.ink)

                GoalBar(label: "Jours suivis", value: "\(w.trackedDays)/7",
                        progress: w.trackingProgress, tint: LumeColor.protein)
                GoalBar(label: "Séances muscu", value: "\(w.workouts)/\(w.workoutGoal)",
                        progress: w.workoutProgress, tint: LumeColor.success)

                HStack {
                    Text("Moy. kcal vs cible").font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary)
                    Spacer()
                    Text("\(w.avgKcal) / \(w.targetKcal)")
                        .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).monospacedDigit()
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var muscleCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Volume muscu").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                    Spacer()
                    if bestOneRM > 0 {
                        Text("1RM max \(bestOneRM) kg").font(.lumeFootnote).foregroundStyle(LumeColor.muted).monospacedDigit()
                    }
                }
                Text("kg soulevés par semaine").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                Chart(weeklyVolume) { p in
                    BarMark(x: .value("Semaine", p.weekStart, unit: .weekOfYear),
                            y: .value("kg", p.volumeKg), width: .fixed(16))
                        .foregroundStyle(p.volumeKg == 0 ? LumeColor.faint : LumeColor.protein)
                        .cornerRadius(5)
                }
                .chartYAxis(.hidden)
                .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 2)) }
                .frame(height: 150)
                .accessibilityLabel("Volume de musculation par semaine")
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            // Accès rapide à l'historique des records.
            Button { showPRHistory = true } label: {
                Image(appIcon: .forward).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
                    .padding(Spacing.md)
            }.buttonStyle(.lumePress)
        }
    }

    /// Libellé directionnel de l'objectif de poids (selon le Goal du profil).
    private var targetLabel: String? {
        guard targetWeightKg > 0, !allWeights.isEmpty else { return nil }
        let goal = profiles.first?.profile.goal ?? .maintain
        return WeightTrend.targetLabel(current: current, target: targetWeightKg, goal: goal)
    }

    /// Objectif de poids atteint → déclenche le jalon (haptique + pastille).
    private var goalReached: Bool {
        targetLabel == "Objectif atteint"
    }

    /// Pastille de célébration éphémère affichée quand l'objectif est atteint.
    private var goalBurst: some View {
        HStack(spacing: Spacing.sm) {
            Image(appIcon: .validate).lumeIcon(16, weight: .bold).foregroundStyle(LumeColor.surface)
            Text("Objectif atteint 🎉").font(.lumeSubhead.weight(.bold)).foregroundStyle(LumeColor.surface)
        }
        .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.sm)
        .background(LumeColor.success, in: Capsule())
        .lumeShadow(.card)
        .padding(.top, Spacing.sm)
    }

    /// Progression vers l'objectif (0…1) : du poids de départ vers la cible. nil si non pertinent.
    private var targetProgress: Double? {
        guard targetWeightKg > 0, weights.count >= 2,
              let start = weights.first?.kg
        else { return nil }
        let total = start - targetWeightKg
        guard abs(total) > 0.001 else { return 1 }
        return min(1, max(0, (start - current) / total))
    }

    private var weightCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Poids").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                    Spacer()
                    if let targetLabel {
                        Text(targetLabel)
                            .font(.lumeFootnote).foregroundStyle(LumeColor.muted).monospacedDigit()
                    }
                }
                if weights.count >= 2 {
                    weightChart
                    if let p = targetProgress {
                        GoalBar(label: "Vers l'objectif", value: WeightFormat.body(targetWeightKg, imperial: useImperial, decimals: 0),
                                progress: p, tint: LumeColor.success)
                    }
                } else if weights.count == 1, let only = weights.first {
                    // Un seul point : pas de courbe (rien à interpoler), on invite à peser à nouveau.
                    VStack(spacing: Spacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(WeightFormat.body(only.kg, imperial: useImperial)).font(.lumeNumberL).foregroundStyle(LumeColor.ink).monospacedDigit()
                        }
                        Text("Ajoute une 2ᵉ pesée pour voir ta tendance.")
                            .font(.lumeFootnote).foregroundStyle(LumeColor.muted).multilineTextAlignment(.center)
                        SecondaryButton(title: "Peser à nouveau", icon: .add) { showWeightEntry = true }
                    }.frame(maxWidth: .infinity).padding(.vertical, Spacing.md)
                } else {
                    VStack(spacing: Spacing.md) {
                        LumeEmptyState(icon: .weight, title: "Ajoute ton poids",
                                       message: "Suis ton évolution au fil des semaines.")
                        SecondaryButton(title: "Ajouter", icon: .add) { showWeightEntry = true }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var weightChart: some View {
        Chart {
            // Points réels (discrets) — la vérité brute.
            ForEach(weights) { e in
                PointMark(x: .value("Date", e.date), y: .value("kg", e.kg))
                    .foregroundStyle(LumeColor.muted.opacity(0.5))
                    .symbolSize(18)
            }
            // Tendance lissée (ligne nette + aire douce).
            ForEach(smoothedWeights) { e in
                AreaMark(x: .value("Date", e.date), y: .value("kg", e.kg))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [LumeColor.ink.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", e.date), y: .value("kg", e.kg))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LumeColor.ink).lineStyle(.init(lineWidth: 2.5))
            }
            // Ligne d'objectif (pointillée) si défini.
            if targetWeightKg > 0 {
                RuleMark(y: .value("Objectif", targetWeightKg))
                    .lineStyle(.init(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(LumeColor.success)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Objectif \(WeightFormat.body(targetWeightKg, imperial: useImperial, decimals: 0))")
                            .font(.lumeFootnote).foregroundStyle(LumeColor.success)
                    }
            }
        }
        .chartYScale(domain: weightDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .font(.lumeFootnote)
            }
        }
        .chartXSelection(value: $selectedDate)
        .frame(height: 170)
        .opacity(chartGrow) // révélation douce de la courbe à l'apparition
        .accessibilityLabel("Évolution du poids")
        .accessibilityValue(hasWeightData ? String(format: "Actuel %.1f kilos", current) : "Aucune donnée")
        .overlay(alignment: .topLeading) { selectionLollipop }
        .sensoryFeedback(.selection, trigger: selectedEntry?.id)
    }

    /// Pesée la plus proche de la date tapée (parmi les points affichés).
    private var selectedEntry: WeightEntry? {
        guard let selectedDate else { return nil }
        return weights.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    /// WeightSample local correspondant au point sélectionné (pour Modifier/Supprimer).
    private var selectedSample: WeightSample? {
        guard let e = selectedEntry else { return nil }
        let cal = Calendar.current
        return weightSamples.first { cal.isDate($0.date, inSameDayAs: e.date) }
    }

    @ViewBuilder private var selectionLollipop: some View {
        if let e = selectedEntry {
            ChartLollipop(title: WeightFormat.body(e.kg, imperial: useImperial),
                          subtitle: Formatters.dayMonthFR.string(from: e.date))
            {
                if let sample = selectedSample {
                    Button { editingSample = sample } label: {
                        Image(appIcon: .edit).lumeIcon(15, weight: .semibold).foregroundStyle(LumeColor.ink)
                    }.buttonStyle(.lumePress)
                    Button { deletingSample = sample } label: {
                        Image(appIcon: .trash).lumeIcon(15, weight: .semibold).foregroundStyle(LumeColor.negative)
                    }.buttonStyle(.lumePress)
                }
            }
            .animation(LumeMotion.snappy, value: e.id)
        }
    }

    private var caloriesTitle: String {
        period.aggregatesByWeek ? "Calories / semaine" : "Calories cette semaine"
    }

    /// Métabolisme de repos (BMR) du profil — base de la dépense quotidienne.
    private var bmr: Int {
        profiles.first.map { Int(TDEECalculator.bmr($0.profile).rounded()) } ?? 0
    }

    /// Début de la fenêtre balance : début de période, sinon 1ʳᵉ pesée/repas réel (évite « Tout » infini).
    private var balanceStart: Date {
        if let start = period.start() { return start }
        let earliest = [allFoods.map(\.date).min(), health.activeEnergySeries.first?.date].compactMap { $0 }.min()
        return earliest ?? Calendar.current.date(byAdding: .day, value: -29, to: Date())!
    }

    /// Série jour-par-jour conso vs dépense (BMR + calories actives Santé).
    private var balanceSeries: [DayBalance] {
        let consumed = WeeklyCalories.consumedByDay(from: allFoods, since: balanceStart)
        return EnergyBalance.series(consumed: consumed,
                                    activeEnergy: forPeriod(health.activeEnergySeries),
                                    bmr: bmr)
    }

    /// On affiche la balance dès qu'on a un BMR et au moins un jour de conso ou de dépense.
    private var hasBalanceData: Bool {
        bmr > 0 && balanceSeries.contains { $0.consumed > 0 }
    }

    /// Net énergétique par jour (consommé − dépensé) en points de graphe.
    private var balanceNetPoints: [ChartPoint] {
        balanceSeries.map { ChartPoint(date: $0.date, value: $0.net) }
    }

    private var energyBalanceCard: some View {
        let avgNet = EnergyBalance.averageNet(balanceSeries)
        return LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Balance énergétique").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                    Spacer()
                    Text(avgNet <= 0 ? "déficit \(abs(avgNet)) kcal/j" : "surplus \(avgNet) kcal/j")
                        .font(.lumeFootnote.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(avgNet <= 0 ? LumeColor.success : LumeColor.negative)
                }
                // Net divergent autour de 0 : vert sous la ligne (déficit), rouge au-dessus (surplus).
                InteractiveBarChart(points: balanceNetPoints, diverging: true,
                                    format: { kcalLabel($0, signed: true) })
                    .accessibilityLabel("Balance énergétique nette par jour")
                HStack(spacing: Spacing.md) {
                    legendDot(LumeColor.success, "Déficit")
                    legendDot(LumeColor.negative, "Surplus")
                    Spacer()
                }
                Text(health.isAuthorized ? "Net = consommé − (repos + activité)." : "Dépense au repos seul — active Apple Santé pour inclure ton activité.")
                    .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
        }
    }

    /// Format kcal compact (« 1 850 kcal »), avec signe optionnel pour le net.
    private func kcalLabel(_ v: Int, signed: Bool = false) -> String {
        let s = signed && v > 0 ? "+" : ""
        return "\(s)\(v) kcal"
    }

    /// Calories consommées par jour (datées) sur la période, en points de graphe.
    private var caloriesPoints: [ChartPoint] {
        WeeklyCalories.consumedByDay(from: allFoods, since: balanceStart)
            .map { ChartPoint(date: $0.date, value: $0.value) }
    }

    private var caloriesCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Calories par jour").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                    Spacer()
                    if period == .week, hasWeekData, let pct = weekComparison.deltaPct {
                        let up = pct >= 0
                        Text(String(format: "%@%.0f %% vs S-1", up ? "+" : "−", abs(pct) * 100))
                            .font(.lumeFootnote.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(up ? LumeColor.protein : LumeColor.success)
                    }
                }
                if hasWeekData {
                    InteractiveBarChart(points: caloriesPoints, format: { kcalLabel($0) })
                        .accessibilityLabel("Calories consommées par jour")
                    if let m = weeklyMacros {
                        HStack(spacing: Spacing.sm) {
                            Chip(color: LumeColor.protein, text: "P \(m.protein) g")
                            Chip(color: LumeColor.carbs, text: "G \(m.carbs) g")
                            Chip(color: LumeColor.fat, text: "L \(m.fat) g")
                            Spacer()
                        }
                    }
                } else {
                    LumeEmptyState(icon: .calories, title: "Aucun repas",
                                   message: "Journalise tes repas pour suivre tes calories.")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var periodPicker: some View {
        SegmentedPicker(options: ChartPeriod.allCases.map(\.label),
                        selection: Binding(get: { period.rawValue },
                                           set: { period = ChartPeriod(rawValue: $0) ?? .week }))
            .frame(maxWidth: .infinity)
    }

    /// Calories actives (Santé) filtrées sur la période — moyenne/jour affichée sous le graphe.
    /// Moyenne par jour renseigné (> 0) d'une série datée. 0 si aucun.
    private func dayAverage(_ series: [DayValue]) -> Int {
        let active = series.filter { $0.value > 0 }
        return active.isEmpty ? 0 : active.map(\.value).reduce(0, +) / active.count
    }

    private var stepsPoints: [ChartPoint] {
        stepsForPeriod.map { ChartPoint(date: $0.date, value: $0.value) }
    }

    private var activityCard: some View {
        let avgSteps = dayAverage(stepsForPeriod)
        let avgActive = dayAverage(forPeriod(health.activeEnergySeries))
        return LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Pas").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                    Spacer()
                    Text("\(avgSteps) / jour en moyenne").font(.lumeFootnote).foregroundStyle(LumeColor.muted).monospacedDigit()
                }
                InteractiveBarChart(points: stepsPoints, tint: LumeColor.carbs, format: { "\($0) pas" }, height: 130)
                    .accessibilityLabel("Pas par jour")
                if avgActive > 0 {
                    HStack(spacing: Spacing.sm) {
                        Image(appIcon: .activeEnergy).lumeIcon(13, weight: .semibold).foregroundStyle(LumeColor.protein)
                        Text("\(avgActive) kcal actives / jour en moyenne")
                            .font(.lumeFootnote).foregroundStyle(LumeColor.muted).monospacedDigit()
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview { ProgressDashboardView().modelContainer(LumeStore.preview).environment(HealthManager.shared) }

// MARK: - Saisie de poids

struct WeightEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(HealthManager.self) private var health
    @AppStorage(WeightFormat.defaultsKey) private var useImperial = false
    @State private var kg: Double
    /// Pesée locale en cours d'édition (sinon nouvelle saisie).
    private let editing: WeightSample?

    init(current: Double?) {
        // Démarre au dernier poids connu (arrondi au demi-kilo), sinon 70 kg.
        let base = current ?? 70
        _kg = State(initialValue: (base * 2).rounded() / 2)
        editing = nil
    }

    /// Édition d'une pesée existante : pré-remplit sur sa valeur.
    init(editing sample: WeightSample) {
        _kg = State(initialValue: (sample.kg * 2).rounded() / 2)
        editing = sample
    }

    private func save() {
        let value = kg
        if let editing {
            // Édition : on met à jour la pesée locale (sa date reste celle d'origine).
            editing.kg = value
            Task { await health.saveWeight(kg: value, date: editing.date) }
        } else {
            let now = Date()
            // Dédup : une seule pesée locale par jour (évite le double-comptage du lissage).
            let day = Calendar.current.startOfDay(for: now)
            let next = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? now
            let sameDay = FetchDescriptor<WeightSample>(
                predicate: #Predicate { $0.date >= day && $0.date < next }
            )
            if let existing = try? ctx.fetch(sameDay) {
                existing.forEach(ctx.delete)
            }
            ctx.insert(WeightSample(date: now, kg: value))
            // Source de vérité = HealthKit ; copie locale comme repli hors-Santé.
            Task { await health.saveWeight(kg: value, date: now) }
        }
        dismiss()
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Text(editing == nil ? "Ton poids" : "Modifier la pesée").font(.lumeTitle).foregroundStyle(LumeColor.ink)
            HStack(spacing: Spacing.lg) {
                RoundIconButton(icon: .minus) { kg = max(35, kg - WeightFormat.stepKg(imperial: useImperial)) }
                Text(WeightFormat.body(kg, imperial: useImperial))
                    .font(.lumeNumberL).foregroundStyle(LumeColor.ink).monospacedDigit().frame(minWidth: 140)
                RoundIconButton(icon: .add, filled: true) { kg = min(250, kg + WeightFormat.stepKg(imperial: useImperial)) }
            }
            Spacer()
            PrimaryButton(title: "Enregistrer", icon: .validate) { save() }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .background(LumeColor.cream.ignoresSafeArea())
        .presentationDetents([.medium])
        .sensoryFeedback(.selection, trigger: kg)
    }
}

#Preview("Poids") { WeightEntryView(current: 74).modelContainer(LumeStore.preview).environment(HealthManager.shared) }
