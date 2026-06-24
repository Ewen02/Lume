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

    /// Moyenne kcal/jour sur 7 j (StatTile) — indépendante de la période des graphes.
    private var avgKcal: Int {
        WeeklyCalories.dailyAverage(of: WeeklyCalories.lastSevenDays(from: weekFoods))
    }

    /// Macros moyennes (P/G/L) sur 7 j, pour les chips sous le graphe calories.
    private var weeklyMacros: Macros? {
        WeeklyMacros.average(from: weekFoods)
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
                                 value: allWeights.isEmpty ? "—" : String(format: "%.1f kg", current),
                                 label: "Poids actuel")
                    }.buttonStyle(.lumePress)
                    StatTile(icon: .progress,
                             tint: delta.map { $0 <= 0 ? LumeColor.success : LumeColor.protein } ?? LumeColor.muted,
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
                periodPicker.lumeEntrance(3)
                weightCard.lumeEntrance(4)
                caloriesCard.lumeEntrance(5)
                if !sessions.isEmpty { muscleCard.lumeEntrance(6) }
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
            WeightEntryView(current: allWeights.last?.kg)
        }
        .sheet(item: $editingSample) { sample in
            WeightEntryView(editing: sample)
        }
        .sheet(item: $deletingSample) { sample in
            LumeConfirmSheet(icon: .minusCircle, tint: LumeColor.negative,
                             title: "Supprimer cette pesée ?",
                             message: "\(String(format: "%.1f kg", sample.kg)) le \(Formatters.dayMonthFR.string(from: sample.date)). Gère tes données Apple Santé depuis l'app Santé.",
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
                        GoalBar(label: "Vers l'objectif", value: String(format: "%.0f kg", targetWeightKg),
                                progress: p, tint: LumeColor.success)
                    }
                } else if weights.count == 1, let only = weights.first {
                    // Un seul point : pas de courbe (rien à interpoler), on invite à peser à nouveau.
                    VStack(spacing: Spacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(String(format: "%.1f kg", only.kg)).font(.lumeNumberL).foregroundStyle(LumeColor.ink).monospacedDigit()
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
        .chartXSelection(value: $selectedDate)
        .frame(height: 170)
        .accessibilityLabel("Évolution du poids")
        .accessibilityValue(hasWeightData ? String(format: "Actuel %.1f kilos", current) : "Aucune donnée")
        .overlay(alignment: .topLeading) { selectionLollipop }
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
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: "%.1f kg", e.kg)).font(.lumeSubhead.weight(.bold)).foregroundStyle(LumeColor.ink).monospacedDigit()
                    Text(Formatters.dayMonthFR.string(from: e.date)).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }
                if let sample = selectedSample {
                    Button { editingSample = sample } label: {
                        Image(appIcon: .edit).lumeIcon(15, weight: .semibold).foregroundStyle(LumeColor.ink)
                    }.buttonStyle(.lumePress)
                    Button { deletingSample = sample } label: {
                        Image(appIcon: .trash).lumeIcon(15, weight: .semibold).foregroundStyle(LumeColor.negative)
                    }.buttonStyle(.lumePress)
                }
            }
            .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
            .background(LumeColor.surface, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .lumeShadow(.soft)
        }
    }

    private var caloriesTitle: String {
        period.aggregatesByWeek ? "Calories / semaine" : "Calories cette semaine"
    }

    private var caloriesCard: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(caloriesTitle).font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                    Spacer()
                    // Comparaison « vs S-1 » pertinente seulement sur la vue semaine.
                    if period == .week, hasWeekData, let pct = weekComparison.deltaPct {
                        let up = pct >= 0
                        Text(String(format: "%@%.0f %% vs S-1", up ? "+" : "−", abs(pct) * 100))
                            .font(.lumeFootnote.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(up ? LumeColor.protein : LumeColor.success)
                    }
                }
                if hasWeekData {
                    Chart(week) { d in
                        BarMark(x: .value("Période", d.label), y: .value("kcal", Double(d.kcal) * chartGrow),
                                width: .fixed(period.aggregatesByWeek ? 14 : 22))
                            .foregroundStyle(d.kcal == 0 ? LumeColor.faint : LumeColor.ink)
                            .cornerRadius(6)
                    }
                    .chartYScale(domain: 0 ... Double(max(week.map(\.kcal).max() ?? 1, 1)))
                    .chartYAxis(.hidden)
                    .frame(height: 150)
                    .accessibilityLabel("Calories par \(period.aggregatesByWeek ? "semaine" : "jour")")
                    // Macros moyennes (sur 7 j) — profondeur nutritionnelle.
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
}

#Preview { ProgressDashboardView().modelContainer(LumeStore.preview).environment(HealthManager.shared) }

// MARK: - Saisie de poids

struct WeightEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(HealthManager.self) private var health
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
