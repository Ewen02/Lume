import Foundation
import SwiftData

/// Exercice de la bibliothèque (persisté + CloudKit). Seedé au 1er lancement,
/// extensible par l'utilisateur (exercices custom).
/// Contraintes CloudKit : toutes les propriétés ont une valeur par défaut, aucune contrainte unique.
@Model
final class ExerciseModel {
    var id: UUID = UUID()
    var name: String = ""
    /// Clé stable du groupe musculaire (jamais le label localisé).
    var muscleRaw: String = MuscleGroup.chest.code
    var equipment: String = ""
    /// Exercice ajouté par l'utilisateur (vs seed par défaut) — utile pour l'édition/suppression.
    var isCustom: Bool = false
    var createdAt: Date = Date()

    init(name: String, muscleRaw: String, equipment: String, isCustom: Bool = false, createdAt: Date = Date()) {
        self.name = name; self.muscleRaw = muscleRaw; self.equipment = equipment
        self.isCustom = isCustom; self.createdAt = createdAt
    }

    convenience init(from e: Exercise, isCustom: Bool = true) {
        self.init(name: e.name, muscleRaw: e.primary.code, equipment: e.equipment, isCustom: isCustom)
    }

    /// Mappe vers la struct `Exercise` utilisée par l'UI (picker, cartes, séances).
    var asExercise: Exercise {
        Exercise(name: name, primary: MuscleGroup.from(code: muscleRaw), equipment: equipment)
    }
}

/// Insère la bibliothèque par défaut si le store est vide (1re ouverture).
@MainActor
func seedDefaultExercisesIfNeeded(_ context: ModelContext) {
    let existing = (try? context.fetch(FetchDescriptor<ExerciseModel>())) ?? []
    guard existing.isEmpty else { return }
    for e in Mock.exercises {
        context.insert(ExerciseModel(name: e.name, muscleRaw: e.primary.code,
                                     equipment: e.equipment, isCustom: false))
    }
}
