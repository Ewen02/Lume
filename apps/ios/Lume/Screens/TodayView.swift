import SwiftData
import SwiftUI

struct TodayView: View {
    @Query private var allFoods: [LoggedFood] // borné aux 7 derniers jours
    @Query private var waterLogs: [WaterLog] // borné au jour courant
    @Query private var profiles: [ProfileRecord]
    /// Léger : sert uniquement au calcul du streak (jours consécutifs avec repas).
    @Query(sort: \LoggedFood.date, order: .reverse) private var streakFoods: [LoggedFood]

    private let cal = Calendar.current
    @State private var showWater = false
    @State private var showSearch = false
    @State private var routeEntry: LoggedFood?
    @State private var highlight = false

    /// Change de valeur quand un repas vient d'être ajouté → déclenche l'animation de mise en valeur.
    var highlightTrigger: UUID = .init()

    init(highlightTrigger: UUID = UUID()) {
        self.highlightTrigger = highlightTrigger
        let c = Calendar.current
        let dayStart = c.startOfDay(for: Date())
        let weekStart = c.date(byAdding: .day, value: -6, to: dayStart)!
        _allFoods = Query(filter: #Predicate<LoggedFood> { $0.date >= weekStart },
                          sort: \LoggedFood.date, order: .reverse)
        _waterLogs = Query(filter: #Predicate<WaterLog> { $0.day >= dayStart }, sort: \WaterLog.day, order: .reverse)
    }

    private var target: Macros {
        profiles.first.map { TDEECalculator.target($0.profile) } ?? Mock.target
    }

    private var streak: Int {
        StreakCalculator.currentStreak(from: streakFoods.map(\.date))
    }

    private var todayFoods: [LoggedFood] {
        let start = cal.startOfDay(for: Date())
        return allFoods.filter { $0.date >= start }
    }

    private var consumed: Macros {
        todayFoods.reduce(.zero) { $0 + $1.macros }
    }

    private var water: Int {
        waterLogs.first { cal.isDate($0.day, inSameDayAs: Date()) }?.glasses ?? 0
    }

    private var week: [(String, Int, Double, Bool)] {
        let letters = ["D", "L", "M", "M", "J", "V", "S"]
        let today0 = cal.startOfDay(for: Date())
        return (0 ..< 7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today0)!
            let kcal = allFoods.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.kcal }
            let wd = cal.component(.weekday, from: day)
            return (letters[wd - 1], cal.component(.day, from: day),
                    min(1.0, Double(kcal) / Double(max(target.kcal, 1))), offset == 0)
        }
    }

    private var mealsToday: [(MealType, [LoggedFood])] {
        MealType.allCases.compactMap { type in
            let items = todayFoods.filter { $0.meal == type }
            return items.isEmpty ? nil : (type, items)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                header.lumeEntrance(0)
                HStack { ForEach(week.indices, id: \.self) { i in
                    let d = week[i]
                    DayRing(letter: d.0, day: d.1, progress: d.2, isToday: d.3)
                    if i < week.count - 1 { Spacer() }
                } }
                .lumeEntrance(1)
                CalorieCard(consumed: consumed.kcal, goal: target.kcal)
                    .scaleEffect(highlight ? 1.04 : 1)
                    .shadow(color: LumeColor.protein.opacity(highlight ? 0.45 : 0), radius: highlight ? 18 : 0)
                    .lumeEntrance(2)
                HStack(spacing: Spacing.md) {
                    MacroCard(letter: "P", value: consumed.protein, goal: target.protein, color: LumeColor.protein, label: "Protéines")
                    MacroCard(letter: "G", value: consumed.carbs, goal: target.carbs, color: LumeColor.carbs, label: "Glucides")
                    MacroCard(letter: "L", value: consumed.fat, goal: target.fat, color: LumeColor.fat, label: "Lipides")
                }
                .lumeEntrance(3)
                Button { showWater = true } label: { WaterTracker(filled: water) }
                    .buttonStyle(.lumePress)
                    .lumeEntrance(4)
                SectionHeader(title: "Repas du jour").lumeEntrance(5)
                if mealsToday.isEmpty {
                    emptyState.lumeEntrance(6)
                } else {
                    ForEach(Array(mealsToday.enumerated()), id: \.element.0) { idx, pair in
                        mealGroup(type: pair.0, foods: pair.1).lumeEntrance(6 + idx)
                    }
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, 130)
        }
        .background(LumeColor.cream)
        .onChange(of: highlightTrigger) { _, _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { highlight = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.smooth) { highlight = false }
            }
        }
        .sheet(isPresented: $showWater) { WaterDetailView() }
        .sheet(isPresented: $showSearch) { SearchView() }
        .sheet(item: $routeEntry) { FoodDetailView(entry: $0) }
    }

    /// Un repas (Petit-déj / Déjeuner / …) : en-tête avec sous-total + une ligne par aliment.
    private func mealGroup(type: MealType, foods: [LoggedFood]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(appIcon: type.icon).lumeIcon(15, weight: .semibold).foregroundStyle(type.tint)
                Text(type.title).font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink)
                Spacer()
                Text("\(foods.reduce(0) { $0 + $1.kcal }) kcal")
                    .font(.lumeFootnote.weight(.semibold)).foregroundStyle(LumeColor.muted).monospacedDigit()
            }
            .padding(.horizontal, Spacing.xs)
            ForEach(foods) { food in
                FoodRow(name: food.name,
                        detail: "\(food.grams) g · P \(food.protein) G \(food.carbs) L \(food.fat)",
                        kcal: food.kcal,
                        trailing: .forward) { routeEntry = food }
                    .onTapGesture { routeEntry = food }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateString).font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                Text("Aujourd'hui").font(.lumeDisplay).foregroundStyle(LumeColor.ink)
            }
            Spacer()
            if streak > 0 { StreakPill(days: streak) }
            Button { showSearch = true } label: {
                Image(appIcon: .search).lumeIcon(20, weight: .semibold).foregroundStyle(LumeColor.ink)
                    .frame(width: 40, height: 40).background(LumeColor.surface).clipShape(Circle()).lumeShadow(.soft)
            }.buttonStyle(.lumePress)
        }
    }

    private var emptyState: some View {
        LumeEmptyState(icon: .camera, title: "Aucun repas aujourd'hui",
                       message: "Touche + pour scanner ton premier plat")
    }

    static var dateString: String {
        Formatters.dayMonthFR.string(from: Date()).capitalized
    }
}

#Preview { TodayView().modelContainer(LumeStore.preview) }
