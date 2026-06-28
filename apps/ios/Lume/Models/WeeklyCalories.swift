import Foundation

/// Agrège les calories par jour sur les 7 derniers jours (lundi→dimanche relatif :
/// 6 jours en arrière jusqu'à aujourd'hui). Logique extraite des vues, testable.
enum WeeklyCalories {
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
            // Initiale localisée (index = weekday 1...7, comme veryShortWeekdaySymbols).
            return DayCalories(label: calendar.veryShortWeekdaySymbols[wd - 1], kcal: kcal)
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

    /// Agrège les calories par **semaine** depuis `start` jusqu'à `reference` : une barre
    /// par semaine (moyenne kcal/jour renseigné de la semaine). Utilisé pour les périodes
    /// > 7 j où un graphe jour-par-jour serait illisible. Ordonné du plus ancien au courant.
    static func byWeek(from entries: [LoggedFood],
                       since start: Date,
                       reference: Date = Date(),
                       calendar: Calendar = .current) -> [DayCalories]
    {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: reference)
        /// Borne de semaine (lundi) de chaque date, pour grouper.
        func weekStart(_ date: Date) -> Date {
            calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        }
        // Somme + nombre de jours actifs par semaine.
        var sumByWeek: [Date: Int] = [:]
        var daysByWeek: [Date: Set<Date>] = [:]
        for f in entries where f.date >= from {
            let day = calendar.startOfDay(for: f.date)
            let wk = weekStart(day)
            sumByWeek[wk, default: 0] += f.kcal
            daysByWeek[wk, default: []].insert(day)
        }
        // Génère toutes les semaines de la fenêtre (même vides) pour un axe continu.
        var weeks: [Date] = []
        var cursor = weekStart(from)
        let lastWeek = weekStart(to)
        while cursor <= lastWeek {
            weeks.append(cursor)
            cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? lastWeek.addingTimeInterval(1)
        }
        return weeks.map { wk in
            let days = daysByWeek[wk]?.count ?? 0
            let avg = days > 0 ? (sumByWeek[wk] ?? 0) / days : 0
            let day = calendar.component(.day, from: wk)
            let month = calendar.component(.month, from: wk)
            return DayCalories(label: "\(day)/\(month)", kcal: avg)
        }
    }

    /// Calories consommées par jour, datées, de `start` au jour de `reference` inclus.
    /// Tous les jours de la fenêtre sont présents (vides à 0) pour un axe continu — sert
    /// au graphe « balance énergétique » qui joint la conso à la dépense par date.
    static func consumedByDay(from entries: [LoggedFood],
                              since start: Date,
                              reference: Date = Date(),
                              calendar: Calendar = .current) -> [DayValue]
    {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: reference)
        var sumByDay: [Date: Int] = [:]
        for f in entries where f.date >= from {
            sumByDay[calendar.startOfDay(for: f.date), default: 0] += f.kcal
        }
        var out: [DayValue] = []
        var cursor = from
        while cursor <= to {
            out.append(DayValue(date: cursor, value: sumByDay[cursor] ?? 0))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? to.addingTimeInterval(1)
        }
        return out
    }
}
