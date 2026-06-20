import Testing
@testable import Lume

struct OneRepMaxTests {
    @Test func singleRepReturnsWeight() {
        #expect(abs(OneRepMax.epley(weight: 100, reps: 1) - 100) < 0.001)
        #expect(abs(OneRepMax.brzycki(weight: 100, reps: 1) - 100) < 0.001)
        #expect(OneRepMax.estimate(weight: 100, reps: 1) == 100)
    }
    @Test func estimateAveragesFormulas() { #expect(OneRepMax.estimate(weight: 100, reps: 5) == 115) }
    @Test func estimateHigherReps() { #expect(OneRepMax.estimate(weight: 60, reps: 12) == 85) }
}
