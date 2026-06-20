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
}
