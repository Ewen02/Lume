import Foundation

/// Série (streak) d'entraînement HEBDOMADAIRE : nombre de semaines consécutives où l'objectif
/// de séances est atteint, en remontant depuis la semaine courante. Pur et testable.
///
/// Adapté à la muscu (on ne s'entraîne pas tous les jours) : l'unité est la semaine, pas le jour.
/// Tolérance : la semaine en cours ne « casse » pas la série tant qu'elle n'est pas terminée —
/// elle ne compte que si l'objectif y est déjà atteint, mais son éventuel manque est ignoré.
enum WorkoutStreak {
    /// Compte de séances par semaine (clé = début de semaine), sur la fenêtre des dates fournies.
    private static func sessionsPerWeek(_ dates: [Date], calendar: Calendar) -> [Date: Int] {
        var out: [Date: Int] = [:]
        for date in dates {
            if let week = calendar.dateInterval(of: .weekOfYear, for: date)?.start {
                out[week, default: 0] += 1
            }
        }
        return out
    }

    /// Série courante (en semaines) : nombre de semaines consécutives, en remontant, où
    /// `séances >= goal`. La semaine en cours est tolérée (ne casse pas si incomplète).
    static func currentStreak(from dates: [Date], goal: Int,
                              reference: Date = Date(), calendar: Calendar = .current) -> Int
    {
        guard goal > 0, !dates.isEmpty,
              let thisWeek = calendar.dateInterval(of: .weekOfYear, for: reference)?.start
        else { return 0 }

        let counts = sessionsPerWeek(dates, calendar: calendar)
        var streak = 0
        var cursor = thisWeek
        var isCurrentWeek = true

        while true {
            let met = (counts[cursor] ?? 0) >= goal
            if met {
                streak += 1
            } else if isCurrentWeek {
                // Semaine en cours encore incomplète : on l'ignore et on remonte sans casser.
            } else {
                break
            }
            isCurrentWeek = false
            guard let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Plus longue série hebdomadaire historique (record).
    static func longestStreak(from dates: [Date], goal: Int, calendar: Calendar = .current) -> Int {
        guard goal > 0, !dates.isEmpty else { return 0 }
        let counts = sessionsPerWeek(dates, calendar: calendar)
        let metWeeks = counts.filter { $0.value >= goal }.keys.sorted()
        guard !metWeeks.isEmpty else { return 0 }

        var best = 1, run = 1
        for i in 1 ..< metWeeks.count {
            if let next = calendar.date(byAdding: .weekOfYear, value: 1, to: metWeeks[i - 1]),
               calendar.isDate(next, equalTo: metWeeks[i], toGranularity: .weekOfYear)
            {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return best
    }

    /// Nombre de séances de la semaine de référence (pour l'anneau d'objectif).
    static func sessionsThisWeek(from dates: [Date], reference: Date = Date(),
                                 calendar: Calendar = .current) -> Int
    {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: reference)?.start else { return 0 }
        return sessionsPerWeek(dates, calendar: calendar)[week] ?? 0
    }
}
