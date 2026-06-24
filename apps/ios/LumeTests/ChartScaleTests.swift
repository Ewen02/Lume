import Foundation
import Testing
@testable import Lume

struct ChartScaleTests {
    private let ref = Date(timeIntervalSince1970: 1_700_000_000)

    private func points(_ values: [Int]) -> [ChartPoint] {
        values.enumerated().map { ChartPoint(date: ref.addingTimeInterval(Double($0.offset) * 86400), value: $0.element) }
    }

    // MARK: positiveDomain

    @Test func positiveDomainStartsAtZeroWithHeadroom() {
        let d = ChartScale.positiveDomain(points([0, 1000, 2000]))
        #expect(d.lowerBound == 0)
        #expect(d.upperBound == 2200) // 2000 + 10 %
    }

    @Test func positiveDomainNeverDegenerate() {
        let d = ChartScale.positiveDomain(points([0, 0, 0]))
        #expect(d.upperBound >= 1) // pas de domaine 0...0
    }

    // MARK: symmetricDomain (net déficit/surplus)

    @Test func symmetricDomainIsCenteredOnZero() {
        // Plus grand écart absolu = 800 → bornes symétriques ±800·1.15.
        let d = ChartScale.symmetricDomain(points([-300, 800, -500]))
        #expect(d.lowerBound == -d.upperBound)
        #expect(d.upperBound > 800)
    }

    @Test func symmetricDomainAllDeficitStaysReadable() {
        // Tout déficit : l'axe reste symétrique (ne s'aplatit pas vers 0).
        let d = ChartScale.symmetricDomain(points([-200, -400, -600]))
        #expect(d.lowerBound < -600)
        #expect(d.upperBound > 0)
    }

    // MARK: barWidth

    @Test func barWidthShrinksWithMorePoints() {
        let few = ChartScale.barWidth(count: 7, available: 350)
        let many = ChartScale.barWidth(count: 90, available: 350)
        #expect(many < few) // 90 j → barres plus fines que 7 j
        #expect(many >= 3) // mais jamais des traits invisibles
        #expect(few <= 28) // ni des pavés
    }

    @Test func barWidthHandlesEmpty() {
        #expect(ChartScale.barWidth(count: 0, available: 350) == 16)
    }

    // MARK: ticks

    @Test func ticksAreRoundAndCoverDomain() {
        let ticks = ChartScale.ticks(0 ... 2200)
        #expect(ticks.first == 0)
        #expect(ticks.contains { $0 >= 2000 }) // couvre le haut
        #expect(ticks.count >= 2) // au moins quelques repères
    }
}
