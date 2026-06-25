import Testing
@testable import Lume

struct TDEECalculatorTests {
    private func profile(sex: Sex = .male, activity: ActivityLevel = .moderate, goal: Goal = .maintain,
                         age: Int = 24, heightCm: Int = 178, weightKg: Double = 74) -> UserProfile {
        UserProfile(name: "Test", sex: sex, age: age, heightCm: heightCm, weightKg: weightKg,
                    activity: activity, goal: goal)
    }

    // MARK: BMR / TDEE (Mifflin–St Jeor, inchangé)

    @Test func bmrMale() { #expect(abs(TDEECalculator.bmr(profile()) - 1737.5) < 0.001) }
    @Test func femaleBranch() { #expect(abs(TDEECalculator.bmr(profile(sex: .female)) - 1571.5) < 0.001) }
    @Test func tdeeModerate() { #expect(TDEECalculator.tdee(profile()) == 2693) }
    @Test func tdeeSedentary() { #expect(TDEECalculator.tdee(profile(activity: .sedentary)) == 2085) }

    // MARK: Objectif en % du TDEE

    @Test func maintainIsTdee() {
        #expect(TDEECalculator.targetKcal(profile(goal: .maintain)) == 2693)
    }
    @Test func loseApplies15PercentDeficit() {
        // 2693 × 0.85 = 2289.05 → 2289
        #expect(TDEECalculator.targetKcal(profile(goal: .lose)) == 2289)
    }
    @Test func gainApplies10PercentSurplus() {
        // 2693 × 1.10 = 2962.3 → 2962
        #expect(TDEECalculator.targetKcal(profile(goal: .gain)) == 2962)
    }

    // MARK: Répartition macros (protéines modulées par objectif)

    @Test func maintainMacros() {
        // protéines 1.6·74 = 118 ; lipides 0.9·74 = 67 ; glucides = reste
        let t = TDEECalculator.target(profile(goal: .maintain))
        #expect(t.kcal == 2693)
        #expect(t.protein == 118)
        #expect(t.fat == 67)
        #expect(t.carbs == 404)
    }
    @Test func loseRaisesProtein() {
        // sèche : 2.0·74 = 148 g de protéines
        let t = TDEECalculator.target(profile(goal: .lose))
        #expect(t.kcal == 2289)
        #expect(t.protein == 148)
        #expect(t.fat == 67)
        #expect(t.carbs == 273)
    }
    @Test func gainProtein() {
        // prise : 1.8·74 = 133 g
        #expect(TDEECalculator.target(profile(goal: .gain)).protein == 133)
    }

    // MARK: Plancher de sécurité

    @Test func targetNeverBelowFloor() {
        // Petit gabarit en déficit : la cible ne descend jamais sous max(BMR, 1500/1200).
        let p = profile(sex: .female, activity: .sedentary, goal: .lose, age: 30, heightCm: 160, weightKg: 50)
        let bmr = Int(TDEECalculator.bmr(p).rounded())
        let floor = max(bmr, 1200)
        #expect(TDEECalculator.targetKcal(p) >= floor)
    }

    // MARK: Glucides garantis sur enveloppe serrée

    @Test func carbsStayPositiveOnTightBudget() {
        // Enveloppe volontairement basse : glucides > 0, lipides au plancher, pas de répartition absurde.
        let p = profile(sex: .female, goal: .lose, age: 30, heightCm: 160, weightKg: 50)
        let m = TDEECalculator.macros(forKcal: 1000, profile: p)
        #expect(m.protein == 100)        // 2.0·50
        #expect(m.fat >= 30)             // jamais sous 0.6·50
        #expect(m.carbs > 0)             // jamais nuls
    }

    // MARK: Avertissement de rythme

    @Test func maintainHasNoWarning() {
        #expect(TDEECalculator.objectiveWarning(profile(goal: .maintain)) == nil)
    }
    @Test func mildDeficitHasNoWarning() {
        // −15 % d'un TDEE modéré reste sous 1 %/sem → pas d'alerte (le −15 % est sûr par construction).
        #expect(TDEECalculator.objectiveWarning(profile(goal: .lose)) == nil)
    }
    @Test func weeklyRateMatchesDeficit() {
        // Vitesse = (cible − TDEE)·7 / 7700. Lose 74 kg modéré : déficit 2289−2693 = −404 kcal/j.
        let rate = TDEECalculator.weeklyWeightChangeKg(profile(goal: .lose))
        #expect(abs(rate - (-404.0 * 7 / 7700)) < 0.001)
        #expect(rate < 0) // perte → variation négative
    }

    // MARK: Cible de repos (base du bilan dynamique)

    @Test func restingTargetIsBmrAdjustedNoFloor() {
        // restingTarget = BMR × facteur objectif, sans plancher (l'activité est rajoutée par EnergyBudget).
        let p = profile(goal: .lose)
        let expected = TDEECalculator.macros(forKcal: Int((TDEECalculator.bmr(p) * Goal.lose.tdeeFactor).rounded()), profile: p)
        #expect(TDEECalculator.restingTarget(p) == expected)
    }
    @Test func restingTargetBelowFullTarget() {
        // Pour une activité > sédentaire, la base de repos est sous la cible affichée.
        #expect(TDEECalculator.restingTarget(profile()).kcal < TDEECalculator.target(profile()).kcal)
    }
}
