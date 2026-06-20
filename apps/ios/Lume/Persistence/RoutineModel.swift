import Foundation
import SwiftData

/// Routine / template d'entraînement réutilisable (persisté + CloudKit).
@Model
final class RoutineModel {
    var id: UUID = UUID()
    var name: String = ""
    var order: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \RoutineExerciseModel.routine)
    var exercises: [RoutineExerciseModel]? = []

    init(name: String, order: Int = 0) {
        self.name = name; self.order = order
    }

    var orderedExercises: [RoutineExerciseModel] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    /// Mappe vers la struct `Routine` utilisée par l'UI (RoutineCard, RoutineDetailView).
    var asRoutine: Routine {
        Routine(name: name, exercises: orderedExercises.map {
            RoutineExercise(
                exercise: Exercise(name: $0.exerciseName,
                                   primary: MuscleGroup.from(code: $0.muscleRaw),
                                   equipment: $0.equipment),
                targetSets: $0.targetSets,
                targetReps: $0.targetReps
            )
        })
    }
}

@Model
final class RoutineExerciseModel {
    var id: UUID = UUID()
    var exerciseName: String = ""
    var muscleRaw: String = MuscleGroup.chest.code
    var equipment: String = ""
    var targetSets: Int = 3
    var targetReps: String = "8-12"
    var order: Int = 0

    var routine: RoutineModel?

    init(exerciseName: String, muscleRaw: String, equipment: String,
         targetSets: Int, targetReps: String, order: Int = 0)
    {
        self.exerciseName = exerciseName; self.muscleRaw = muscleRaw; self.equipment = equipment
        self.targetSets = targetSets; self.targetReps = targetReps; self.order = order
    }
}

/// Insère les routines par défaut si le store n'en contient aucune (1re ouverture).
/// Les routines deviennent alors de vraies données persistées (éditables, synchronisées).
@MainActor
func seedDefaultRoutinesIfNeeded(_ context: ModelContext) {
    let existing = (try? context.fetch(FetchDescriptor<RoutineModel>())) ?? []
    guard existing.isEmpty else { return }
    for (i, routine) in Mock.routines.enumerated() {
        let model = RoutineModel(name: routine.name, order: i)
        context.insert(model)
        for (j, re) in routine.exercises.enumerated() {
            let m = RoutineExerciseModel(
                exerciseName: re.exercise.name,
                muscleRaw: re.exercise.primary.code,
                equipment: re.exercise.equipment,
                targetSets: re.targetSets,
                targetReps: re.targetReps,
                order: j
            )
            m.routine = model
            context.insert(m)
        }
    }
}
