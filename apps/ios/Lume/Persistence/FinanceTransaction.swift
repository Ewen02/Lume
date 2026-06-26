import Foundation
import SwiftData

/// Une transaction financière (dépense ou revenu). Montant **toujours positif** en centimes ;
/// le sens vient de `kindRaw`. CloudKit-safe : toutes les props ont un défaut, aucune `.unique`.
@Model
final class FinanceTransaction: Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var amountCents: Int = 0
    var kindRaw: String = TransactionKind.expense.rawValue
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var note: String = ""
    /// Si générée par une récurrente : lien (par UUID, pas par relation obligatoire) vers la règle source.
    var recurringID: UUID?

    init(date: Date = Date(), amountCents: Int = 0,
         kind: TransactionKind = .expense, category: ExpenseCategory = .other,
         note: String = "", recurringID: UUID? = nil)
    {
        self.date = date
        self.amountCents = max(0, amountCents)
        kindRaw = kind.rawValue
        categoryRaw = category.rawValue
        self.note = note
        self.recurringID = recurringID
    }

    var kind: TransactionKind {
        TransactionKind(rawValue: kindRaw) ?? .expense
    }

    var category: ExpenseCategory {
        ExpenseCategory(rawValue: categoryRaw) ?? .other
    }

    /// Montant signé en centimes (revenu positif, dépense négative) — pour solde/affichage.
    var signedCents: Int {
        kind == .income ? amountCents : -amountCents
    }

    /// Vue plate pour la logique pure (`FinanceCalculator`).
    var data: TransactionData {
        TransactionData(date: date, kind: kind, category: category, amountCents: amountCents)
    }
}
