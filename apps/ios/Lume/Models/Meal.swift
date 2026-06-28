import SwiftUI

enum MealType: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String {
        rawValue
    }

    /// Créneau de repas par défaut selon l'heure (utilisé au moment de logger : photo, code-barres,
    /// recette…). Centralisé ici pour éviter de dupliquer la règle dans chaque écran.
    static func forNow(_ date: Date = Date(), calendar: Calendar = .current) -> MealType {
        switch calendar.component(.hour, from: date) {
        case 5 ..< 11: .breakfast
        case 11 ..< 15: .lunch
        case 18 ..< 23: .dinner
        default: .snack
        }
    }

    var title: String {
        switch self {
        case .breakfast: "Petit-déjeuner"
        case .lunch: "Déjeuner"
        case .dinner: "Dîner"
        case .snack: "Collations"
        }
    }

    var icon: AppIcon {
        switch self {
        case .breakfast: .breakfast
        case .lunch: .lunch
        case .dinner: .dinner
        case .snack: .snack
        }
    }

    var tint: Color {
        switch self {
        case .breakfast: LumeColor.carbs
        case .lunch: LumeColor.protein
        case .dinner: LumeColor.fat
        case .snack: LumeColor.success
        }
    }
}

struct Meal: Identifiable {
    let id = UUID()
    var type: MealType
    var subtitle: String
    var items: [FoodItem]
    var total: Macros {
        items.reduce(.zero) { $0 + $1.macros }
    }
}
