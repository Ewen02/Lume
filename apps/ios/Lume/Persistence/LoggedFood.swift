import Foundation
import SwiftData

/// Un aliment journalisé (entrée du journal alimentaire). Persistant, synchronisé CloudKit.
/// CloudKit impose des valeurs par défaut sur toutes les propriétés (pas de contrainte d'unicité).
@Model
final class LoggedFood: Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var mealRaw: String = MealType.lunch.rawValue
    var name: String = ""
    var grams: Int = 0
    var kcal: Int = 0
    var protein: Int = 0
    var carbs: Int = 0
    var fat: Int = 0
    /// Identifiant du repas scanné auquel cet aliment appartient (nil = ajout isolé).
    /// Les aliments d'un même scan partagent le même groupId.
    var mealGroupID: UUID?
    /// Titre du repas scanné (ex. "Nasi lemak"), porté par chaque aliment du groupe.
    var mealTitle: String?

    init(date: Date = Date(), meal: MealType, name: String, grams: Int,
         kcal: Int, protein: Int, carbs: Int, fat: Int,
         mealGroupID: UUID? = nil, mealTitle: String? = nil)
    {
        self.date = date
        mealRaw = meal.rawValue
        self.name = name
        self.grams = grams
        self.kcal = kcal; self.protein = protein; self.carbs = carbs; self.fat = fat
        self.mealGroupID = mealGroupID
        self.mealTitle = mealTitle
    }

    var meal: MealType {
        MealType(rawValue: mealRaw) ?? .snack
    }

    var macros: Macros {
        Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }
}
