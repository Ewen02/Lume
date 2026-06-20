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
}

struct RoutineExercise: Identifiable {
    let id = UUID()
    var exercise: Exercise
    var targetSets: Int
    var targetReps: String
}

struct Routine: Identifiable {
    let id = UUID()
    var name: String
    var exercises: [RoutineExercise]
    var muscles: String {
        let groups = Set(exercises.map { $0.exercise.primary.rawValue })
        return groups.sorted().joined(separator: " · ")
    }
}

struct PRPoint: Identifiable {
    let id = UUID()
    var date: Date
    var oneRM: Double
}
