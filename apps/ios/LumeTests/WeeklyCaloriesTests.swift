import Foundation
import Testing
@testable import Lume

struct WeeklyCaloriesTests {
    private let cal = Calendar(identifier: .gregorian)
    private let ref = Date(timeIntervalSince1970: 1_700_000_000)

    private func food(_ dayOffset: Int, kcal: Int) -> LoggedFood {
        let date = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: ref))!
        return LoggedFood(date: date, meal: .lunch, name: "x", grams: 100,
                          kcal: kcal, protein: 0, carbs: 0, fat: 0)
    }

    @Test func returnsSevenDays() {
        let week = WeeklyCalories.lastSevenDays(from: [], reference: ref, calendar: cal)
        #expect(week.count == 7)
        #expect(week.allSatisfy { $0.kcal == 0 })
    }

    @Test func sumsCaloriesPerDay() {
        // Aujourd'hui : 300 + 200 = 500 ; hier : 400.
        let foods = [food(0, kcal: 300), food(0, kcal: 200), food(-1, kcal: 400)]
        let week = WeeklyCalories.lastSevenDays(from: foods, reference: ref, calendar: cal)
        #expect(week.last?.kcal == 500)          // dernier = aujourd'hui
        #expect(week[week.count - 2].kcal == 400) // avant-dernier = hier
    }

    @Test func ignoresFoodsOutsideWindow() {
        // Un repas il y a 10 jours ne doit pas apparaître dans la fenêtre de 7 jours.
        let week = WeeklyCalories.lastSevenDays(from: [food(-10, kcal: 999)], reference: ref, calendar: cal)
        #expect(week.allSatisfy { $0.kcal == 0 })
    }

    @Test func averageIgnoresEmptyDays() {
        let week = [DayCalories(label: "L", kcal: 2000),
                    DayCalories(label: "M", kcal: 1000),
                    DayCalories(label: "M", kcal: 0)]
        #expect(WeeklyCalories.dailyAverage(of: week) == 1500) // (2000+1000)/2, le 0 ignoré
    }

    @Test func averageOfEmptyIsZero() {
        let week = [DayCalories(label: "L", kcal: 0), DayCalories(label: "M", kcal: 0)]
        #expect(WeeklyCalories.dailyAverage(of: week) == 0)
    }

    @Test func weekOverWeekComputesDelta() {
        // Cette semaine : 2000 kcal (aujourd'hui). Semaine dernière : 1000 (il y a 8 jours).
        let foods = [food(0, kcal: 2000), food(-8, kcal: 1000)]
        let wow = WeeklyCalories.weekOverWeek(from: foods, reference: ref, calendar: cal)
        #expect(wow.thisWeek == 2000)
        #expect(wow.lastWeek == 1000)
        #expect(wow.deltaPct == 1.0) // +100 %
    }

    @Test func weekOverWeekNilWhenNoPriorWeek() {
        // Aucune donnée la semaine précédente → deltaPct indéfini.
        let wow = WeeklyCalories.weekOverWeek(from: [food(0, kcal: 1500)], reference: ref, calendar: cal)
        #expect(wow.thisWeek == 1500)
        #expect(wow.lastWeek == 0)
        #expect(wow.deltaPct == nil)
    }

    @Test func byWeekAggregatesAndCoversEmptyWeeks() {
        // Fenêtre 30 j ; repas seulement aujourd'hui (2000) et il y a 14 j (1000).
        let start = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: ref))!
        let foods = [food(0, kcal: 2000), food(-14, kcal: 1000)]
        let weeks = WeeklyCalories.byWeek(from: foods, since: start, reference: ref, calendar: cal)
        // Au moins 4 semaines couvertes (axe continu), et les kcal max correspondent à une semaine active.
        #expect(weeks.count >= 4)
        #expect(weeks.map(\.kcal).max() == 2000)
        #expect(weeks.contains { $0.kcal == 1000 })
    }

    @Test func consumedByDayIsDatedAndCoversEmptyDays() {
        // Repas aujourd'hui (300+200=500) et il y a 2 jours (400). Fenêtre = 3 jours.
        let start = cal.date(byAdding: .day, value: -2, to: cal.startOfDay(for: ref))!
        let foods = [food(0, kcal: 300), food(0, kcal: 200), food(-2, kcal: 400)]
        let days = WeeklyCalories.consumedByDay(from: foods, since: start, reference: ref, calendar: cal)
        #expect(days.count == 3) // jours datés, fenêtre continue
        #expect(days.first?.value == 400) // J-2
        #expect(days[1].value == 0) // J-1 vide
        #expect(days.last?.value == 500) // aujourd'hui (somme)
        // Les dates sont bien ordonnées et croissantes.
        #expect(days[0].date < days[1].date && days[1].date < days[2].date)
    }
}
