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

    init() {
        let weekStart = Calendar.current.date(byAdding: .day, value: -6,
                                              to: Calendar.current.startOfDay(for: Date()))!
        _weekFoods = Query(filter: #Predicate<LoggedFood> { $0.date >= weekStart },
                           sort: \LoggedFood.date, order: .reverse)
    }

    /// Priorité : HealthKit → poids saisis localement (WeightSample) → démo.
    private var weights: [WeightEntry] {
        if !health.weightSeries.isEmpty { return health.weightSeries }
        if !weightSamples.isEmpty { return weightSamples.map { WeightEntry(date: $0.date, kg: $0.kg) } }
        return Mock.weights
    }

    /// Calories par jour sur 7 jours : repli démo seulement si aucun repas enregistré.
    private var week: [DayCalories] {
        weekFoods.isEmpty ? Mock.weekCalories : WeeklyCalories.lastSevenDays(from: weekFoods)
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

    private var delta: Double {
        (weights.last?.kg ?? 0) - (weights.first?.kg ?? 0)
    }

    private var avgKcal: Int {
        WeeklyCalories.dailyAverage(of: week)
    }

    private var targetKcal: Int {
        profiles.first.map { TDEECalculator.target($0.profile).kcal } ?? Mock.target.kcal
    }

    private var weekly: WeeklyGoals {
        WeeklyGoals.compute(foods: weekFoods, sessions: sessions, targetKcal: targetKcal)
    }

    /// Bornes de l'axe Y du graphe poids (défensif si la série venait à être vide).
    private var weightDomain: ClosedRange<Double> {
        let kgs = weights.map(\.kg)
        guard let lo = kgs.min(), let hi = kgs.max() else { return 0 ... 1 }
        return (lo - 1) ... (hi + 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.md) {
                    Button { showWeightEntry = true } label: {
                        StatTile(icon: .weight, tint: LumeColor.fat, value: String(format: "%.1f kg", current), label: "Poids actuel")
                    }.buttonStyle(.lumePress)
                    StatTile(icon: .progress, tint: delta <= 0 ? LumeColor.success : LumeColor.protein,
                             value: String(format: "%+.1f kg", delta), label: "Variation")
                }
                .lumeEntrance(0)
                HStack(spacing: Spacing.md) {
                    StatTile(icon: .calories, tint: LumeColor.carbs, value: "\(avgKcal)", label: "Moy. kcal / jour")
                    Button { if streak > 0 { showStreak = true } } label: {
                        StatTile(icon: .streak, tint: LumeColor.protein, value: streak > 0 ? "\(streak) j" : "—", label: "Série en cours")
                    }.buttonStyle(.lumePress)
                }
                .lumeEntrance(1)
                weeklyGoalsCard.lumeEntrance(2)
                weightCard.lumeEntrance(3)
                caloriesCard.lumeEntrance(4)
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

    private var weightCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Poids").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                Chart(weights) { e in
                    AreaMark(x: .value("Date", e.date), y: .value("kg", e.kg))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [LumeColor.ink.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Date", e.date), y: .value("kg", e.kg))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LumeColor.ink).lineStyle(.init(lineWidth: 2.5))
                }
                .chartYScale(domain: weightDomain)
                .chartXAxis(.hidden)
                .frame(height: 170)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var caloriesCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Calories cette semaine").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                Chart(week) { d in
                    BarMark(x: .value("Jour", d.label), y: .value("kcal", d.kcal), width: .fixed(22))
                        .foregroundStyle(d.kcal == 0 ? LumeColor.faint : LumeColor.ink)
                        .cornerRadius(6)
                }
                .chartYAxis(.hidden)
                .frame(height: 150)
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
