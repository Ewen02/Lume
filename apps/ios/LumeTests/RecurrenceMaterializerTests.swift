import Foundation
import Testing
@testable import Lume

struct RecurrenceMaterializerTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func monthlyGeneratesOnePerMonth() {
        let rule = RecurrenceData(frequency: .monthly, dayOfMonth: 2,
                                  startDate: date(2026, 1, 1), lastMaterialized: nil)
        // Jusqu'au 15 mars → échéances du 2 jan, 2 fév, 2 mars.
        let due = RecurrenceMaterializer.dueOccurrences(rule: rule, until: date(2026, 3, 15), calendar: calendar)
        #expect(due == [date(2026, 1, 2), date(2026, 2, 2), date(2026, 3, 2)])
    }

    @Test func idempotentWithCursor() {
        // Curseur au 2 février → ne renvoie que les échéances STRICTEMENT après (2 mars).
        let rule = RecurrenceData(frequency: .monthly, dayOfMonth: 2,
                                  startDate: date(2026, 1, 1), lastMaterialized: date(2026, 2, 2))
        let due = RecurrenceMaterializer.dueOccurrences(rule: rule, until: date(2026, 3, 15), calendar: calendar)
        #expect(due == [date(2026, 3, 2)])
    }

    @Test func secondRunCreatesNothing() {
        // Après matérialisation jusqu'au 2 mars, un 2e passage le même jour ne renvoie rien.
        let rule = RecurrenceData(frequency: .monthly, dayOfMonth: 2,
                                  startDate: date(2026, 1, 1), lastMaterialized: date(2026, 3, 2))
        let due = RecurrenceMaterializer.dueOccurrences(rule: rule, until: date(2026, 3, 2), calendar: calendar)
        #expect(due.isEmpty)
    }

    @Test func clampsDay31OnShortMonths() {
        // Jour 31 sur février 2026 (28 j) → clampé au 28.
        let rule = RecurrenceData(frequency: .monthly, dayOfMonth: 31,
                                  startDate: date(2026, 2, 1), lastMaterialized: nil)
        let due = RecurrenceMaterializer.dueOccurrences(rule: rule, until: date(2026, 2, 28), calendar: calendar)
        #expect(due == [date(2026, 2, 28)])
    }

    @Test func nothingBeforeStartDate() {
        let rule = RecurrenceData(frequency: .monthly, dayOfMonth: 2,
                                  startDate: date(2026, 6, 1), lastMaterialized: nil)
        let due = RecurrenceMaterializer.dueOccurrences(rule: rule, until: date(2026, 3, 15), calendar: calendar)
        #expect(due.isEmpty)
    }

    @Test func weeklyEverySevenDays() {
        let rule = RecurrenceData(frequency: .weekly, dayOfMonth: 1,
                                  startDate: date(2026, 6, 1), lastMaterialized: nil)
        let due = RecurrenceMaterializer.dueOccurrences(rule: rule, until: date(2026, 6, 22), calendar: calendar)
        #expect(due == [date(2026, 6, 1), date(2026, 6, 8), date(2026, 6, 15), date(2026, 6, 22)])
    }
}
