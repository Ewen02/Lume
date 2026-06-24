import Foundation
import Testing
@testable import Lume

struct WeightMergeTests {
    private let cal = Calendar(identifier: .gregorian)
    private let ref = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(_ dayOffset: Int, kg: Double, hour: Int = 8) -> WeightEntry {
        let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: ref))!
        let date = cal.date(byAdding: .hour, value: hour, to: day)!
        return WeightEntry(date: date, kg: kg)
    }

    @Test func mergeKeepsAllDistinctDays() {
        let hk = [entry(-2, kg: 80)]
        let local = [entry(-1, kg: 79), entry(0, kg: 78)]
        let merged = WeightMerge.merge(healthKit: hk, local: local, calendar: cal)
        #expect(merged.count == 3) // aucun point perdu (le bug XOR perdait les locaux)
        #expect(merged.map(\.kg) == [80, 79, 78]) // trié par date asc
    }

    @Test func healthKitWinsOnSameDayConflict() {
        let hk = [entry(0, kg: 75, hour: 7)]
        let local = [entry(0, kg: 99, hour: 20)] // même jour, valeur différente
        let merged = WeightMerge.merge(healthKit: hk, local: local, calendar: cal)
        #expect(merged.count == 1)
        #expect(merged.first?.kg == 75) // HealthKit prioritaire
    }

    @Test func mergeDeduplicatesLocalSameDay() {
        // Deux pesées locales le même jour (seed + saisie) → 1 seul point.
        let local = [entry(0, kg: 74, hour: 8), entry(0, kg: 73, hour: 20)]
        let merged = WeightMerge.merge(healthKit: [], local: local, calendar: cal)
        #expect(merged.count == 1)
    }

    @Test func emptySourcesGiveEmpty() {
        #expect(WeightMerge.merge(healthKit: [], local: [], calendar: cal).isEmpty)
    }
}
