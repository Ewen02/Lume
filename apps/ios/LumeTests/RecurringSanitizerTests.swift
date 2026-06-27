import Foundation
import Testing
@testable import Lume

struct RecurringSanitizerTests {
    private func r(_ order: Int, _ label: String, _ cents: Int,
                   _ kind: TransactionKind, _ cat: ExpenseCategory) -> RecurringSummary
    {
        RecurringSummary(id: UUID(), label: label, amountCents: cents, kind: kind, category: cat, createdOrder: order)
    }

    @Test func incomeAndSavingAreIllegitimate() {
        // Revenu et épargne vivent dans le profil → toujours illégitimes en récurrente.
        #expect(RecurringSanitizer.isIllegitimate(r(0, "Salaire", 210_000, .income, .salary)))
        #expect(RecurringSanitizer.isIllegitimate(r(0, "Épargne", 30_000, .saving, .savings)))
    }

    @Test func housingExpenseIsIllegitimate() {
        // Le loyer (dépense housing) est géré dans « Mon budget ».
        #expect(RecurringSanitizer.isIllegitimate(r(0, "Loyer", 75_000, .expense, .housing)))
    }

    @Test func normalExpenseIsLegitimate() {
        // Un abonnement reste une récurrente valide.
        #expect(!RecurringSanitizer.isIllegitimate(r(0, "Spotify", 1_099, .expense, .subscriptions)))
    }

    @Test func removesAllIllegitimate() {
        let rules = [
            r(0, "Salaire", 210_000, .income, .salary),
            r(1, "Loyer", 75_000, .expense, .housing),
            r(2, "Spotify", 1_099, .expense, .subscriptions),
        ]
        let remove = RecurringSanitizer.idsToRemove(rules)
        // Salaire + Loyer supprimés, Spotify conservé.
        #expect(remove.count == 2)
        #expect(!remove.contains(rules[2].id))
    }

    @Test func dedupesEquivalentRulesKeepingFirst() {
        let first = r(0, "Spotify", 1_099, .expense, .subscriptions)
        let dupe = r(1, "spotify", 1_099, .expense, .subscriptions) // libellé normalisé → même clé
        let other = r(2, "Assurance", 4_000, .expense, .subscriptions)
        let remove = RecurringSanitizer.idsToRemove([first, dupe, other])
        // On garde le premier Spotify, on supprime le doublon, on garde l'assurance.
        #expect(remove.contains(dupe.id))
        #expect(!remove.contains(first.id))
        #expect(!remove.contains(other.id))
    }

    @Test func dedupeKeyNormalizesLabel() {
        let a = r(0, "  Loyer ", 75_000, .expense, .subscriptions)
        let b = r(1, "loyer", 75_000, .expense, .subscriptions)
        #expect(RecurringSanitizer.dedupeKey(a) == RecurringSanitizer.dedupeKey(b))
    }

    @Test func nothingToRemoveOnCleanSet() {
        let rules = [
            r(0, "Spotify", 1_099, .expense, .subscriptions),
            r(1, "Assurance", 4_000, .expense, .subscriptions),
            r(2, "Transport", 7_500, .expense, .transport),
        ]
        #expect(RecurringSanitizer.idsToRemove(rules).isEmpty)
    }
}
