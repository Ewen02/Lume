import Foundation

/// Mifflin–St Jeor → TDEE → objectif → répartition macros.
///
/// Modèle de calcul (le plus personnalisé possible à partir de ce que saisit l'utilisateur) :
/// - **BMR** : Mifflin–St Jeor (sexe, âge, taille, poids).
/// - **TDEE** : BMR × facteur d'activité (5 paliers).
/// - **Objectif** : ajustement en **% du TDEE** (−15 % perte / +10 % prise), pas un kcal fixe →
///   vitesse de perte/prise cohérente quel que soit le gabarit.
/// - **Plancher de sécurité** : la cible affichée ne descend jamais sous `max(BMR, 1500 H / 1200 F)`.
/// - **Protéines** : modulées par l'objectif (perte 2.0 / maintien 1.6 / prise 1.8 g·kg⁻¹).
/// - **Lipides** : 0.9 g·kg⁻¹ (peut être rogné jusqu'à 0.6 si l'enveloppe kcal est serrée).
/// - **Glucides** : le reste. On vise un minimum (`carbsPerKgFloor`) en rognant d'abord les lipides ;
///   il n'est pas absolument garanti dans des cas extrêmes (énergie sous protéines+lipides-plancher),
///   mais le plancher kcal de `target()`/`restingTarget()` rend ces cas inatteignables en pratique.
enum TDEECalculator {
    /// Profil neutre pour un objectif de repli quand aucun profil n'est encore enregistré.
    /// (Remplace l'ancien `Mock.target` — c'est un défaut documenté, pas une donnée de démo.)
    private static let neutralProfile = UserProfile(name: "", sex: .male, age: 30, heightCm: 175,
                                                    weightKg: 70, activity: .moderate, goal: .maintain)

    /// Objectif de repli (profil absent). Valeur explicite, jamais présentée comme « ton » objectif.
    static var defaultTarget: Macros {
        target(neutralProfile)
    }

    // MARK: - Constantes du modèle

    /// Plancher kcal absolu (avant prise en compte du BMR), par sexe.
    private static func kcalFloor(_ p: UserProfile) -> Int {
        let absolute = p.sex == .male ? 1500 : 1200
        return max(Int(bmr(p).rounded()), absolute)
    }

    /// Lipides : cible 0.9 g·kg⁻¹, jamais rognés sous 0.6 g·kg⁻¹.
    private static let fatPerKgTarget = 0.9
    private static let fatPerKgFloor = 0.6
    /// Glucides : minimum garanti ≈ 2 g·kg⁻¹, plancher absolu 50 g (fonctionnement cérébral / sport).
    private static let carbsPerKgFloor = 2.0
    private static let carbsAbsoluteFloor = 50

    // MARK: - Énergie

    static func bmr(_ p: UserProfile) -> Double {
        let base = 10 * p.weightKg + 6.25 * Double(p.heightCm) - 5 * Double(p.age)
        return base + (p.sex == .male ? 5 : -161)
    }

    static func tdee(_ p: UserProfile) -> Int {
        Int((bmr(p) * p.activity.factor).rounded())
    }

    /// Cible énergétique du jour (TDEE ajusté par l'objectif), **bornée au plancher de sécurité**.
    static func targetKcal(_ p: UserProfile) -> Int {
        let adjusted = Int((Double(tdee(p)) * p.goal.tdeeFactor).rounded())
        return max(adjusted, kcalFloor(p))
    }

    static func target(_ p: UserProfile) -> Macros {
        macros(forKcal: targetKcal(p), profile: p)
    }

    /// Cible « de repos » : base = BMR ajusté par l'objectif (sans facteur d'activité ni plancher).
    /// Sert au bilan énergétique dynamique : on y ajoute ensuite les calories actives RÉELLES
    /// mesurées par Santé (cf. `EnergyBudget`), au lieu d'estimer l'activité via le facteur — ce qui
    /// éviterait le double-comptage. Pas de plancher ici : le plancher s'applique à la cible affichée
    /// (`target`/`targetKcal`) ; l'appliquer au repos fausserait l'ajout d'activité.
    static func restingTarget(_ p: UserProfile) -> Macros {
        macros(forKcal: Int((bmr(p) * p.goal.tdeeFactor).rounded()), profile: p)
    }

    // MARK: - Macros

    /// Répartition macros pour une cible kcal donnée. Factorisé entre cible fixe (TDEE), cible de
    /// repos (BMR) et cible dynamique (Santé).
    ///
    /// Ordre des priorités quand l'enveloppe kcal est serrée :
    /// 1. Protéines servies en plein (modulées par l'objectif) — non négociables.
    /// 2. Glucides garantis à leur minimum (≥ `carbsPerKgFloor` g·kg⁻¹, ≥ `carbsAbsoluteFloor`).
    /// 3. Lipides = ce qui reste, mais jamais sous `fatPerKgFloor` g·kg⁻¹ ; dans l'enveloppe la plus
    ///    serrée (protéines + lipides-plancher consomment tout), les glucides deviennent la dernière
    ///    variable d'ajustement et peuvent tomber à 0 — cas inatteignable via le plancher kcal.
    static func macros(forKcal kcal: Int, profile p: UserProfile) -> Macros {
        let protein = Int((p.goal.proteinPerKg * p.weightKg).rounded())
        let carbsFloor = max(carbsAbsoluteFloor, Int((carbsPerKgFloor * p.weightKg).rounded()))
        let fatFloor = Int((fatPerKgFloor * p.weightKg).rounded())
        let fatTarget = Int((fatPerKgTarget * p.weightKg).rounded())

        let kcalForProtein = protein * 4
        // Énergie restante après protéines, pour répartir lipides + glucides.
        let remaining = max(0, kcal - kcalForProtein)

        // Lipides cibles, mais on garde de quoi servir le plancher de glucides.
        let fatTargetKcal = fatTarget * 9
        let carbsFloorKcal = carbsFloor * 4
        var fat: Int
        if remaining >= fatTargetKcal + carbsFloorKcal {
            fat = fatTarget // tout tient : lipides pleins
        } else if remaining >= fatFloor * 9 + carbsFloorKcal {
            fat = (remaining - carbsFloorKcal) / 9 // on rogne les lipides pour garder les glucides
        } else {
            fat = fatFloor // enveloppe très serrée : lipides au plancher
        }
        fat = max(fatFloor, fat)

        let carbs = max(0, (remaining - fat * 9) / 4)
        return Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }

    // MARK: - Réalisme de l'objectif

    /// Estime la vitesse de variation de poids (kg/semaine) impliquée par la cible, à partir du
    /// déficit/surplus quotidien et de l'équivalence ≈ 7700 kcal par kg de masse.
    static func weeklyWeightChangeKg(_ p: UserProfile) -> Double {
        let dailyDelta = Double(targetKcal(p) - tdee(p)) // <0 en perte, >0 en prise
        return dailyDelta * 7 / 7700
    }

    /// Avertissement si le rythme implicite est trop agressif (> 1 % du poids/semaine). Indépendant
    /// du poids cible : on se base sur la vitesse seule, donc ça marche même sans objectif de poids.
    /// Renvoie `nil` si le rythme est raisonnable.
    static func objectiveWarning(_ p: UserProfile) -> String? {
        guard p.goal != .maintain, p.weightKg > 0 else { return nil }
        let rateKgPerWeek = abs(weeklyWeightChangeKg(p))
        let maxSafe = p.weightKg * 0.01 // 1 % du poids / semaine
        guard rateKgPerWeek > maxSafe + 0.001 else { return nil }
        let verb = p.goal == .lose ? "perte" : "prise"
        let perWeek = String(format: "%.2f", rateKgPerWeek)
        return "Rythme soutenu : ~\(perWeek) kg/semaine de \(verb). Au-delà d'1 % du poids par semaine, vise plutôt une progression plus douce et durable."
    }
}
