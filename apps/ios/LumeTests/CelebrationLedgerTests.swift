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

    // MARK: Jalons « une fois pour toutes »

    @Test func milestoneFiresOnceThenNeverAgain() {
        // Clé unique par exécution pour ne pas polluer les UserDefaults entre runs.
        let id = "test.\(UUID().uuidString)"
        #expect(CelebrationLedger.shouldFire(id))     // jamais fêté → oui
        CelebrationLedger.markFired(id)
        #expect(!CelebrationLedger.shouldFire(id))    // gravé → plus jamais
        #expect(CelebrationLedger.hasFired(id))
        // Nettoyage pour ne pas laisser de résidu.
        UserDefaults.standard.removeObject(forKey: "lume.celebration.milestone.\(id)")
    }
}

struct StreakMilestoneTests {
    @Test func returnsHighestCrossedUnfiredThreshold() {
        // Streak de 8 j, paliers 3/7/30, aucun fêté → on remonte au plus haut atteint (7).
        let crossed = StreakMilestone.crossed(streak: 8, thresholds: [3, 7, 30], alreadyFired: { _ in false })
        #expect(crossed == 7)
    }

    @Test func skipsAlreadyFiredThresholds() {
        // 7 et 3 déjà fêtés → même à 8 j, plus rien à fêter (30 pas atteint).
        let fired: Set<Int> = [3, 7]
        let crossed = StreakMilestone.crossed(streak: 8, thresholds: [3, 7, 30], alreadyFired: { fired.contains($0) })
        #expect(crossed == nil)
    }

    @Test func nilWhenNoThresholdReached() {
        #expect(StreakMilestone.crossed(streak: 2, thresholds: [3, 7, 30], alreadyFired: { _ in false }) == nil)
    }

    @Test func firesNextThresholdAfterLowerOnesDone() {
        // 3 et 7 fêtés, on atteint 30 → on fête 30.
        let fired: Set<Int> = [3, 7]
        #expect(StreakMilestone.crossed(streak: 30, thresholds: [3, 7, 30], alreadyFired: { fired.contains($0) }) == 30)
    }

    @Test func ledgerIDIsStableAndDomainScoped() {
        #expect(StreakMilestone.ledgerID(domain: "nutrition", threshold: 7) == "streak.nutrition.7")
        #expect(StreakMilestone.ledgerID(domain: "workout", threshold: 2) == "streak.workout.2")
    }

    @Test func nutritionAndWorkoutThresholdsMatchBadges() {
        // Les paliers doivent rester alignés sur les badges nstreak_*/streak_*.
        #expect(StreakMilestone.nutrition == [3, 7, 30])
        #expect(StreakMilestone.workout == [2, 4, 12])
    }
}
