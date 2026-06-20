import Foundation
import SwiftData

/// Séance de musculation terminée (persistée localement + CloudKit).
/// 100 % local côté produit — aucun backend. Relations optionnelles (contrainte CloudKit).
@Model
final class WorkoutSessionModel {
    var id: UUID = UUID()
    var date: Date = Date()
    var durationSec: Int = 0
    var title: String = "Séance"

    @Relationship(deleteRule: .cascade, inverse: \LoggedExerciseModel.session)
    var exercises: [LoggedExerciseModel]? = []

    init(date: Date = Date(), durationSec: Int = 0, title: String = "Séance") {
        self.date = date; self.durationSec = durationSec; self.title = title
    }

    var orderedExercises: [LoggedExerciseModel] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class LoggedExerciseModel {
    var id: UUID = UUID()
    var name: String = ""
    var muscleRaw: String = MuscleGroup.chest.code // code stable, pas le label
    var order: Int = 0

    var session: WorkoutSessionModel?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSetModel.exercise)
    var sets: [LoggedSetModel]? = []

    init(name: String, muscleRaw: String, order: Int = 0) {
        self.name = name; self.muscleRaw = muscleRaw; self.order = order
    }

    var muscle: MuscleGroup {
        MuscleGroup.from(code: muscleRaw)
    }

    var orderedSets: [LoggedSetModel] {
        (sets ?? []).sorted { $0.order < $1.order }
    }

    /// 1RM estimé de l'exercice sur la séance (meilleur set).
    var bestOneRM: Int {
        orderedSets.map { OneRepMax.estimate(weight: $0.weight, reps: $0.reps) }.max() ?? 0
    }
}

@Model
final class LoggedSetModel {
    var id: UUID = UUID()
    var reps: Int = 0
    var weight: Double = 0
    var rpe: Int?
    var order: Int = 0

    var exercise: LoggedExerciseModel?

    init(reps: Int, weight: Double, rpe: Int? = nil, order: Int = 0) {
        self.reps = reps; self.weight = weight; self.rpe = rpe; self.order = order
    }
}
