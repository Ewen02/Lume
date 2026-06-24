import Foundation
import Testing
@testable import Lume

struct WeeklyMacrosTests {
    private let cal = Calendar(identifier: .gregorian)
    private let ref = Date(timeIntervalSince1970: 1_700_000_000)

    private func food(_ dayOffset: Int, p: Int, c: Int, f: Int) -> LoggedFood {
        let date = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: ref))!
        return LoggedFood(date: date, meal: .lunch, name: "x", grams: 100,
                          kcal: p * 4 + c * 4 + f * 9, protein: p, carbs: c, fat: f)
    }

    @Test func nilWhenNoFood() {
        #expect(WeeklyMacros.average(from: [], reference: ref, calendar: cal) == nil)
    }

    @Test func averagesPerActiveDay() {
        // Jour 0 : P30+P10=40 ; jour -1 : P20. Moyenne sur 2 jours actifs = 30.
        let foods = [food(0, p: 30, c: 0, f: 0), food(0, p: 10, c: 0, f: 0), food(-1, p: 20, c: 0, f: 0)]
        let avg = WeeklyMacros.average(from: foods, reference: ref, calendar: cal)
        #expect(avg?.protein == 30) // (40 + 20) / 2 jours
    }

    @Test func ignoresFoodOutsideWindow() {
        let avg = WeeklyMacros.average(from: [food(-10, p: 99, c: 0, f: 0)], reference: ref, calendar: cal)
        #expect(avg == nil) // hors fenêtre 7 j → aucun jour actif
    }
}
