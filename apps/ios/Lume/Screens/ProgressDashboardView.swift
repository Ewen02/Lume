import Charts
import SwiftData
import SwiftUI

struct ProgressDashboardView: View {
    @Environment(HealthManager.self) private var health
    @Query private var weekFoods: [LoggedFood] // borné aux 7 derniers jours
    @Query(sort: \LoggedFood.date, order: .reverse) private var allFoods: [LoggedFood]
    @Query(sort: \WeightSample.date) private var weightSamples: [WeightSample]
    @Query(sort: \WorkoutSessionModel.date, order: .reverse) private var sessions: [WorkoutSessionModel]
    @Query private var profiles: [ProfileRecord]
    @State private var showStreak = false
    @State private var showWeightEntry = false
    /// Anime les barres du graphe calories à l'apparition (montée de 0 → valeur).
    @State private var chartGrow: Double = 0

    init() {
        let weekStart = Calendar.current.date(byAdding: .day, value: -6,
                                              to: Calendar.current.startOfDay(for: Date()))!
        _weekFoods = Query(filter: #Predicate<LoggedFood> { $0.date >= weekStart },
                           sort: \LoggedFood.date, order: .reverse)
    }

    /// Priorité : HealthKit → poids saisis localement (WeightSample). Vide si aucune donnée
    /// réelle (la vue affiche alors un état vide, jamais de courbe de démo).
    private var weights: [WeightEntry] {
        if !health.weightSeries.isEmpty { return health.weightSeries }
        return weightSamples.map { WeightEntry(date: $0.date, kg: $0.kg) }
    }

    private var hasWeightData: Bool { !weights.isEmpty }

    /// Série de poids lissée (moyenne glissante) pour une tendance lisible.
    private var smoothedWeights: [WeightEntry] {
        WeightTrend.smoothed(weights)
    }

    /// Calories par jour sur 7 jours. Vide si aucun repas enregistré (→ état vide).
    private var week: [DayCalories] {
        weekFoods.isEmpty ? [] : WeeklyCalories.lastSevenDays(from: weekFoods)
    }

    private var hasWeekData: Bool { week.contains { $0.kcal > 0 } }

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

    private var current: Double {
        weights.last?.kg ?? 0
    }

    /// Variation sur 7 jours basée sur la tendance lissée (plus honnête que dernier−premier).
    /// `nil` tant qu'il n'y a pas assez de points pour une tendance.
    private var delta: Double? {
        WeightTrend.movingAverageDelta(weights)
    }

    private var avgKcal: Int {
        WeeklyCalories.dailyAverage(of: week)
    }

    private var targetKcal: Int {
        profiles.first.map { TDEECalculator.target($0.profile).kcal } ?? Mock.target.kcal
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
                                 value: hasWeightData ? String(format: "%.1f kg", current) : "—",
                                 label: "Poids actuel")
                    }.buttonStyle(.lumePress)
                    StatTile(icon: .progress,
                             tint: (delta ?? 0) <= 0 ? LumeColor.success : LumeColor.protein,
                             value: delta.map { String(format: "%+.1f kg", $0) } ?? "—",
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
                weightCard.lumeEntrance(3)
                caloriesCard.lumeEntrance(4)
                if !sessions.isEmpty { muscleCard.lumeEntrance(5) }
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
        .onAppear { withAnimation(LumeMotion.smooth.delay(0.25)) { chartGrow = 1 } }
        .sheet(isPresented: $showStreak) {
            StreakDetailView(streak: streak, record: streakRecord)
        }
        .sheet(isPresented: $showWeightEntry) {
            WeightEntryView(current: weights.last?.kg)
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
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var weightCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Poids").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                    Spacer()
                    if hasWeightData, targetWeightKg > 0,
                       let remaining = WeightTrend.remainingToTarget(current: current, target: targetWeightKg)
                    {
                        Text(remaining == 0 ? "Objectif atteint" : String(format: "Reste %.1f kg", abs(remaining)))
                            .font(.lumeFootnote).foregroundStyle(LumeColor.muted).monospacedDigit()
                    }
                }
                if hasWeightData {
                    weightChart
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
                        Text(String(format: "Objectif %.0f kg", targetWeightKg))
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
        .frame(height: 170)
        .accessibilityLabel("Évolution du poids")
        .accessibilityValue(hasWeightData ? String(format: "Actuel %.1f kilos", current) : "Aucune donnée")
    }

    private var caloriesCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Calories cette semaine").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                    Spacer()
                    if hasWeekData, let pct = weekComparison.deltaPct {
                        let up = pct >= 0
                        Text(String(format: "%@%.0f %% vs S-1", up ? "+" : "−", abs(pct) * 100))
                            .font(.lumeFootnote.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(up ? LumeColor.protein : LumeColor.success)
                    }
                }
                if hasWeekData {
                    Chart(week) { d in
                        BarMark(x: .value("Jour", d.label), y: .value("kcal", Double(d.kcal) * chartGrow), width: .fixed(22))
                            .foregroundStyle(d.kcal == 0 ? LumeColor.faint : LumeColor.ink)
                            .cornerRadius(6)
                    }
                    .chartYScale(domain: 0 ... Double(max(week.map(\.kcal).max() ?? 1, 1)))
                    .chartYAxis(.hidden)
                    .frame(height: 150)
                    .accessibilityLabel("Calories des 7 derniers jours")
                } else {
                    LumeEmptyState(icon: .calories, title: "Aucun repas cette semaine",
                                   message: "Journalise tes repas pour suivre tes calories.")
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
    @State private var kg: Double

    init(current: Double?) {
        // Démarre au dernier poids connu (arrondi au demi-kilo), sinon 70 kg.
        let base = current ?? 70
        _kg = State(initialValue: (base * 2).rounded() / 2)
    }

    private func save() {
        // Source de vérité = HealthKit ; copie locale (WeightSample) comme repli hors-Santé.
        let value = kg, now = Date()
        Task { await health.saveWeight(kg: value, date: now) }
        ctx.insert(WeightSample(date: now, kg: value))
        dismiss()
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Text("Ton poids").font(.lumeTitle).foregroundStyle(LumeColor.ink)
            HStack(spacing: Spacing.lg) {
                RoundIconButton(icon: .minus) { kg = max(35, kg - 0.5) }
                Text(String(format: "%.1f kg", kg))
                    .font(.lumeNumberL).foregroundStyle(LumeColor.ink).monospacedDigit().frame(minWidth: 140)
                RoundIconButton(icon: .add, filled: true) { kg = min(250, kg + 0.5) }
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
