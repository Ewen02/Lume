import Foundation
import Testing
@testable import Lume

struct StreakCalculatorTests {
    private let cal = Calendar(identifier: .gregorian)
    /// Référence fixe pour des tests déterministes (pas de `Date()`).
    private let ref = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 ~22:13 UTC

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: ref))!
    }

    @Test func emptyIsZero() {
        #expect(StreakCalculator.currentStreak(from: [], reference: ref, calendar: cal) == 0)
    }

    @Test func todayOnlyIsOne() {
        #expect(StreakCalculator.currentStreak(from: [day(0)], reference: ref, calendar: cal) == 1)
    }

    @Test func consecutiveDaysCount() {
        let dates = [day(0), day(-1), day(-2), day(-3)]
        #expect(StreakCalculator.currentStreak(from: dates, reference: ref, calendar: cal) == 4)
    }

    @Test func multipleMealsSameDayCountOnce() {
        // 3 repas aujourd'hui + 1 hier = streak de 2, pas 4.
        let dates = [day(0), day(0), day(0), day(-1)]
        #expect(StreakCalculator.currentStreak(from: dates, reference: ref, calendar: cal) == 2)
    }

    @Test func gapBreaksStreak() {
        // Aujourd'hui + avant-hier (trou hier) → streak de 1.
        let dates = [day(0), day(-2), day(-3)]
        #expect(StreakCalculator.currentStreak(from: dates, reference: ref, calendar: cal) == 1)
    }

    @Test func yesterdayToleranceKeepsStreakAlive() {
        // Pas de repas aujourd'hui mais hier + avant-hier → streak de 2 (journée pas finie).
        let dates = [day(-1), day(-2)]
        #expect(StreakCalculator.currentStreak(from: dates, reference: ref, calendar: cal) == 2)
    }

    @Test func staleStreakIsZero() {
        // Dernier repas il y a 2 jours → série rompue.
        let dates = [day(-2), day(-3), day(-4)]
        #expect(StreakCalculator.currentStreak(from: dates, reference: ref, calendar: cal) == 0)
    }

    @Test func unorderedDatesHandled() {
        let dates = [day(-2), day(0), day(-3), day(-1)]
        #expect(StreakCalculator.currentStreak(from: dates, reference: ref, calendar: cal) == 4)
    }
}
