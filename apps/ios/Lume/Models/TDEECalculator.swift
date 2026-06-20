import Foundation

/// Mifflin–St Jeor → TDEE → objectif → répartition macros.
/// Protéines 1.8 g/kg, lipides 0.9 g/kg, glucides = reste.
enum TDEECalculator {
    static func bmr(_ p: UserProfile) -> Double {
        let base = 10 * p.weightKg + 6.25 * Double(p.heightCm) - 5 * Double(p.age)
        return base + (p.sex == .male ? 5 : -161)
    }

    static func tdee(_ p: UserProfile) -> Int {
        Int((bmr(p) * p.activity.factor).rounded())
    }

    static func target(_ p: UserProfile) -> Macros {
        let kcal = tdee(p) + p.goal.kcalDelta
        let protein = Int((1.8 * p.weightKg).rounded())
        let fat = Int((0.9 * p.weightKg).rounded())
        let kcalFromPF = protein * 4 + fat * 9
        let carbs = max(0, Int(Double(kcal - kcalFromPF) / 4))
        return Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }
}
