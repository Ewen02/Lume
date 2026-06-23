import SwiftUI

enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Pectoraux", back = "Dos", legs = "Jambes"
    case shoulders = "Épaules", arms = "Bras", core = "Gainage"
    var id: String {
        rawValue
    }

    /// Clé stable non-localisée (utilisée pour la persistance, jamais le rawValue/label).
    var code: String {
        switch self {
        case .chest: "chest"; case .back: "back"; case .legs: "legs"
        case .shoulders: "shoulders"; case .arms: "arms"; case .core: "core"
        }
    }

    static func from(code: String) -> MuscleGroup {
        switch code {
        case "back": .back; case "legs": .legs; case "shoulders": .shoulders
        case "arms": .arms; case "core": .core; default: .chest
        }
    }

    var tint: Color {
        switch self {
        case .chest: LumeColor.protein
        case .back: LumeColor.fat
        case .legs: LumeColor.success
        case .shoulders: LumeColor.carbs
        case .arms: LumeColor.warning
        case .core: LumeColor.muted
        }
    }
}

struct Exercise: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var primary: MuscleGroup
    var equipment: String
}

struct SetEntry: Identifiable, Equatable {
    let id = UUID()
    var reps: Int
    var weight: Double
    var rpe: Int?
    var done: Bool = false
}

/// Un exercice dans une séance active (avec ses séries).
struct ExerciseSession: Identifiable {
    let id = UUID()
    var exercise: Exercise
    var sets: [SetEntry]

    /// Meilleur 1RM estimé sur les séries effectuées (kg). 0 si aucune.
    var bestOneRM: Int {
        sets.filter { $0.done }.map { OneRepMax.estimate(weight: $0.weight, reps: $0.reps) }.max() ?? 0
    }
}

struct RoutineExercise: Identifiable {
    let id = UUID()
    var exercise: Exercise
    var targetSets: Int
    var targetReps: String
}

struct Routine: Identifiable {
    /// Stable quand la routine vient d'un `RoutineModel` persisté (évite la ré-identité à chaque rendu).
    var id: UUID = .init()
    var name: String
    var exercises: [RoutineExercise]
    var muscles: String {
        let groups = Set(exercises.map { $0.exercise.primary.rawValue })
        return groups.sorted().joined(separator: " · ")
    }

    /// Séance active vierge prête à remplir : un exercice par exercice de la routine,
    /// avec `targetSets` séries vides (reps/poids à 0, non cochées).
    var emptySession: [ExerciseSession] {
        exercises.map { ex in
            ExerciseSession(exercise: ex.exercise,
                            sets: (0 ..< max(1, ex.targetSets)).map { _ in
                                SetEntry(reps: 0, weight: 0, rpe: nil, done: false)
                            })
        }
    }
}

struct PRPoint: Identifiable {
    let id = UUID()
    var date: Date
    var oneRM: Double
}
