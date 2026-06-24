import Foundation

/// Analyse de la série de poids : lissage (moyenne glissante), variation honnête sur
/// une fenêtre, et écart restant à l'objectif. Logique extraite des vues, testable.
///
/// Le but du lissage est d'éviter la lecture trompeuse de `dernier - premier` : une
/// pesée bruitée (eau, repas, heure) fait sauter le chiffre. La moyenne glissante donne
/// une tendance réaliste.
enum WeightTrend {
    /// Série lissée par moyenne glissante (fenêtre centrée sur les `window` derniers points).
    /// Renvoie une entrée par point d'origine (mêmes dates), avec la valeur moyennée.
    /// Si la série a moins de 2 points, elle est renvoyée telle quelle.
    static func smoothed(_ entries: [WeightEntry], window: Int = 7) -> [WeightEntry] {
        guard entries.count > 1, window > 1 else { return entries }
        let sorted = entries.sorted { $0.date < $1.date }
        return sorted.enumerated().map { index, entry in
            let lower = max(0, index - (window - 1))
            let slice = sorted[lower ... index]
            let avg = slice.map(\.kg).reduce(0, +) / Double(slice.count)
            return WeightEntry(date: entry.date, kg: avg)
        }
    }

    /// Variation de poids sur les `days` derniers jours, calculée sur la tendance lissée
    /// (plus honnête que `dernier - premier` brut). `nil` si la série est insuffisante.
    static func movingAverageDelta(_ entries: [WeightEntry],
                                   days: Int = 7,
                                   reference _: Date = Date(),
                                   calendar: Calendar = .current) -> Double?
    {
        guard entries.count > 1 else { return nil }
        let smoothedSeries = smoothed(entries)
        guard let latest = smoothedSeries.last else { return nil }
        let cutoff = calendar.date(byAdding: .day, value: -days, to: latest.date) ?? latest.date
        // Référence = dernier point lissé au plus tard à `cutoff` ; sinon le plus ancien.
        let past = smoothedSeries.last { $0.date <= cutoff } ?? smoothedSeries.first
        guard let past else { return nil }
        return latest.kg - past.kg
    }

    /// Écart restant à l'objectif (positif = au-dessus, négatif = en-dessous).
    /// `nil` si aucun objectif défini (target <= 0) ou pas de poids courant.
    static func remainingToTarget(current: Double?, target: Double) -> Double? {
        guard let current, current > 0, target > 0 else { return nil }
        return current - target
    }

    /// Tolérance (kg) en-dessous de laquelle on considère l'objectif atteint.
    static let targetEpsilon = 0.25

    /// Libellé directionnel de l'écart à l'objectif, tenant compte du sens de l'objectif
    /// (perte vs prise de poids). `nil` si pas d'objectif ou pas de poids courant.
    ///
    /// - `goal` : sens de l'objectif. `.lose` → on descend vers la cible ; `.gain` → on monte ;
    ///   `.maintain` → on vise l'égalité (le plus proche, dans les deux sens).
    static func targetLabel(current: Double?, target: Double, goal: Goal) -> String? {
        guard let remaining = remainingToTarget(current: current, target: target) else { return nil }
        if abs(remaining) < targetEpsilon { return "Objectif atteint" }
        let kg = String(format: "%.1f kg", abs(remaining))
        switch goal {
        case .lose:
            // current > target → encore à perdre ; current < target → sous la cible.
            return remaining > 0 ? "Reste \(kg)" : "\(kg) sous l'objectif"
        case .gain:
            // current < target → encore à prendre ; current > target → au-dessus.
            return remaining < 0 ? "Reste \(kg)" : "\(kg) au-dessus"
        case .maintain:
            return remaining > 0 ? "\(kg) au-dessus" : "\(kg) sous l'objectif"
        }
    }
}
