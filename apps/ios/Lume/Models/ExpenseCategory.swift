import SwiftUI

/// Catégories de dépenses (set fixe). Même pattern que `MealType` : la `rawValue` est une clé
/// stable persistée (jamais le label localisé), avec titre/icône/teinte dérivés.
enum ExpenseCategory: String, CaseIterable, Identifiable {
    case food, restaurant, transport, housing, groceries, health, leisure, subscriptions, shopping, salary, savings, other

    var id: String {
        rawValue
    }

    /// Catégories affichées dans les pickers de DÉPENSE (on exclut `salary` = revenu et `savings` = épargne).
    static var expenseCases: [ExpenseCategory] {
        allCases.filter { $0 != .salary && $0 != .savings }
    }

    /// Catégories pour une récurrente manuelle de DÉPENSE : on exclut en plus `housing` (le loyer est
    /// géré dans « Mon budget » et déduit du budget — le recréer ici ferait du double-comptage).
    static var manualRecurringExpenseCases: [ExpenseCategory] {
        expenseCases.filter { $0 != .housing }
    }

    var title: String {
        switch self {
        case .food: "Alimentation"
        case .restaurant: "Restaurants"
        case .transport: "Transport"
        case .housing: "Logement"
        case .groceries: "Courses / Maison"
        case .health: "Santé"
        case .leisure: "Loisirs"
        case .subscriptions: "Abonnements"
        case .shopping: "Shopping"
        case .salary: "Salaire / Revenu"
        case .savings: "Épargne"
        case .other: "Autre"
        }
    }

    var icon: AppIcon {
        switch self {
        case .food: .food
        case .restaurant: .restaurant
        case .transport: .transport
        case .housing: .housing
        case .groceries: .home
        case .health: .health
        case .leisure: .leisure
        case .subscriptions: .subscription
        case .shopping: .shopping
        case .salary: .salary
        case .savings: .savings
        case .other: .category
        }
    }

    /// Teinte mappée sur les tokens du design system (jamais de couleur en dur).
    var tint: Color {
        switch self {
        case .food: LumeColor.success
        case .restaurant: LumeColor.protein
        case .transport: LumeColor.fat
        case .housing: LumeColor.ink
        case .groceries: LumeColor.carbs
        case .health: LumeColor.negative
        case .leisure: LumeColor.warning
        case .subscriptions: LumeColor.fat
        case .shopping: LumeColor.protein
        case .salary: LumeColor.success
        case .savings: LumeColor.fat
        case .other: LumeColor.muted
        }
    }
}

/// Sens d'une transaction. Le montant est toujours stocké positif ; le signe vient d'ici.
/// `saving` (mise de côté) est distinct : ni dépense (n'entame pas le budget variable),
/// ni revenu (n'augmente pas le solde) — suivi à part pour le capital épargné.
enum TransactionKind: String, CaseIterable, Identifiable {
    case expense, income, saving
    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .expense: "Dépense"
        case .income: "Revenu"
        case .saving: "Épargne"
        }
    }

    var tint: Color {
        switch self {
        case .income: LumeColor.success
        case .saving: LumeColor.fat
        case .expense: LumeColor.ink
        }
    }
}

/// Fréquence d'une transaction récurrente.
enum RecurrenceFrequency: String, CaseIterable, Identifiable {
    case monthly, weekly
    var id: String {
        rawValue
    }

    var title: String {
        self == .monthly ? "Mensuel" : "Hebdomadaire"
    }
}
