import Foundation

/// Moyennes de macros par jour renseigné sur une fenêtre de repas (7 j par défaut).
/// Complète la moyenne kcal : utile pour une app macros (protéines surtout).
enum WeeklyMacros {
    /// Moyenne (protéines, glucides, lipides) par jour où au moins un repas a été enregistré.
    /// Renvoie `nil` si aucun jour actif (la vue masque alors les chips).
    static func average(from entries: [LoggedFood],
                        days: Int = 7,
                        reference: Date = Date(),
                        calendar: Calendar = .current) -> Macros?
    {
        let today0 = calendar.startOfDay(for: reference)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today0) ?? today0
        let window = entries.filter { $0.date >= start }
        guard !window.isEmpty else { return nil }

        // Total par macro + nombre de jours distincts renseignés.
        var totals = Macros.zero
        var activeDays: Set<Date> = []
        for f in window {
            totals = totals + f.macros
            activeDays.insert(calendar.startOfDay(for: f.date))
        }
        let n = activeDays.count
        guard n > 0 else { return nil }
        return Macros(kcal: totals.kcal / n, protein: totals.protein / n,
                      carbs: totals.carbs / n, fat: totals.fat / n)
    }
}
