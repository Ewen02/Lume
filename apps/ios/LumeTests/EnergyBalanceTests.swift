import Foundation
import Testing
@testable import Lume

struct EnergyBalanceTests {
    private let cal = Calendar(identifier: .gregorian)
    private let ref = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: ref))!
    }

    @Test func expendedIsBmrPlusActive() {
        let consumed = [DayValue(date: day(0), value: 2200)]
        let active = [DayValue(date: day(0), value: 400)]
        let s = EnergyBalance.series(consumed: consumed, activeEnergy: active, bmr: 1600, calendar: cal)
        #expect(s.count == 1)
        #expect(s[0].expended == 2000) // 1600 + 400
        #expect(s[0].net == 200) // 2200 consommé − 2000 dépensé = surplus
    }

    @Test func fallbackToBmrWhenNoActive() {
        // Sans données Santé : la dépense se réduit au BMR.
        let consumed = [DayValue(date: day(0), value: 1500)]
        let s = EnergyBalance.series(consumed: consumed, activeEnergy: [], bmr: 1600, calendar: cal)
        #expect(s[0].expended == 1600)
        #expect(s[0].net == -100) // déficit
    }

    @Test func joinsByDateNotByIndex() {
        // L'énergie active d'un autre jour ne doit pas se mélanger.
        let consumed = [DayValue(date: day(-1), value: 2000), DayValue(date: day(0), value: 2500)]
        let active = [DayValue(date: day(0), value: 500)] // seulement aujourd'hui
        let s = EnergyBalance.series(consumed: consumed, activeEnergy: active, bmr: 1500, calendar: cal)
        #expect(s[0].expended == 1500) // hier : BMR seul
        #expect(s[1].expended == 2000) // aujourd'hui : BMR + 500
    }

    @Test func averageNetIgnoresEmptyDays() {
        let s = [
            DayBalance(date: day(-1), consumed: 2000, expended: 1800), // net +200
            DayBalance(date: day(0), consumed: 1600, expended: 1800), // net −200
            DayBalance(date: day(1), consumed: 0, expended: 0), // jour vide ignoré
        ]
        #expect(EnergyBalance.averageNet(s) == 0) // (+200 −200) / 2
    }
}
