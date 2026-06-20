import Foundation

/// Agrège les calories par jour sur les 7 derniers jours (lundi→dimanche relatif :
/// 6 jours en arrière jusqu'à aujourd'hui). Logique extraite des vues, testable.
enum WeeklyCalories {
    private static let weekdayLetters = ["D", "L", "M", "M", "J", "V", "S"] // index = weekday 1...7

    /// - Parameters:
    ///   - entries: repas enregistrés (au moins les 7 derniers jours).
    ///   - reference: dernier jour de la fenêtre (aujourd'hui par défaut).
    ///   - calendar: calendrier (courant par défaut).
    /// - Returns: 7 entrées ordonnées du plus ancien au jour courant.
    static func lastSevenDays(from entries: [LoggedFood],
                              reference: Date = Date(),
                              calendar: Calendar = .current) -> [DayCalories]
    {
        let today0 = calendar.startOfDay(for: reference)
        return (0 ..< 7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today0) ?? today0
            let kcal = entries
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.kcal }
            let wd = calendar.component(.weekday, from: day)
            return DayCalories(label: weekdayLetters[wd - 1], kcal: kcal)
        }
    }

    /// Moyenne des kcal sur les jours réellement renseignés (> 0). 0 si aucun.
    static func dailyAverage(of week: [DayCalories]) -> Int {
        let active = week.filter { $0.kcal > 0 }
        return active.isEmpty ? 0 : active.map(\.kcal).reduce(0, +) / active.count
    }
}
