import Foundation

struct FoodItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var grams: Int
    var macros: Macros // pour la portion `grams`
    /// Base exacte pour 100 g (renvoyée par le serveur). `nil` → on retombe sur une estimation
    /// dérivée des macros de la portion (mode démo / valeur absente).
    var per100g: Macros?
    /// `false` quand l'aliment a été reconnu mais introuvable en base (macros à 0, à signaler).
    var matched: Bool = true
    /// Confiance de reconnaissance (0–1). En dessous de 0,5 → aliment à vérifier.
    var confidence: Double = 1

    /// Reconnaissance peu sûre : on invite l'utilisateur à vérifier.
    var isUncertain: Bool {
        matched && confidence < 0.5
    }
}
