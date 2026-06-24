import Foundation

/// Mifflin–St Jeor → TDEE → objectif → répartition macros.
/// Protéines 1.8 g/kg, lipides 0.9 g/kg, glucides = reste.
enum TDEECalculator {
    /// Profil neutre pour un objectif de repli quand aucun profil n'est encore enregistré.
    /// (Remplace l'ancien `Mock.target` — c'est un défaut documenté, pas une donnée de démo.)
    private static let neutralProfile = UserProfile(name: "", sex: .male, age: 30, heightCm: 175,
                                                    weightKg: 70, activity: .moderate, goal: .maintain)

    /// Objectif de repli (profil absent). Valeur explicite, jamais présentée comme « ton » objectif.
    static var defaultTarget: Macros { target(neutralProfile) }

    static func bmr(_ p: UserProfile) -> Double {
        let base = 10 * p.weightKg + 6.25 * Double(p.heightCm) - 5 * Double(p.age)
        return base + (p.sex == .male ? 5 : -161)
    }

    static func tdee(_ p: UserProfile) -> Int {
        Int((bmr(p) * p.activity.factor).rounded())
    }

    static func target(_ p: UserProfile) -> Macros {
        macros(forKcal: tdee(p) + p.goal.kcalDelta, profile: p)
    }

    /// Cible « de repos » : base = BMR (sans facteur d'activité) + objectif.
    /// Sert au bilan énergétique dynamique : on y ajoute ensuite les calories
    /// actives RÉELLES mesurées par Santé (cf. `EnergyBudget`), au lieu d'estimer
    /// l'activité via le facteur — ce qui éviterait le double-comptage.
    static func restingTarget(_ p: UserProfile) -> Macros {
        macros(forKcal: Int(bmr(p).rounded()) + p.goal.kcalDelta, profile: p)
    }

    /// Répartition macros pour une cible kcal donnée (protéines 1.8 g/kg, lipides 0.9 g/kg,
    /// glucides = reste). Factorisé entre cible fixe (TDEE), cible de repos (BMR) et cible dynamique.
    static func macros(forKcal kcal: Int, profile p: UserProfile) -> Macros {
        let protein = Int((1.8 * p.weightKg).rounded())
        let fat = Int((0.9 * p.weightKg).rounded())
        let kcalFromPF = protein * 4 + fat * 9
        let carbs = max(0, Int(Double(kcal - kcalFromPF) / 4))
        return Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }
}
