import Foundation

/// Records personnels (1RM estimé) dérivés des séances persistées.
///
/// Logique extraite des vues (`PRHistoryView`, `WorkoutHomeView`) pour être testable
/// et partagée — une seule source de vérité pour les PR affichés partout.
struct PersonalRecord: Identifiable {
    var exercise: String
    var oneRM: Int
    var date: Date
    var id: String {
        exercise
    }
}

/// Résumé d'entraînement sur une fenêtre (7 jours par défaut) : nombre de séances,
/// volume total (kg·reps) et durée cumulée. Extrait des vues, testable.
struct WeekTraining {
    var sessions: Int
    var volumeKg: Int
    var minutes: Int
}

enum WorkoutStats {
    /// Résumé des 7 derniers jours.
    static func lastSevenDays(from sessions: [WorkoutSessionModel],
                              reference: Date = Date(),
                              calendar: Calendar = .current) -> WeekTraining
    {
        let today0 = calendar.startOfDay(for: reference)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today0) ?? today0
        let inWeek = sessions.filter { $0.date >= weekStart }
        let volume = inWeek.reduce(0.0) { acc, s in
            acc + s.orderedExercises.reduce(0.0) { exAcc, ex in
                exAcc + ex.orderedSets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
            }
        }
        let secs = inWeek.reduce(0) { $0 + $1.durationSec }
        return WeekTraining(sessions: inWeek.count, volumeKg: Int(volume), minutes: secs / 60)
    }

    /// Meilleur 1RM estimé par exercice, trié du plus lourd au plus léger.
    ///
    /// - Parameter sessions: séances persistées (`WorkoutSessionModel`).
    /// - Returns: un record par exercice, classé décroissant. Vide si aucune donnée.
    static func topPRs(from sessions: [WorkoutSessionModel]) -> [PersonalRecord] {
        var best: [String: (oneRM: Int, date: Date)] = [:]
        for session in sessions {
            for ex in session.orderedExercises where ex.bestOneRM > 0 {
                if let cur = best[ex.name] {
                    if ex.bestOneRM > cur.oneRM { best[ex.name] = (ex.bestOneRM, session.date) }
                } else {
                    best[ex.name] = (ex.bestOneRM, session.date)
                }
            }
        }
        return best
            .sorted { $0.value.oneRM > $1.value.oneRM }
            .map { PersonalRecord(exercise: $0.key, oneRM: $0.value.oneRM, date: $0.value.date) }
    }
}
