import Foundation

/// Calcul de la série (streak) : nombre de jours consécutifs, en remontant depuis
/// aujourd'hui, où au moins un repas a été enregistré.
///
/// Logique extraite des vues pour être testable. Pure : dépend uniquement des dates
/// fournies et du calendrier (injectable pour les tests).
enum StreakCalculator {
    /// - Parameters:
    ///   - dates: dates des repas enregistrés (ordre quelconque).
    ///   - reference: jour de référence (aujourd'hui par défaut).
    ///   - calendar: calendrier utilisé (courant par défaut).
    /// - Returns: la longueur de la série courante. 0 si aucun repas aujourd'hui ni hier.
    ///
    /// Tolérance : la série reste vivante si le dernier repas date d'aujourd'hui OU d'hier
    /// (on ne « casse » pas la série tant que la journée en cours n'est pas finie).
    static func currentStreak(from dates: [Date],
                              reference: Date = Date(),
                              calendar: Calendar = .current) -> Int
    {
        guard !dates.isEmpty else { return 0 }

        let loggedDays = Set(dates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: reference)

        // Point de départ : aujourd'hui s'il y a un repas, sinon hier (tolérance), sinon série rompue.
        var cursor: Date
        if loggedDays.contains(today) {
            cursor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  loggedDays.contains(yesterday)
        {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while loggedDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Plus longue série historique (record), tous jours confondus.
    static func longestStreak(from dates: [Date], calendar: Calendar = .current) -> Int {
        guard !dates.isEmpty else { return 0 }
        let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
        var best = 1, run = 1
        for i in 1 ..< days.count {
            if let prev = calendar.date(byAdding: .day, value: 1, to: days[i - 1]),
               calendar.isDate(prev, inSameDayAs: days[i]) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return best
    }
}
