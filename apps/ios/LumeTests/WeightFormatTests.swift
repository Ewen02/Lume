import Foundation
import Testing
@testable import Lume

struct WeightFormatTests {
    @Test func conversionRoundTrip() {
        let kg = 80.0
        #expect(abs(WeightFormat.lbToKg(WeightFormat.kgToLb(kg)) - kg) < 0.0001)
    }

    @Test func kgToLbKnownValue() {
        #expect(abs(WeightFormat.kgToLb(100) - 220.462) < 0.01)
    }

    @Test func bodyMetric() {
        #expect(WeightFormat.body(74.5, imperial: false) == "74.5 kg")
    }

    @Test func bodyImperialConverts() {
        // 74.5 kg ≈ 164.2 lb
        #expect(WeightFormat.body(74.5, imperial: true).hasSuffix("lb"))
        #expect(WeightFormat.body(74.5, imperial: true).hasPrefix("164.2"))
    }

    @Test func deltaCarriesSign() {
        #expect(WeightFormat.bodyDelta(0.4, imperial: false) == "+0.4 kg")
        #expect(WeightFormat.bodyDelta(-1.2, imperial: false) == "-1.2 kg")
    }

    @Test func loadIsRoundedInteger() {
        // 60 kg ≈ 132 lb
        #expect(WeightFormat.load(60, imperial: false) == "60 kg")
        #expect(WeightFormat.load(60, imperial: true) == "132 lb")
    }

    @Test func stepIsHalfKiloOrOnePound() {
        #expect(WeightFormat.stepKg(imperial: false) == 0.5)
        // 1 lb ≈ 0.4536 kg
        #expect(abs(WeightFormat.stepKg(imperial: true) - 0.4536) < 0.001)
    }

    @Test func unitLabel() {
        #expect(WeightFormat.unit(imperial: false) == "kg")
        #expect(WeightFormat.unit(imperial: true) == "lb")
    }
}
