import Foundation
import Testing
@testable import Lume

struct EnergyBudgetTests {
    private let profile = UserProfile(name: "T", sex: .male, age: 30, heightCm: 180,
                                      weightKg: 80, activity: .moderate, goal: .maintain)

    @Test func fixedTargetWhenHealthUnauthorized() {
        // Pas d'accès Santé → cible = TDEE classique (avec facteur d'activité).
        let kcal = EnergyBudget.targetKcal(profile, activeKcal: 500, healthAuthorized: false)
        #expect(kcal == TDEECalculator.target(profile).kcal)
    }

    @Test func fixedTargetWhenNoActiveData() {
        // Autorisé mais aucune donnée d'activité → fallback TDEE fixe.
        let kcal = EnergyBudget.targetKcal(profile, activeKcal: nil, healthAuthorized: true)
        #expect(kcal == TDEECalculator.target(profile).kcal)
    }

    @Test func dynamicTargetIsRestingPlusActive() {
        // Mode dynamique : cible = restingTarget (BMR) + calories actives réelles.
        let active = 450
        let kcal = EnergyBudget.targetKcal(profile, activeKcal: active, healthAuthorized: true)
        #expect(kcal == TDEECalculator.restingTarget(profile).kcal + active)
    }

    @Test func restingTargetIsLowerThanTdeeTarget() {
        // La cible de repos (BMR) doit être < cible TDEE (BMR × facteur) pour activité > sédentaire.
        #expect(TDEECalculator.restingTarget(profile).kcal < TDEECalculator.target(profile).kcal)
    }

    @Test func dynamicNeverDoubleCountsActivity() {
        // Avec une activité réelle modérée, la cible dynamique reste proche du TDEE (pas 2× l'activité).
        // Concrètement : restingTarget + active ne dépasse pas restingTarget + (TDEE - resting) * 2.
        let active = 300
        let dyn = EnergyBudget.targetKcal(profile, activeKcal: active, healthAuthorized: true)
        let resting = TDEECalculator.restingTarget(profile).kcal
        #expect(dyn == resting + active) // base BMR, pas base TDEE → pas de double-comptage
    }

    @Test func isDynamicReflectsConditions() {
        #expect(EnergyBudget.isDynamic(activeKcal: 100, healthAuthorized: true) == true)
        #expect(EnergyBudget.isDynamic(activeKcal: nil, healthAuthorized: true) == false)
        #expect(EnergyBudget.isDynamic(activeKcal: 100, healthAuthorized: false) == false)
    }
}
