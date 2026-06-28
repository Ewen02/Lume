import Foundation
import SwiftData

/// Recette réutilisable : un plat composé de plusieurs aliments (ex. « Bowl protéiné »). Persistée +
/// CloudKit. Logguer la recette insère ses ingrédients comme un repas groupé dans le journal.
/// Contraintes CloudKit : toutes les propriétés ont une valeur par défaut, relations optionnelles,
/// aucune contrainte `.unique`.
@Model
final class RecipeModel {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredientModel.recipe)
    var ingredients: [RecipeIngredientModel]? = []

    init(name: String, createdAt: Date = Date()) {
        self.name = name
        self.createdAt = createdAt
    }

    var orderedIngredients: [RecipeIngredientModel] {
        (ingredients ?? []).sorted { $0.order < $1.order }
    }

    /// Macros totales de la recette (somme des ingrédients à leur portion respective).
    var totalMacros: Macros {
        orderedIngredients.reduce(.zero) { $0 + $1.macros }
    }
}

@Model
final class RecipeIngredientModel {
    var id: UUID = UUID()
    var name: String = ""
    var grams: Int = 0
    /// Macros pour 100 g (base de référence stable, conservée même si l'aliment source disparaît).
    var kcal: Int = 0
    var protein: Int = 0
    var carbs: Int = 0
    var fat: Int = 0
    var order: Int = 0

    var recipe: RecipeModel?

    init(name: String, grams: Int, per100g: Macros, order: Int = 0) {
        self.name = name
        self.grams = grams
        kcal = per100g.kcal; protein = per100g.protein; carbs = per100g.carbs; fat = per100g.fat
        self.order = order
    }

    var per100g: Macros {
        Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }

    /// Macros de l'ingrédient à sa portion réelle (`grams`).
    var macros: Macros {
        per100g.scaled(Double(grams) / 100)
    }
}
