import Foundation

/// Bilan énergétique d'une journée : calories consommées vs dépensées.
/// `net < 0` = déficit (on perd), `net > 0` = surplus (on prend).
struct DayBalance: Identifiable {
    var date: Date
    var consumed: Int
    var expended: Int
    var id: Date {
        date
    }

    var net: Int {
        consumed - expended
    }
}

/// Construit la série jour-par-jour conso vs dépense. Logique pure (aucune dépendance
/// HealthKit) → testable.
///
/// Dépense totale d'un jour = **BMR (métabolisme de repos, constant)** + **calories actives**
/// mesurées par Santé ce jour-là. Sans données Santé (compte gratuit), la dépense se
/// réduit au BMR — sous-estimée mais honnête (à signaler dans l'UI).
enum EnergyBalance {
    /// - Parameters:
    ///   - consumed: kcal consommées par jour (datées, jours vides à 0).
    ///   - activeEnergy: kcal actives par jour (Santé) ; jours absents → 0 actif.
    ///   - bmr: métabolisme de repos (kcal/jour), constante du profil.
    /// - Returns: une entrée par jour de `consumed`, ordonnée comme elle.
    static func series(consumed: [DayValue],
                       activeEnergy: [DayValue],
                       bmr: Int,
                       calendar: Calendar = .current) -> [DayBalance]
    {
        // Indexe l'énergie active par jour pour une jointure O(1).
        var activeByDay: [Date: Int] = [:]
        for d in activeEnergy {
            activeByDay[calendar.startOfDay(for: d.date)] = d.value
        }
        return consumed.map { day in
            let active = activeByDay[calendar.startOfDay(for: day.date)] ?? 0
            return DayBalance(date: day.date, consumed: day.value, expended: bmr + active)
        }
    }

    /// Moyenne du net sur les jours réellement renseignés (conso ou dépense > 0). 0 si aucun.
    static func averageNet(_ series: [DayBalance]) -> Int {
        let active = series.filter { $0.consumed > 0 || $0.expended > 0 }
        return active.isEmpty ? 0 : active.map(\.net).reduce(0, +) / active.count
    }
}
