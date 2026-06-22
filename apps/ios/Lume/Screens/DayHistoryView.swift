import SwiftData
import SwiftUI

/// Historique d'un jour passé : mêmes cartes qu'« Aujourd'hui » (calories, macros, repas),
/// en lecture seule. Ouvert en tapant un jour de la semaine sur TodayView.
struct DayHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var foods: [LoggedFood]
    @Query private var profiles: [ProfileRecord]

    private let day: Date
    private let cal = Calendar.current

    init(day: Date) {
        self.day = day
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        _foods = Query(filter: #Predicate<LoggedFood> { $0.date >= start && $0.date < end },
                       sort: \LoggedFood.date, order: .forward)
    }

    private var target: Macros {
        profiles.first.map { TDEECalculator.target($0.profile) } ?? Mock.target
    }

    private var consumed: Macros {
        foods.reduce(.zero) { $0 + $1.macros }
    }

    /// Repas du jour groupés par scan (mealGroupID) ou par créneau (ajouts isolés).
    private var groups: [(title: String, icon: AppIcon, tint: Color, foods: [LoggedFood])] {
        var out: [(String, AppIcon, Color, [LoggedFood])] = []
        var seen = Set<UUID>()
        for food in foods {
            guard let gid = food.mealGroupID, !seen.contains(gid) else { continue }
            seen.insert(gid)
            let items = foods.filter { $0.mealGroupID == gid }
            let type = items.first?.meal ?? .snack
            out.append((items.first?.mealTitle ?? "Repas scanné · \(type.title)", .camera, type.tint, items))
        }
        for type in MealType.allCases {
            let items = foods.filter { $0.meal == type && $0.mealGroupID == nil }
            if !items.isEmpty { out.append((type.title, type.icon, type.tint, items)) }
        }
        return out
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                CalorieCard(consumed: consumed.kcal, goal: target.kcal).lumeEntrance(0)
                HStack(spacing: Spacing.md) {
                    MacroCard(letter: "P", value: consumed.protein, goal: target.protein, color: LumeColor.protein, label: "Protéines")
                    MacroCard(letter: "G", value: consumed.carbs, goal: target.carbs, color: LumeColor.carbs, label: "Glucides")
                    MacroCard(letter: "L", value: consumed.fat, goal: target.fat, color: LumeColor.fat, label: "Lipides")
                }
                .lumeEntrance(1)
                SectionHeader(title: "Repas").lumeEntrance(2)
                if groups.isEmpty {
                    LumeEmptyState(icon: .camera, title: "Aucun repas ce jour-là",
                                   message: "Rien n'a été enregistré le \(Self.dayLabel(day)).")
                        .lumeEntrance(3)
                } else {
                    ForEach(Array(groups.enumerated()), id: \.offset) { idx, g in
                        mealGroup(g).lumeEntrance(3 + idx)
                    }
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 2) {
                TopBar(title: "Historique", leading: .back, onLeading: { dismiss() })
                Text(Self.dayLabel(day).capitalized).font(.lumeDisplay).foregroundStyle(LumeColor.ink)
            }
            .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }

    private func mealGroup(_ g: (title: String, icon: AppIcon, tint: Color, foods: [LoggedFood])) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(appIcon: g.icon).lumeIcon(15, weight: .semibold).foregroundStyle(g.tint)
                Text(g.title).font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).lineLimit(1)
                Spacer()
                Text("\(g.foods.reduce(0) { $0 + $1.kcal }) kcal")
                    .font(.lumeFootnote.weight(.semibold)).foregroundStyle(LumeColor.muted).monospacedDigit()
            }
            .padding(.horizontal, Spacing.xs)
            ForEach(g.foods) { food in
                FoodRow(name: food.name,
                        detail: "\(food.grams) g · P \(food.protein) G \(food.carbs) L \(food.fat)",
                        kcal: food.kcal, trailing: .forward)
            }
        }
    }

    static func dayLabel(_ date: Date) -> String {
        Formatters.dayMonthFR.string(from: date)
    }
}

#Preview { DayHistoryView(day: Date()).modelContainer(LumeStore.preview) }
