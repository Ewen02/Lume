import Foundation

extension Mock {
    static let exercises: [Exercise] = [
        Exercise(name: "Développé couché", primary: .chest, equipment: "Barre"),
        Exercise(name: "Développé incliné haltères", primary: .chest, equipment: "Haltères"),
        Exercise(name: "Squat", primary: .legs, equipment: "Barre"),
        Exercise(name: "Soulevé de terre", primary: .back, equipment: "Barre"),
        Exercise(name: "Tractions", primary: .back, equipment: "Poids du corps"),
        Exercise(name: "Développé militaire", primary: .shoulders, equipment: "Barre"),
        Exercise(name: "Curl biceps", primary: .arms, equipment: "Haltères"),
        Exercise(name: "Gainage", primary: .core, equipment: "Poids du corps"),
    ]

    static var pushRoutine: Routine {
        Routine(name: "Push", exercises: [
            RoutineExercise(exercise: exercises[0], targetSets: 4, targetReps: "8-10"),
            RoutineExercise(exercise: exercises[1], targetSets: 3, targetReps: "10-12"),
            RoutineExercise(exercise: exercises[5], targetSets: 3, targetReps: "8-10"),
            RoutineExercise(exercise: exercises[7], targetSets: 3, targetReps: "45 s"),
        ])
    }

    static var routines: [Routine] {
        [pushRoutine,
         Routine(name: "Pull", exercises: [
             RoutineExercise(exercise: exercises[3], targetSets: 3, targetReps: "5"),
             RoutineExercise(exercise: exercises[4], targetSets: 4, targetReps: "max"),
             RoutineExercise(exercise: exercises[6], targetSets: 3, targetReps: "12"),
         ]),
         Routine(name: "Legs", exercises: [
             RoutineExercise(exercise: exercises[2], targetSets: 5, targetReps: "5"),
         ])]
    }

    static var activeSession: [ExerciseSession] {
        [ExerciseSession(exercise: exercises[0], sets: [
            SetEntry(reps: 12, weight: 60, rpe: 7, done: true),
            SetEntry(reps: 10, weight: 70, rpe: 8, done: true),
            SetEntry(reps: 8, weight: 75, rpe: 9, done: false),
        ]),
        ExerciseSession(exercise: exercises[1], sets: [
            SetEntry(reps: 12, weight: 22, rpe: 7, done: false),
            SetEntry(reps: 12, weight: 22, rpe: nil, done: false),
        ])]
    }

    static var benchPR: [PRPoint] {
        let cal = Calendar.current
        let vals: [Double] = [78, 80, 82, 85, 86, 88, 90, 92, 94]
        return vals.enumerated().map { i, v in
            PRPoint(date: cal.date(byAdding: .weekOfYear, value: -(vals.count - 1 - i), to: Date())!, oneRM: v)
        }
    }
}
