import Foundation

// Modèles de lecture HealthKit (valeurs simples, sans dépendance au framework HealthKit
// pour rester testables). Peuplés par `HealthManager` à partir des échantillons Santé.

/// Une séance importée depuis Apple Santé (Apple Watch / autre app), en lecture seule.
struct ExternalWorkout: Identifiable {
    let id: UUID
    var date: Date
    var durationSec: Int
    var kcal: Int?
    /// Libellé du type d'activité (déjà traduit/raccourci par le mapping).
    var type: String

    init(id: UUID = UUID(), date: Date, durationSec: Int, kcal: Int?, type: String) {
        self.id = id; self.date = date; self.durationSec = durationSec
        self.kcal = kcal; self.type = type
    }

    /// Durée formatée « 1 h 05 » / « 45 min ».
    var durationLabel: String {
        let m = durationSec / 60
        return m >= 60 ? "\(m / 60) h \(String(format: "%02d", m % 60))" : "\(m) min"
    }
}

/// Valeur quotidienne datée d'une métrique d'activité (pas, calories actives…).
/// Type daté commun aux séries de Progrès : permet un filtrage par période homogène
/// (`.filter { $0.date >= start }`) sans aligner deux séries par longueur.
struct DayValue: Identifiable {
    var date: Date
    var value: Int
    /// id stable (dérivé du jour) → SwiftUI/Charts ne ré-anime pas tout à chaque refresh.
    var id: Date {
        date
    }
}
