import Charts
import SwiftData
import SwiftUI

struct ProgressDashboardView: View {
    @Environment(HealthManager.self) private var health
    @Query private var weekFoods: [LoggedFood] // borné aux 7 derniers jours
    @Query(sort: \LoggedFood.date, order: .reverse) private var allFoods: [LoggedFood]

    init() {
        let weekStart = Calendar.current.date(byAdding: .day, value: -6,
                                              to: Calendar.current.startOfDay(for: Date()))!
        _weekFoods = Query(filter: #Predicate<LoggedFood> { $0.date >= weekStart },
                           sort: \LoggedFood.date, order: .reverse)
    }

    private var weights: [WeightEntry] {
        health.weightSeries.isEmpty ? Mock.weights : health.weightSeries
    }

    /// Calories par jour sur 7 jours : repli démo seulement si aucun repas enregistré.
    private var week: [DayCalories] {
        weekFoods.isEmpty ? Mock.weekCalories : WeeklyCalories.lastSevenDays(from: weekFoods)
    }

    private var streak: Int {
        StreakCalculator.currentStreak(from: allFoods.map(\.date))
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

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.md) {
                    StatTile(icon: .weight, tint: LumeColor.fat, value: String(format: "%.1f kg", current), label: "Poids actuel")
                    StatTile(icon: .progress, tint: delta <= 0 ? LumeColor.success : LumeColor.protein,
                             value: String(format: "%+.1f kg", delta), label: "Variation")
                }
                .lumeEntrance(0)
                HStack(spacing: Spacing.md) {
                    StatTile(icon: .calories, tint: LumeColor.carbs, value: "\(avgKcal)", label: "Moy. kcal / jour")
                    StatTile(icon: .streak, tint: LumeColor.protein, value: streak > 0 ? "\(streak) j" : "—", label: "Série en cours")
                }
                .lumeEntrance(1)
                weightCard.lumeEntrance(2)
                caloriesCard.lumeEntrance(3)
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
                .chartYScale(domain: (weights.map(\.kg).min()! - 1) ... (weights.map(\.kg).max()! + 1))
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
