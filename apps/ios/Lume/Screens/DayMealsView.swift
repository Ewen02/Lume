import SwiftData
import SwiftUI

/// Repas d'un jour donné (historique). Lecture + accès au détail d'un aliment.
struct DayMealsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var foods: [LoggedFood]
    @Query private var profiles: [ProfileRecord]
    @State private var routeEntry: LoggedFood?

    private let day: Date
    private let cal = Calendar.current

    init(day: Date) {
        self.day = day
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _foods = Query(filter: #Predicate<LoggedFood> { $0.date >= start && $0.date < end },
                       sort: \LoggedFood.date)
    }

    private var consumed: Macros { foods.reduce(.zero) { $0 + $1.macros } }
    private var target: Macros { profiles.first.map { TDEECalculator.target($0.profile) } ?? Mock.target }

    /// Repas groupés par créneau (petit-déj, déj…), aliments triés.
    private var byMeal: [(type: MealType, foods: [LoggedFood])] {
        MealType.allCases.compactMap { type in
            let f = foods.filter { $0.meal == type }
            return f.isEmpty ? nil : (type, f)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                if foods.isEmpty {
                    LumeEmptyState(icon: .camera, title: "Aucun repas ce jour-là", message: nil)
                        .padding(.top, Spacing.xxl)
                } else {
                    summaryCard
                    ForEach(byMeal, id: \.type) { group in mealSection(group.type, group.foods) }
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: Formatters.dayMonthFR.string(from: day).capitalized, leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(item: $routeEntry) { FoodDetailView(entry: $0) }
    }

    private var summaryCard: some View {
        LumeCard {
            VStack(spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(consumed.kcal)").font(.lumeNumberL).foregroundStyle(LumeColor.ink).monospacedDigit()
                    Text("/ \(target.kcal) kcal").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                }
                HStack(spacing: Spacing.sm) {
                    Chip(color: LumeColor.protein, text: "P \(consumed.protein) g")
                    Chip(color: LumeColor.carbs, text: "G \(consumed.carbs) g")
                    Chip(color: LumeColor.fat, text: "L \(consumed.fat) g")
                }
            }.frame(maxWidth: .infinity)
        }
    }

    private func mealSection(_ type: MealType, _ foods: [LoggedFood]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(appIcon: type.icon).lumeIcon(15, weight: .semibold).foregroundStyle(type.tint)
                Text(foods.first?.mealTitle ?? type.title).font(.lumeSubhead.weight(.semibold))
                    .foregroundStyle(LumeColor.ink).lineLimit(1)
                Spacer()
                Text("\(foods.reduce(0) { $0 + $1.kcal }) kcal")
                    .font(.lumeFootnote.weight(.semibold)).foregroundStyle(LumeColor.muted).monospacedDigit()
            }.padding(.horizontal, Spacing.xs)
            ForEach(foods) { food in
                FoodRow(name: food.name,
                        detail: "\(food.grams) g · P \(food.protein) G \(food.carbs) L \(food.fat)",
                        kcal: food.kcal, trailing: .forward) { routeEntry = food }
            }
        }
    }
}

#Preview { DayMealsView(day: Date()).modelContainer(LumeStore.preview) }
