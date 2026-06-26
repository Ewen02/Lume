import Foundation
import Testing
@testable import Lume

struct FinanceCalculatorTests {
    // Calendrier fixe (UTC) pour des tests déterministes.
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func tx(_ y: Int, _ m: Int, _ d: Int, _ kind: TransactionKind,
                    _ cat: ExpenseCategory, _ cents: Int) -> TransactionData
    {
        TransactionData(date: date(y, m, d), kind: kind, category: cat, amountCents: cents)
    }

    private var sample: [TransactionData] {
        [
            tx(2026, 6, 1, .income, .salary, 210_000),
            tx(2026, 6, 2, .expense, .housing, 65_000),
            tx(2026, 6, 5, .expense, .groceries, 8_000),
            tx(2026, 6, 9, .expense, .groceries, 2_000),
            tx(2026, 6, 12, .expense, .restaurant, 5_000),
            tx(2026, 5, 20, .expense, .housing, 65_000), // mois précédent — ignoré pour juin
        ]
    }

    @Test func totalSpentBoundsToMonth() {
        // Juin : 65000 + 8000 + 2000 + 5000 = 80000 (le loyer de mai est exclu).
        #expect(FinanceCalculator.totalSpent(sample, in: date(2026, 6, 15), calendar: calendar) == 80_000)
    }

    @Test func totalIncomeAndBalance() {
        #expect(FinanceCalculator.totalIncome(sample, in: date(2026, 6, 15), calendar: calendar) == 210_000)
        #expect(FinanceCalculator.balance(sample, in: date(2026, 6, 15), calendar: calendar) == 130_000)
    }

    @Test func committedOutflowSumsFixedEngagements() {
        // Loyer + charges + épargne, planchés à 0 (jamais de négatif).
        #expect(FinanceCalculator.committedOutflow(rentCents: 65_000, fixedChargesCents: 11_000, savingCents: 30_000) == 106_000)
        #expect(FinanceCalculator.committedOutflow(rentCents: -10, fixedChargesCents: 0, savingCents: 0) == 0)
    }

    @Test func realBalanceDeductsCommittedEngagements() {
        // Solde brut = 130000 (revenus − dépenses variables). Engagements fixes = 106000.
        // Solde RÉEL à vivre = 130000 − 106000 = 24000 (honnête, cohérent avec l'anneau).
        let committed = FinanceCalculator.committedOutflow(rentCents: 65_000, fixedChargesCents: 11_000, savingCents: 30_000)
        #expect(FinanceCalculator.realBalance(sample, in: date(2026, 6, 15), committed: committed, calendar: calendar) == 24_000)
    }

    @Test func realBalanceFallsBackToBrutWhenNoCommitment() {
        // Mois passé (committed = 0) → realBalance == balance brut.
        #expect(FinanceCalculator.realBalance(sample, in: date(2026, 6, 15), committed: 0, calendar: calendar)
            == FinanceCalculator.balance(sample, in: date(2026, 6, 15), calendar: calendar))
    }

    @Test func spentByCategoryAggregates() {
        let byCat = FinanceCalculator.spentByCategory(sample, in: date(2026, 6, 15), calendar: calendar)
        #expect(byCat[.groceries] == 10_000) // 8000 + 2000
        #expect(byCat[.housing] == 65_000)
        #expect(byCat[.salary] == nil) // revenu non compté dans les dépenses
    }

    @Test func savingExcludedFromSpentAndIncome() {
        // Une épargne ne doit compter NI comme dépense (budget) NI comme revenu (solde).
        let tx = [
            tx(2026, 6, 1, .income, .salary, 200_000),
            tx(2026, 6, 2, .expense, .groceries, 5_000),
            tx(2026, 6, 3, .saving, .savings, 30_000),
        ]
        #expect(FinanceCalculator.totalSpent(tx, in: date(2026, 6, 15), calendar: calendar) == 5_000)
        #expect(FinanceCalculator.totalIncome(tx, in: date(2026, 6, 15), calendar: calendar) == 200_000)
        #expect(FinanceCalculator.totalSaved(tx, in: date(2026, 6, 15), calendar: calendar) == 30_000)
        // Solde = revenus − dépenses (l'épargne ne l'entame pas).
        #expect(FinanceCalculator.balance(tx, in: date(2026, 6, 15), calendar: calendar) == 195_000)
    }

    @Test func cumulativeSavedSumsAllSavings() {
        let tx = [
            tx(2026, 5, 3, .saving, .savings, 30_000),
            tx(2026, 6, 3, .saving, .savings, 30_000),
            tx(2026, 6, 4, .expense, .food, 1_000),
        ]
        #expect(FinanceCalculator.cumulativeSaved(tx) == 60_000)
    }

    @Test func budgetStatusThresholds() {
        #expect(BudgetStatus.of(spent: 5_000, budget: 10_000) == .under)
        #expect(BudgetStatus.of(spent: 9_000, budget: 10_000) == .near) // 90 %
        #expect(BudgetStatus.of(spent: 11_000, budget: 10_000) == .over)
        #expect(BudgetStatus.of(spent: 5_000, budget: 0) == .under) // pas de budget → under
    }

    @Test func progressClamped() {
        #expect(FinanceCalculator.progress(spent: 5_000, budget: 10_000) == 0.5)
        #expect(FinanceCalculator.progress(spent: 20_000, budget: 10_000) == 1) // plafonné
        #expect(FinanceCalculator.progress(spent: 100, budget: 0) == 0)
    }

    @Test func monthlySeriesLength() {
        let series = FinanceCalculator.monthlySeries(sample, months: 3, reference: date(2026, 6, 15), calendar: calendar)
        #expect(series.count == 3)
        // Le dernier point = juin = 80000 ; le précédent = mai = 65000.
        #expect(series.last?.value == 80_000)
        #expect(series[1].value == 65_000)
    }

    @Test func averagePerDayCurrentMonth() {
        // averagePerDay divise le total du MOIS (80000) par les jours écoulés (10 au 10 juin) = 8000/j.
        let avg = FinanceCalculator.averagePerDay(sample, in: date(2026, 6, 10),
                                                  reference: date(2026, 6, 10), calendar: calendar)
        #expect(avg == 8_000)
    }
}
