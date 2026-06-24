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

    /// Comparaison semaine courante vs semaine précédente (moyenne kcal/jour renseigné).
    /// - Returns: `(thisWeek, lastWeek, deltaPct)` où `deltaPct` = variation relative
    ///   (`+0.08` = +8 %). `deltaPct` est `nil` si la semaine précédente est vide (0).
    static func weekOverWeek(from entries: [LoggedFood],
                             reference: Date = Date(),
                             calendar: Calendar = .current) -> (thisWeek: Int, lastWeek: Int, deltaPct: Double?)
    {
        let thisWeek = dailyAverage(of: lastSevenDays(from: entries, reference: reference, calendar: calendar))
        let priorRef = calendar.date(byAdding: .day, value: -7, to: reference) ?? reference
        let lastWeek = dailyAverage(of: lastSevenDays(from: entries, reference: priorRef, calendar: calendar))
        let deltaPct = lastWeek > 0 ? (Double(thisWeek) - Double(lastWeek)) / Double(lastWeek) : nil
        return (thisWeek, lastWeek, deltaPct)
    }
}
