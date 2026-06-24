import Foundation

extension Mock {
    /// Base d'exercices par défaut (seedée au 1er lancement, extensible par l'utilisateur).
    /// ⚠️ Les 8 premiers gardent leur ordre : `pushRoutine`/`routines`/`activeSession` les référencent par index.
    static let exercises: [Exercise] = [
        // — Index 0–7 figés (référencés par les routines/séances de démo) —
        Exercise(name: "Développé couché", primary: .chest, equipment: "Barre"),
        Exercise(name: "Développé incliné haltères", primary: .chest, equipment: "Haltères"),
        Exercise(name: "Squat", primary: .legs, equipment: "Barre"),
        Exercise(name: "Soulevé de terre", primary: .back, equipment: "Barre"),
        Exercise(name: "Tractions", primary: .back, equipment: "Poids du corps"),
        Exercise(name: "Développé militaire", primary: .shoulders, equipment: "Barre"),
        Exercise(name: "Curl biceps", primary: .arms, equipment: "Haltères"),
        Exercise(name: "Gainage", primary: .core, equipment: "Poids du corps"),

        // — Pectoraux —
        Exercise(name: "Développé couché haltères", primary: .chest, equipment: "Haltères"),
        Exercise(name: "Développé incliné barre", primary: .chest, equipment: "Barre"),
        Exercise(name: "Écarté couché haltères", primary: .chest, equipment: "Haltères"),
        Exercise(name: "Écarté à la poulie", primary: .chest, equipment: "Poulie"),
        Exercise(name: "Développé à la machine", primary: .chest, equipment: "Machine"),
        Exercise(name: "Pompes", primary: .chest, equipment: "Poids du corps"),
        Exercise(name: "Dips", primary: .chest, equipment: "Poids du corps"),

        // — Dos —
        Exercise(name: "Rowing barre", primary: .back, equipment: "Barre"),
        Exercise(name: "Rowing haltère", primary: .back, equipment: "Haltères"),
        Exercise(name: "Tirage vertical", primary: .back, equipment: "Poulie"),
        Exercise(name: "Tirage horizontal", primary: .back, equipment: "Poulie"),
        Exercise(name: "Soulevé de terre roumain", primary: .back, equipment: "Barre"),
        Exercise(name: "Shrugs", primary: .back, equipment: "Haltères"),

        // — Jambes —
        Exercise(name: "Presse à cuisses", primary: .legs, equipment: "Machine"),
        Exercise(name: "Fentes", primary: .legs, equipment: "Haltères"),
        Exercise(name: "Leg extension", primary: .legs, equipment: "Machine"),
        Exercise(name: "Leg curl", primary: .legs, equipment: "Machine"),
        Exercise(name: "Hip thrust", primary: .legs, equipment: "Barre"),
        Exercise(name: "Mollets debout", primary: .legs, equipment: "Machine"),
        Exercise(name: "Squat bulgare", primary: .legs, equipment: "Haltères"),

        // — Épaules —
        Exercise(name: "Développé haltères épaules", primary: .shoulders, equipment: "Haltères"),
        Exercise(name: "Élévations latérales", primary: .shoulders, equipment: "Haltères"),
        Exercise(name: "Oiseau (deltoïde postérieur)", primary: .shoulders, equipment: "Haltères"),
        Exercise(name: "Face pull", primary: .shoulders, equipment: "Poulie"),
        Exercise(name: "Élévations frontales", primary: .shoulders, equipment: "Haltères"),

        // — Bras —
        Exercise(name: "Curl barre", primary: .arms, equipment: "Barre"),
        Exercise(name: "Curl marteau", primary: .arms, equipment: "Haltères"),
        Exercise(name: "Extension triceps poulie", primary: .arms, equipment: "Poulie"),
        Exercise(name: "Barre au front", primary: .arms, equipment: "Barre"),
        Exercise(name: "Curl pupitre", primary: .arms, equipment: "Machine"),
        Exercise(name: "Kickback triceps", primary: .arms, equipment: "Haltères"),

        // — Gainage / abdos —
        Exercise(name: "Crunch", primary: .core, equipment: "Poids du corps"),
        Exercise(name: "Relevé de jambes", primary: .core, equipment: "Poids du corps"),
        Exercise(name: "Gainage latéral", primary: .core, equipment: "Poids du corps"),
        Exercise(name: "Roue abdominale", primary: .core, equipment: "Matériel"),
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
}
