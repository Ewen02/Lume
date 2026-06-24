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
    /// Volume (kg·reps) d'une séance — somme entière par série (arrondi unifié avec `weeklyVolume`).
    static func volume(of session: WorkoutSessionModel) -> Int {
        session.orderedExercises.reduce(0) { exAcc, ex in
            exAcc + ex.orderedSets.reduce(0) { $0 + Int($1.weight) * $1.reps }
        }
    }

    /// Résumé de la **semaine calendaire courante** (cohérent avec le streak et l'anneau objectif).
    static func lastSevenDays(from sessions: [WorkoutSessionModel],
                              reference: Date = Date(),
                              calendar: Calendar = .current) -> WeekTraining
    {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: reference)?.start
            ?? calendar.startOfDay(for: reference)
        let inWeek = sessions.filter { $0.date >= weekStart }
        let totalVolume = inWeek.reduce(0) { $0 + volume(of: $1) }
        let secs = inWeek.reduce(0) { $0 + $1.durationSec }
        return WeekTraining(sessions: inWeek.count, volumeKg: totalVolume, minutes: secs / 60)
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
                    // Meilleur 1RM ; à égalité, on retient la date la plus RÉCENTE (déterministe).
                    if ex.bestOneRM > cur.oneRM || (ex.bestOneRM == cur.oneRM && session.date > cur.date) {
                        best[ex.name] = (ex.bestOneRM, session.date)
                    }
                } else {
                    best[ex.name] = (ex.bestOneRM, session.date)
                }
            }
        }
        return best
            // Tri stable : 1RM décroissant, puis nom pour départager (ordre constant).
            .sorted { $0.value.oneRM != $1.value.oneRM ? $0.value.oneRM > $1.value.oneRM : $0.key < $1.key }
            .map { PersonalRecord(exercise: $0.key, oneRM: $0.value.oneRM, date: $0.value.date) }
    }

    /// Volume (kg·reps) agrégé par semaine sur les `weeks` dernières semaines, du plus ancien au courant.
    static func weeklyVolume(from sessions: [WorkoutSessionModel], weeks: Int = 8,
                             reference: Date = Date(), calendar: Calendar = .current) -> [VolumePoint]
    {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: reference)?.start else { return [] }
        return (0 ..< weeks).reversed().compactMap { offset -> VolumePoint? in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek),
                  let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { return nil }
            let weekVolume = sessions
                .filter { $0.date >= weekStart && $0.date < next }
                .reduce(0) { $0 + volume(of: $1) }
            return VolumePoint(weekStart: weekStart, volumeKg: weekVolume)
        }
    }
}

/// Point de volume hebdomadaire pour le graphe de progression muscu.
struct VolumePoint: Identifiable {
    var weekStart: Date
    var volumeKg: Int
    var id: Date {
        weekStart
    }
}
