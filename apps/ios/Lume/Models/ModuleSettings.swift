import Foundation

/// Modules optionnels de Lume, choisis à l'onboarding (la nutrition est le cœur, toujours actif).
///
/// Source de vérité unique pour savoir quels onglets afficher : `RootView` lit ces clés via
/// `@AppStorage` pour composer la barre d'onglets et l'action du bouton flottant. Activer/désactiver
/// un module ne supprime aucune donnée — il masque seulement son onglet.
enum ModuleSettings {
    /// Le module Muscu est-il activé (onglet « Muscu » visible) ?
    static let workoutKey = "lume.module.workout"
    /// Le module Finance est-il activé (onglet « Budget » visible) ?
    static let financeKey = "lume.module.finance"

    /// Valeur par défaut tant que l'onboarding n'a rien écrit (les deux modules proposés, activés).
    static let defaultEnabled = true
}
