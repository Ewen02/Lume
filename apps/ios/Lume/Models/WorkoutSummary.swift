import Foundation

/// Résumé d'une séance terminée, dérivé des exercices loggés. Pur et testable.
struct WorkoutSummary: Identifiable {
    let id = UUID()
    let durationSec: Int
    let exerciseCount: Int
    let setCount: Int
    /// Volume total = somme(poids × reps) sur les séries effectuées.
    let totalVolume: Int
    /// Meilleur 1RM estimé de la séance (kg).
    let bestOneRM: Int
    let bestExercise: String?

    init(from sessions: [ExerciseSession], durationSec: Int) {
        self.durationSec = durationSec
        // On ne compte que les séries réellement effectuées (reps > 0).
        let withSets = sessions.map { ($0.exercise.name, $0.sets.filter { $0.reps > 0 }) }
            .filter { !$0.1.isEmpty }
        exerciseCount = withSets.count
        setCount = withSets.reduce(0) { $0 + $1.1.count }
        totalVolume = withSets.reduce(0) { acc, pair in
            acc + pair.1.reduce(0) { $0 + Int($1.weight) * $1.reps }
        }
        var best = 0
        var bestEx: String?
        for (name, sets) in withSets {
            for set in sets {
                let oneRM = OneRepMax.estimate(weight: set.weight, reps: set.reps)
                if oneRM > best { best = oneRM; bestEx = name }
            }
        }
        bestOneRM = best
        bestExercise = bestEx
    }

    var durationLabel: String {
        let m = durationSec / 60, s = durationSec % 60
        return m > 0 ? "\(m) min \(s) s" : "\(s) s"
    }
}

/// Record personnel de 1RM battu pendant une séance (pour la célébration du récap).
struct PRBeaten: Identifiable {
    var exercise: String
    var oneRM: Int
    var previous: Int
    var id: String {
        exercise
    }
}
