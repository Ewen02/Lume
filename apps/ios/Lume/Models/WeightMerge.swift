import Foundation

/// Réconcilie les pesées HealthKit et les pesées locales (WeightSample) en une seule
/// série propre : un point par jour, HealthKit prioritaire en cas de conflit le même jour.
///
/// Corrige le défaut du fallback « HealthKit sinon local » (OU exclusif), qui masquait
/// tout l'historique local dès que HealthKit renvoyait ne serait-ce qu'un point, et qui
/// pouvait compter deux fois la même journée (seed + saisie) dans la tendance lissée.
enum WeightMerge {
    /// Fusionne les deux sources, déduplique par jour (HealthKit gagne), trie par date asc.
    static func merge(healthKit: [WeightEntry],
                      local: [WeightEntry],
                      calendar: Calendar = .current) -> [WeightEntry]
    {
        // On insère HealthKit en dernier pour qu'il écrase le local sur un même jour.
        var byDay: [Date: WeightEntry] = [:]
        for entry in local {
            byDay[calendar.startOfDay(for: entry.date)] = entry
        }
        for entry in healthKit {
            byDay[calendar.startOfDay(for: entry.date)] = entry
        }
        return byDay.values.sorted { $0.date < $1.date }
    }
}
