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

enum WorkoutStats {
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
