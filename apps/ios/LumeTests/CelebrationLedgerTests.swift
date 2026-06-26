import Foundation
import Testing
@testable import Lume

struct CelebrationLedgerTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func monthKeyFormat() {
        #expect(CelebrationLedger.monthKey(date(2026, 6, 15), calendar: calendar) == "2026-06")
        #expect(CelebrationLedger.monthKey(date(2026, 12, 1), calendar: calendar) == "2026-12")
    }

    @Test func celebratesWhenNeverDone() {
        #expect(CelebrationLedger.shouldCelebrate(currentMonth: "2026-06", lastCelebrated: nil))
    }

    @Test func doesNotRepeatSameMonth() {
        // Déjà fêté ce mois → ne se rejoue pas (anti-spam à chaque ouverture).
        #expect(!CelebrationLedger.shouldCelebrate(currentMonth: "2026-06", lastCelebrated: "2026-06"))
    }

    @Test func celebratesNewMonth() {
        #expect(CelebrationLedger.shouldCelebrate(currentMonth: "2026-07", lastCelebrated: "2026-06"))
    }

    @Test func doesNotBackfillPastMonth() {
        // On ne « rattrape » pas un mois passé si le curseur est déjà plus récent.
        #expect(!CelebrationLedger.shouldCelebrate(currentMonth: "2026-05", lastCelebrated: "2026-06"))
    }
}
