import Foundation

struct WeightEntry: Identifiable {
    let id = UUID()
    var date: Date
    var kg: Double
}

struct DayCalories: Identifiable {
    let id = UUID()
    var label: String
    var kcal: Int
}

extension Mock {
    static var weights: [WeightEntry] {
        let cal = Calendar.current
        let base: [Double] = [75.4, 75.1, 75.2, 74.8, 74.6, 74.7, 74.3, 74.1, 73.9, 74.0, 73.7, 73.5]
        return base.enumerated().map { i, kg in
            WeightEntry(date: cal.date(byAdding: .day, value: -(base.count - 1 - i) * 3, to: Date())!, kg: kg)
        }
    }

    static let weekCalories: [DayCalories] = [
        .init(label: "L", kcal: 2310), .init(label: "M", kcal: 2480), .init(label: "M", kcal: 2200),
        .init(label: "J", kcal: 1450), .init(label: "V", kcal: 0), .init(label: "S", kcal: 0), .init(label: "D", kcal: 0),
    ]
    static let foods: [FoodItem] = [
        FoodItem(name: "Poulet grillé", grams: 100, macros: Macros(kcal: 165, protein: 31, carbs: 0, fat: 4)),
        FoodItem(name: "Riz basmati cuit", grams: 100, macros: Macros(kcal: 130, protein: 3, carbs: 28, fat: 0)),
        FoodItem(name: "Œuf entier", grams: 50, macros: Macros(kcal: 78, protein: 6, carbs: 1, fat: 5)),
        FoodItem(name: "Banane", grams: 120, macros: Macros(kcal: 105, protein: 1, carbs: 27, fat: 0)),
        FoodItem(name: "Skyr nature", grams: 150, macros: Macros(kcal: 96, protein: 17, carbs: 6, fat: 0)),
        FoodItem(name: "Amandes", grams: 30, macros: Macros(kcal: 174, protein: 6, carbs: 6, fat: 15)),
    ]
}
