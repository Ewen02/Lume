import Foundation

struct FoodItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var grams: Int
    var macros: Macros // pour la portion `grams`
    /// `false` quand l'aliment a été reconnu mais introuvable en base (macros à 0, à signaler).
    var matched: Bool = true
}
