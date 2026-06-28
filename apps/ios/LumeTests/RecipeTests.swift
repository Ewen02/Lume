import Foundation
import SwiftData
import Testing
@testable import Lume

/// Agrégation des macros d'une recette (logique pure, sans container).
struct RecipeMacrosTests {
    @Test func ingredientScalesPer100gToPortion() {
        // Riz 130 kcal/100g à 200 g → 260 kcal.
        let ing = RecipeIngredientModel(name: "Riz", grams: 200,
                                        per100g: Macros(kcal: 130, protein: 3, carbs: 28, fat: 0))
        #expect(ing.macros.kcal == 260)
        #expect(ing.macros.carbs == 56)
    }

    @Test func totalMacrosSumsIngredients() {
        let recipe = RecipeModel(name: "Bowl")
        recipe.ingredients = [
            RecipeIngredientModel(name: "Poulet", grams: 150,
                                  per100g: Macros(kcal: 165, protein: 31, carbs: 0, fat: 4), order: 0),
            RecipeIngredientModel(name: "Riz", grams: 200,
                                  per100g: Macros(kcal: 130, protein: 3, carbs: 28, fat: 0), order: 1),
        ]
        let t = recipe.totalMacros
        // kcal : 165*1.5=247.5→248 + 130*2=260 = 508
        #expect(t.kcal == 508)
        // protéines : 31*1.5=46.5→47 (arrondi par ingrédient) + 3*2=6 = 53
        #expect(t.protein == 53)
    }

    @Test func orderedIngredientsRespectsOrder() {
        let recipe = RecipeModel(name: "X")
        recipe.ingredients = [
            RecipeIngredientModel(name: "B", grams: 100, per100g: .zero, order: 1),
            RecipeIngredientModel(name: "A", grams: 100, per100g: .zero, order: 0),
        ]
        #expect(recipe.orderedIngredients.map(\.name) == ["A", "B"])
    }
}

/// Journalisation d'une recette → LoggedFood groupés (avec container in-memory partagé).
@MainActor
@Suite(.serialized)
struct RecipeLoggerTests {
    private static let sharedContainer: ModelContainer = {
        let config = ModelConfiguration(schema: LumeStore.schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: LumeStore.schema, configurations: [config])
    }()

    private func freshContext() throws -> ModelContext {
        let ctx = Self.sharedContainer.mainContext
        for f in (try? ctx.fetch(FetchDescriptor<LoggedFood>())) ?? [] { ctx.delete(f) }
        try? ctx.save()
        return ctx
    }

    @Test func logExpandsRecipeIntoGroupedLoggedFoods() throws {
        let ctx = try freshContext()
        let recipe = RecipeModel(name: "Bowl protéiné")
        recipe.ingredients = [
            RecipeIngredientModel(name: "Poulet", grams: 150,
                                  per100g: Macros(kcal: 165, protein: 31, carbs: 0, fat: 4), order: 0),
            RecipeIngredientModel(name: "Riz", grams: 200,
                                  per100g: Macros(kcal: 130, protein: 3, carbs: 28, fat: 0), order: 1),
        ]
        ctx.insert(recipe)

        let count = RecipeLogger.log(recipe, meal: .lunch, into: ctx)
        #expect(count == 2)

        let logged = try ctx.fetch(FetchDescriptor<LoggedFood>())
        #expect(logged.count == 2)
        // Tous partagent le même mealGroupID (carte groupée) et le nom de la recette.
        let groups = Set(logged.compactMap(\.mealGroupID))
        #expect(groups.count == 1)
        #expect(logged.allSatisfy { $0.mealTitle == "Bowl protéiné" })
        #expect(logged.allSatisfy { $0.meal == .lunch })
        // Les portions sont correctement mises à l'échelle.
        let poulet = logged.first { $0.name == "Poulet" }
        #expect(poulet?.kcal == 248) // 165 * 1.5
    }

    @Test func loggingEmptyRecipeDoesNothing() throws {
        let ctx = try freshContext()
        let empty = RecipeModel(name: "Vide")
        ctx.insert(empty)
        let count = RecipeLogger.log(empty, into: ctx)
        #expect(count == 0)
        #expect((try ctx.fetch(FetchDescriptor<LoggedFood>())).isEmpty)
    }
}

/// Le créneau de repas par défaut suit l'heure.
struct MealForNowTests {
    private func meal(atHour h: Int) -> MealType {
        var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 28; c.hour = h
        let date = Calendar.current.date(from: c)!
        return MealType.forNow(date)
    }
    @Test func slotsByHour() {
        #expect(meal(atHour: 8) == .breakfast)
        #expect(meal(atHour: 12) == .lunch)
        #expect(meal(atHour: 20) == .dinner)
        #expect(meal(atHour: 16) == .snack)
        #expect(meal(atHour: 2) == .snack)
    }
}
