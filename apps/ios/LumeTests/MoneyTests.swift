import Testing
@testable import Lume

struct MoneyTests {
    @Test func composeCents() {
        #expect(Money.cents(major: 12, minor: 50) == 1250)
        #expect(Money.cents(major: 0, minor: 99) == 99)
        #expect(Money.cents(major: 5, minor: 0) == 500)
    }

    @Test func decomposeComponents() {
        let c = Money.components(1250)
        #expect(c.major == 12 && c.minor == 50)
    }

    @Test func plainDecimalForCSV() {
        #expect(Money.plainDecimal(1250) == "12.50")
        #expect(Money.plainDecimal(900) == "9.00")
    }

    @Test func parseHandlesCommaAndDot() {
        #expect(Money.parse("12,50") == 1250)
        #expect(Money.parse("12.50") == 1250)
        #expect(Money.parse("12") == 1200)
        #expect(Money.parse("  9,9 €") == 990)
    }

    @Test func parseRejectsInvalid() {
        #expect(Money.parse("") == nil)
        #expect(Money.parse("abc") == nil)
        #expect(Money.parse("-5") == nil)
    }

    @Test func parseRoundsToCent() {
        // 12,505 → 1251 centimes (arrondi, pas troncature à 1250).
        #expect(Money.parse("12,505") == 1251)
    }
}
