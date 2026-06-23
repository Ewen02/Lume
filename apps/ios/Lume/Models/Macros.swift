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

    /// Calories apportées par chaque macro (Atwater : P/G = 4 kcal/g, L = 9 kcal/g).
    var proteinKcal: Int {
        protein * 4
    }

    var carbsKcal: Int {
        carbs * 4
    }

    var fatKcal: Int {
        fat * 9
    }

    /// Total des calories issues des macros (peut différer de `kcal` mesuré ; sert aux proportions).
    var macroKcal: Int {
        proteinKcal + carbsKcal + fatKcal
    }

    /// Parts (0...1) de chaque macro dans les calories des macros. (0,0,0) si vide.
    var split: (protein: Double, carbs: Double, fat: Double) {
        let total = Double(macroKcal)
        guard total > 0 else { return (0, 0, 0) }
        return (Double(proteinKcal) / total, Double(carbsKcal) / total, Double(fatKcal) / total)
    }
}
