import Foundation

/// Valeurs nutritionnelles. Lume ne suit que kcal + 3 macros.
struct Macros: Equatable {
    var kcal: Int
    var protein: Int // g
    var carbs: Int // g
    var fat: Int // g

    static let zero = Macros(kcal: 0, protein: 0, carbs: 0, fat: 0)

    static func + (l: Macros, r: Macros) -> Macros {
        Macros(kcal: l.kcal + r.kcal, protein: l.protein + r.protein,
               carbs: l.carbs + r.carbs, fat: l.fat + r.fat)
    }
}
