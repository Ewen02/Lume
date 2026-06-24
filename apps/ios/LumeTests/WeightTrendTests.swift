import Foundation
import Testing
@testable import Lume

struct WeightTrendTests {
    private let cal = Calendar(identifier: .gregorian)
    private let ref = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(_ dayOffset: Int, kg: Double) -> WeightEntry {
        let date = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: ref))!
        return WeightEntry(date: date, kg: kg)
    }

    // MARK: smoothed

    @Test func smoothedKeepsSinglePoint() {
        let s = WeightTrend.smoothed([entry(0, kg: 75)])
        #expect(s.count == 1)
        #expect(s.first?.kg == 75)
    }

    @Test func smoothedAveragesTrailingWindow() {
        // Fenêtre glissante : chaque point = moyenne de lui-même et des précédents (max window).
        let series = [entry(-2, kg: 70), entry(-1, kg: 72), entry(0, kg: 74)]
        let s = WeightTrend.smoothed(series, window: 7)
        #expect(s[0].kg == 70)              // 70
        #expect(s[1].kg == 71)              // (70+72)/2
        #expect(s[2].kg == 72)              // (70+72+74)/3
    }

    @Test func smoothedRespectsWindowSize() {
        // window=2 : le dernier point ne moyenne que les 2 derniers.
        let series = [entry(-2, kg: 60), entry(-1, kg: 80), entry(0, kg: 100)]
        let s = WeightTrend.smoothed(series, window: 2)
        #expect(s[2].kg == 90)              // (80+100)/2, pas (60+80+100)/3
    }

    // MARK: movingAverageDelta

    @Test func movingAverageDeltaNilForSinglePoint() {
        #expect(WeightTrend.movingAverageDelta([entry(0, kg: 75)]) == nil)
    }

    @Test func movingAverageDeltaIsNegativeWhenLosing() {
        // Poids descendant régulièrement sur 8 jours → delta sur 7 jours négatif.
        let series = (0 ... 8).reversed().map { entry(-$0, kg: 80 - Double(8 - $0)) }
        let delta = WeightTrend.movingAverageDelta(series, days: 7, reference: ref, calendar: cal)
        #expect(delta != nil)
        #expect((delta ?? 0) < 0)
    }

    // MARK: remainingToTarget

    @Test func remainingToTargetPositiveWhenAbove() {
        #expect(WeightTrend.remainingToTarget(current: 80, target: 75) == 5)
    }

    @Test func remainingToTargetNilWhenNoTarget() {
        #expect(WeightTrend.remainingToTarget(current: 80, target: 0) == nil)
    }

    @Test func remainingToTargetNilWhenNoCurrent() {
        #expect(WeightTrend.remainingToTarget(current: nil, target: 75) == nil)
    }

    // MARK: targetLabel (directionnel + epsilon)

    @Test func targetLabelReachedWithinEpsilon() {
        // À 0.1 kg de la cible (< epsilon 0.25) → objectif atteint, peu importe le sens.
        #expect(WeightTrend.targetLabel(current: 75.1, target: 75, goal: .lose) == "Objectif atteint")
    }

    @Test func targetLabelLoseStillAbove() {
        // Objectif perte, encore au-dessus → « Reste X kg ».
        #expect(WeightTrend.targetLabel(current: 78, target: 75, goal: .lose) == "Reste 3.0 kg")
    }

    @Test func targetLabelLoseBelowTarget() {
        // Objectif perte, passé sous la cible → distinct de « Reste ».
        #expect(WeightTrend.targetLabel(current: 73, target: 75, goal: .lose) == "2.0 kg sous l'objectif")
    }

    @Test func targetLabelGainStillBelow() {
        // Objectif prise, encore en-dessous → « Reste X kg ».
        #expect(WeightTrend.targetLabel(current: 72, target: 75, goal: .gain) == "Reste 3.0 kg")
    }

    @Test func targetLabelNilWithoutTarget() {
        #expect(WeightTrend.targetLabel(current: 75, target: 0, goal: .lose) == nil)
    }
}
