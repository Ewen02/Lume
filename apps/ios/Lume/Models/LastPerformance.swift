import Foundation

/// Retrouve la performance précédente d'un exercice (séance la plus récente où il a été fait),
/// pour l'afficher en référence pendant la séance en cours. Pur et testable.
enum LastPerformance {
    /// Résumé court de la meilleure série de la dernière séance contenant `exerciseName`.
    /// Renvoie nil si l'exercice n'a jamais été fait. `excluding` ignore une séance (la séance en cours).
    /// - Returns: ex. "80 kg × 8" (meilleure série au 1RM estimé).
    static func summary(for exerciseName: String, in sessions: [WorkoutSessionModel],
                        excluding excludedID: UUID? = nil) -> String?
    {
        let candidates = sessions
            .filter { $0.id != excludedID }
            .sorted { $0.date > $1.date }

        for session in candidates {
            guard let ex = session.orderedExercises.first(where: { $0.name == exerciseName }) else { continue }
            // Meilleure série = celle au plus haut 1RM estimé.
            let best = ex.orderedSets.max { a, b in
                OneRepMax.estimate(weight: a.weight, reps: a.reps) < OneRepMax.estimate(weight: b.weight, reps: b.reps)
            }
            if let set = best, set.reps > 0 {
                return "\(set.weight.clean) kg × \(set.reps)"
            }
        }
        return nil
    }
}
