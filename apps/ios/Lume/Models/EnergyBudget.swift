import Foundation

/// Décide de la cible calorique du jour selon que l'app a (ou non) accès à la dépense
/// réelle mesurée par Apple Santé.
///
/// - **Mode dynamique** (Santé autorisé) : `cible = BMR + objectif + calories actives réelles`.
///   Plus tu bouges, plus tu peux manger. La base part du BMR (métabolisme de repos) pour
///   ne PAS double-compter l'activité déjà incluse dans le facteur d'activité du TDEE.
/// - **Mode fixe** (pas de Santé) : on garde le TDEE classique (`BMR × facteur d'activité`),
///   comportement historique inchangé.
enum EnergyBudget {
    /// Cible kcal du jour.
    /// - Parameters:
    ///   - activeKcal: calories actives mesurées par Santé aujourd'hui (`nil` si indisponible).
    ///   - healthAuthorized: l'utilisateur a accordé l'accès Santé.
    static func targetKcal(_ p: UserProfile, activeKcal: Int?, healthAuthorized: Bool) -> Int {
        if healthAuthorized, let activeKcal {
            return TDEECalculator.restingTarget(p).kcal + max(0, activeKcal)
        }
        return TDEECalculator.target(p).kcal
    }

    /// Cible macros cohérente avec la cible kcal retenue (même règle de répartition que TDEECalculator).
    static func target(_ p: UserProfile, activeKcal: Int?, healthAuthorized: Bool) -> Macros {
        guard healthAuthorized, let activeKcal else { return TDEECalculator.target(p) }
        let kcal = TDEECalculator.restingTarget(p).kcal + max(0, activeKcal)
        return TDEECalculator.macros(forKcal: kcal, profile: p)
    }

    /// Indique si le mode dynamique (ajusté à l'activité) est actif.
    static func isDynamic(activeKcal: Int?, healthAuthorized: Bool) -> Bool {
        healthAuthorized && activeKcal != nil
    }
}
