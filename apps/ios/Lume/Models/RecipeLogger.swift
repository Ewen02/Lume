import Foundation
import SwiftData

/// Journalise une recette : insère chacun de ses ingrédients comme un `LoggedFood`, tous reliés par
/// un même `mealGroupID` et portant le nom de la recette en `mealTitle` (carte groupée dans le
/// journal, comme un repas scanné). Séparé de l'UI pour être testable.
@MainActor
enum RecipeLogger {
    /// Insère les ingrédients de `recipe` dans le contexte pour le créneau `meal`.
    /// - Returns: le nombre d'ingrédients journalisés.
    @discardableResult
    static func log(_ recipe: RecipeModel, meal: MealType = MealType.forNow(),
                    into ctx: ModelContext, date: Date = Date()) -> Int
    {
        let ingredients = recipe.orderedIngredients
        guard !ingredients.isEmpty else { return 0 }
        let groupID = UUID()
        let title = recipe.name.trimmingCharacters(in: .whitespaces)
        for ing in ingredients {
            let m = ing.macros
            ctx.insert(LoggedFood(date: date, meal: meal, name: ing.name, grams: ing.grams,
                                  kcal: m.kcal, protein: m.protein, carbs: m.carbs, fat: m.fat,
                                  mealGroupID: groupID, mealTitle: title.isEmpty ? nil : title))
        }
        return ingredients.count
    }
}
