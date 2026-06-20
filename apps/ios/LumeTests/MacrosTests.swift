import Testing
@testable import Lume

struct MacrosTests {
    @Test func zeroIsNeutral() {
        #expect(Macros.zero == Macros(kcal: 0, protein: 0, carbs: 0, fat: 0))
    }
    @Test func addition() {
        let s = Macros(kcal: 100, protein: 10, carbs: 20, fat: 5) + Macros(kcal: 50, protein: 4, carbs: 6, fat: 2)
        #expect(s == Macros(kcal: 150, protein: 14, carbs: 26, fat: 7))
    }
    @Test func scaledHalf() {
        #expect(Macros(kcal: 200, protein: 20, carbs: 10, fat: 8).scaled(0.5) == Macros(kcal: 100, protein: 10, carbs: 5, fat: 4))
    }
    @Test func scaledRoundTripPer100g() {
        let base = Macros(kcal: 260, protein: 6, carbs: 56, fat: 0).scaled(100.0 / 200.0)
        #expect(base == Macros(kcal: 130, protein: 3, carbs: 28, fat: 0))
    }
}
