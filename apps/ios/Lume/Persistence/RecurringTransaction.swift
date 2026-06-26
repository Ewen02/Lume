import Foundation
import SwiftData

/// Modèle d'une transaction récurrente (loyer, abonnement, salaire). À chaque ouverture de
/// l'écran Argent, `RecurrenceEngine` matérialise les occurrences dues en `FinanceTransaction` réelles.
/// CloudKit-safe : tous défauts, aucune `.unique`, aucune relation obligatoire.
@Model
final class RecurringTransaction: Identifiable {
    var id: UUID = UUID()
    var label: String = ""
    var amountCents: Int = 0
    var kindRaw: String = TransactionKind.expense.rawValue
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var frequencyRaw: String = RecurrenceFrequency.monthly.rawValue
    var dayOfMonth: Int = 1 // 1...31, clampé au dernier jour réel à la matérialisation
    var startDate: Date = Date()
    var isActive: Bool = true
    /// Curseur d'idempotence : dernière occurrence matérialisée (nil = jamais).
    var lastMaterializedDate: Date?

    init(label: String = "", amountCents: Int = 0,
         kind: TransactionKind = .expense, category: ExpenseCategory = .other,
         frequency: RecurrenceFrequency = .monthly, dayOfMonth: Int = 1,
         startDate: Date = Date(), isActive: Bool = true)
    {
        self.label = label
        self.amountCents = max(0, amountCents)
        kindRaw = kind.rawValue
        categoryRaw = category.rawValue
        frequencyRaw = frequency.rawValue
        self.dayOfMonth = min(31, max(1, dayOfMonth))
        self.startDate = startDate
        self.isActive = isActive
    }

    var kind: TransactionKind {
        TransactionKind(rawValue: kindRaw) ?? .expense
    }

    var category: ExpenseCategory {
        ExpenseCategory(rawValue: categoryRaw) ?? .other
    }

    var frequency: RecurrenceFrequency {
        RecurrenceFrequency(rawValue: frequencyRaw) ?? .monthly
    }

    var rule: RecurrenceData {
        RecurrenceData(frequency: frequency, dayOfMonth: dayOfMonth,
                       startDate: startDate, lastMaterialized: lastMaterializedDate)
    }
}
