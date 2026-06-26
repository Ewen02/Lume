import Testing
@testable import Lume

struct BudgetPlannerTests {
    @Test func annualToMonthlyDividesBy12() {
        // 30 000 € / an → 2 500 €/mois (3_000_000 centimes → 250_000).
        #expect(BudgetPlanner.monthly(fromAnnual: 3_000_000) == 250_000)
    }

    @Test func annualToMonthlyRoundsToCent() {
        // 10 000 € / an → 833,33 €/mois → 83333 centimes (arrondi).
        #expect(BudgetPlanner.monthly(fromAnnual: 1_000_000) == 83_333)
    }

    @Test func monthlyToAnnualMultipliesBy12() {
        #expect(BudgetPlanner.annual(fromMonthly: 250_000) == 3_000_000)
    }

    @Test func resteAVivreSubtractsFixed() {
        // 2 500 € − 880 € de fixes = 1 620 €.
        #expect(BudgetPlanner.resteAVivre(monthlyIncomeCents: 250_000, fixedMonthlyCents: 88_000) == 162_000)
    }

    @Test func resteAVivreCanBeNegative() {
        // Fixes > revenus → négatif (l'UI plafonne l'affichage du budget à 0 mais alerte).
        #expect(BudgetPlanner.resteAVivre(monthlyIncomeCents: 100_000, fixedMonthlyCents: 120_000) == -20_000)
    }

    @Test func variableBudgetDeductsFixesAndSavings() {
        // Modèle enveloppe : budget = revenu − loyer − charges − épargne (jamais négatif).
        let p = FinanceProfile(monthlyNetIncomeCents: 250_000, rentCents: 80_000,
                               fixedChargesCents: 20_000, monthlySavingCents: 30_000)
        #expect(p.variableBudgetCents == 120_000) // 2500 − 800 − 200 − 300 = 1200
    }

    @Test func variableBudgetFlooredAtZero() {
        let p = FinanceProfile(monthlyNetIncomeCents: 100_000, rentCents: 90_000,
                               fixedChargesCents: 30_000, monthlySavingCents: 0)
        #expect(p.variableBudgetCents == 0) // dépenses fixes > revenu → plancher 0
    }

    @Test func suggestedRentIs30Percent() {
        // 2 500 € × 30 % = 750 €.
        #expect(BudgetPlanner.suggestedRent(monthlyIncomeCents: 250_000) == 75_000)
        #expect(BudgetPlanner.suggestedRent(monthlyIncomeCents: 0) == 0)
    }

    @Test func suggestedSavingIs20Percent() {
        // 2 500 € × 20 % = 500 €.
        #expect(BudgetPlanner.suggestedSaving(monthlyIncomeCents: 250_000) == 50_000)
        #expect(BudgetPlanner.suggestedSaving(monthlyIncomeCents: -10) == 0) // planché à 0
    }
}
