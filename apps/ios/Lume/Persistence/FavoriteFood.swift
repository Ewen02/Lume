import Foundation
import SwiftData

/// Aliment épinglé en favori (macros pour 100 g). Persistant, synchronisé CloudKit.
/// Toutes les propriétés ont une valeur par défaut (contrainte CloudKit).
@Model
final class FavoriteFood: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var addedAt: Date = Date()
    /// Macros pour 100 g (base de référence pour recalculer une portion).
    var kcal: Int = 0
    var protein: Int = 0
    var carbs: Int = 0
    var fat: Int = 0

    init(name: String, per100g: Macros, addedAt: Date = Date()) {
        self.name = name
        self.addedAt = addedAt
        kcal = per100g.kcal; protein = per100g.protein; carbs = per100g.carbs; fat = per100g.fat
    }

    var per100g: Macros {
        Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }
}
