import Foundation

struct FoodItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var grams: Int
    var macros: Macros // pour la portion `grams`
}
