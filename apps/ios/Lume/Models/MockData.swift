import Foundation

/// Données de démo pour les previews et le prototypage.
enum Mock {
    static let profile = UserProfile(name: "Ewen", sex: .male, age: 24,
                                     heightCm: 178, weightKg: 74,
                                     activity: .moderate, goal: .maintain)

    static let target = Macros(kcal: 2400, protein: 150, carbs: 270, fat: 80)
    static let consumed = Macros(kcal: 1450, protein: 88, carbs: 165, fat: 48)

    static let meals: [Meal] = [
        Meal(type: .breakfast, subtitle: "Flocons d'avoine, banane",
             items: [FoodItem(name: "Flocons d'avoine", grams: 60, macros: Macros(kcal: 230, protein: 9, carbs: 40, fat: 4)),
                     FoodItem(name: "Banane", grams: 120, macros: Macros(kcal: 105, protein: 1, carbs: 27, fat: 0))]),
        Meal(type: .lunch, subtitle: "Bowl poulet & riz",
             items: [FoodItem(name: "Poulet grillé", grams: 150, macros: Macros(kcal: 248, protein: 46, carbs: 0, fat: 5)),
                     FoodItem(name: "Riz basmati", grams: 200, macros: Macros(kcal: 260, protein: 5, carbs: 56, fat: 1)),
                     FoodItem(name: "Brocoli", grams: 80, macros: Macros(kcal: 27, protein: 3, carbs: 4, fat: 0))]),
        Meal(type: .snack, subtitle: "Pomme, amandes",
             items: [FoodItem(name: "Pomme", grams: 150, macros: Macros(kcal: 78, protein: 0, carbs: 21, fat: 0)),
                     FoodItem(name: "Amandes", grams: 25, macros: Macros(kcal: 145, protein: 5, carbs: 5, fat: 13))]),
    ]

    static let detected: [FoodItem] = meals[1].items

    /// Records de démo (affichés tant qu'aucune séance n'est enregistrée).
    static let topRecords: [PersonalRecord] = {
        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: -n, to: Date()) ?? Date()
        }
        return [
            PersonalRecord(exercise: "Soulevé de terre", oneRM: 170, date: daysAgo(14)),
            PersonalRecord(exercise: "Squat", oneRM: 140, date: daysAgo(7)),
            PersonalRecord(exercise: "Développé couché", oneRM: 94, date: daysAgo(3)),
            PersonalRecord(exercise: "Développé militaire", oneRM: 62, date: daysAgo(21)),
        ]
    }()

    /// Historique de records de démo, formaté pour `PRHistoryView`.
    static var prHistory: [(String, String, String)] {
        topRecords.map { ($0.exercise, "\($0.oneRM) kg", Formatters.relative($0.date)) }
    }
}
