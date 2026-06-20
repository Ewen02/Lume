import SwiftUI

enum MealType: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String {
        rawValue
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
