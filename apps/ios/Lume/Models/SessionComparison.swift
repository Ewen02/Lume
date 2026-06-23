import Foundation

/// Compare une séance à la précédente (même intitulé en priorité, sinon la plus récente avant).
/// Fournit les deltas de volume et de 1RM par exercice. Pur et testable.
struct SessionComparison {
    /// Séance de référence (la précédente) trouvée, si elle existe.
    let previous: WorkoutSessionModel?
    /// Delta de volume total (kg) : positif = mieux que la fois précédente.
    let volumeDelta: Int
    /// Delta de 1RM par exercice (nom → delta kg), seulement pour les exercices présents dans les deux.
    let oneRMDeltas: [(exercise: String, delta: Int)]

    init(session: WorkoutSessionModel, allSessions: [WorkoutSessionModel]) {
        // La précédente = séance de MÊME intitulé la plus récente avant (comparer une Push à une Push).
        let prev = allSessions
            .filter { $0.id != session.id && $0.date < session.date && $0.title == session.title }
            .max { $0.date < $1.date }
        previous = prev

        guard let prev else {
            volumeDelta = 0
            oneRMDeltas = []
            return
        }

        func volume(_ s: WorkoutSessionModel) -> Int {
            s.orderedExercises.reduce(0) { acc, ex in
                acc + ex.orderedSets.reduce(0) { $0 + Int($1.weight) * $1.reps }
            }
        }
        volumeDelta = volume(session) - volume(prev)

        // 1RM par exercice présent dans les deux séances.
        var prevBest: [String: Int] = [:]
        for ex in prev.orderedExercises {
            prevBest[ex.name] = max(prevBest[ex.name] ?? 0, ex.bestOneRM)
        }
        var deltas: [(String, Int)] = []
        for ex in session.orderedExercises where ex.bestOneRM > 0 {
            if let before = prevBest[ex.name], before > 0 {
                deltas.append((ex.name, ex.bestOneRM - before))
            }
        }
        oneRMDeltas = deltas
    }

    var hasComparison: Bool {
        previous != nil
    }
}
