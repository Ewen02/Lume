import Testing
@testable import Lume

struct PlateMathTests {
    @Test func standardLoad() {
        let side = PlateMath.perSide(target: 100)
        #expect(side == [25, 15])
        #expect(abs(side.reduce(0, +) - 40) < 0.001)
    }
    @Test func emptyBarWhenTargetAtBarWeight() {
        #expect(PlateMath.perSide(target: 20).isEmpty)
        #expect(PlateMath.perSide(target: 15).isEmpty)
    }
    @Test func fractionalPlates() { #expect(PlateMath.perSide(target: 142.5) == [25, 25, 10, 1.25]) }
    @Test func customBar() { #expect(PlateMath.perSide(target: 60, bar: 20) == [20]) }
}
