import Foundation
import SwiftData

/// Budget mensuel (plafond de dépenses) pour une catégorie. Le budget global est stocké
/// séparément en `@AppStorage("lume.finance.globalBudgetCents")` (réglage simple, pas relationnel).
/// CloudKit-safe : tous défauts, aucune `.unique`.
@Model
final class CategoryBudget: Identifiable {
    var id: UUID = UUID()
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var monthlyLimitCents: Int = 0 // 0 = pas de budget pour cette catégorie

    init(category: ExpenseCategory = .other, monthlyLimitCents: Int = 0) {
        categoryRaw = category.rawValue
        self.monthlyLimitCents = max(0, monthlyLimitCents)
    }

    var category: ExpenseCategory {
        ExpenseCategory(rawValue: categoryRaw) ?? .other
    }
}

/// Clés et historique du budget mensuel (centimes), partagés entre l'écran Budget et les réglages.
enum FinanceSettings {
    static let globalBudgetKey = "lume.finance.globalBudgetCents"
    static let setupDoneKey = "lume.financeSetupDone"
    private static let historyKey = "lume.finance.budgetHistory" // [YYYY-MM: centimes]

    /// Mémorise le budget appliqué pour un mois donné (pour afficher un mois passé avec SON budget,
    /// pas le budget courant). Idempotent : n'écrase pas un mois déjà enregistré.
    static func recordBudget(_ cents: Int, forMonth month: Date, calendar: Calendar = .current) {
        let key = CelebrationLedger.monthKey(month, calendar: calendar)
        var history = (UserDefaults.standard.dictionary(forKey: historyKey) as? [String: Int]) ?? [:]
        if history[key] == nil {
            history[key] = cents
            UserDefaults.standard.set(history, forKey: historyKey)
        }
    }

    /// Budget enregistré pour un mois (nil si non enregistré → l'appelant retombe sur le courant).
    static func budget(forMonth month: Date, calendar: Calendar = .current) -> Int? {
        let key = CelebrationLedger.monthKey(month, calendar: calendar)
        return (UserDefaults.standard.dictionary(forKey: historyKey) as? [String: Int])?[key]
    }
}
