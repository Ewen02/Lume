import Foundation
import SwiftData

/// Une charge fixe mensuelle détaillée (assurance, internet, mutuelle…). Fait partie du modèle
/// « enveloppe » : ces charges sont DÉDUITES du budget (via `FinanceProfile.fixedChargesCents`)
/// mais ne sont PAS matérialisées en transactions. On stocke le détail (label + catégorie + montant)
/// uniquement pour pouvoir le ré-afficher fidèlement lors d'une reconfiguration (corrige la perte
/// du détail quand seul le total était mémorisé).
/// CloudKit-safe : tous défauts, aucune `.unique`, aucune relation obligatoire.
@Model
final class FixedCharge: Identifiable {
    var id: UUID = UUID()
    var label: String = ""
    var amountCents: Int = 0
    var categoryRaw: String = ExpenseCategory.subscriptions.rawValue

    init(label: String = "", amountCents: Int = 0, category: ExpenseCategory = .subscriptions) {
        self.label = label
        self.amountCents = max(0, amountCents)
        categoryRaw = category.rawValue
    }

    var category: ExpenseCategory {
        ExpenseCategory(rawValue: categoryRaw) ?? .subscriptions
    }
}
