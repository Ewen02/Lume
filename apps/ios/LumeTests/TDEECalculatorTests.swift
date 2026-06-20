import Testing
@testable import Lume

struct TDEECalculatorTests {
    private func profile(sex: Sex = .male, activity: ActivityLevel = .moderate, goal: Goal = .maintain) -> UserProfile {
        UserProfile(name: "Test", sex: sex, age: 24, heightCm: 178, weightKg: 74, activity: activity, goal: goal)
    }

    @Test func bmrMale() { #expect(abs(TDEECalculator.bmr(profile()) - 1737.5) < 0.001) }
    @Test func tdeeModerate() { #expect(TDEECalculator.tdee(profile()) == 2693) }
    @Test func tdeeSedentary() { #expect(TDEECalculator.tdee(profile(activity: .sedentary)) == 2085) }
    @Test func targetMaintain() {
        #expect(TDEECalculator.target(profile()) == Macros(kcal: 2693, protein: 133, carbs: 389, fat: 67))
    }
    @Test func targetLoseAppliesDelta() {
        let t = TDEECalculator.target(profile(goal: .lose))
        #expect(t.kcal == 2293)
        #expect(t.protein == 133)
        #expect(t.fat == 67)
        #expect(t.carbs == 289)
    }
    @Test func femaleBranch() { #expect(abs(TDEECalculator.bmr(profile(sex: .female)) - 1571.5) < 0.001) }
}
