import Foundation
import SwiftData

/// Container SwiftData de l'app, synchronisé via CloudKit (base privée par compte iCloud).
///
/// ⚠️ Xcode : activer la capability **iCloud → CloudKit** + **Background Modes → Remote notifications**
/// sur la cible, sinon `.automatic` échoue au lancement.
enum LumeStore {
    static let schema = Schema([
        LoggedFood.self, WaterLog.self, WeightSample.self, ProfileRecord.self,
        FavoriteFood.self,
        WorkoutSessionModel.self, LoggedExerciseModel.self, LoggedSetModel.self,
        RoutineModel.self, RoutineExerciseModel.self, ExerciseModel.self,
        BadgeUnlock.self,
    ])

    static let shared: ModelContainer = {
        // ⚠️ CloudKit désactivé (.none) pour tourner avec une Personal Team (compte Apple gratuit).
        // `.automatic` nécessite l'entitlement CloudKit (compte payant) sinon `fatalError` au lancement.
        // Restaurer `cloudKitDatabase: .automatic` une fois le compte Apple Developer payant en place.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        do { return try ModelContainer(for: schema, configurations: [config]) }
        catch { fatalError("Échec d'initialisation du ModelContainer : \(error)") }
    }()

    /// Container en mémoire pour les #Preview, pré-rempli avec des données de démo.
    @MainActor static let preview: ModelContainer = {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let ctx = container.mainContext
        for meal in Mock.meals {
            for it in meal.items {
                ctx.insert(LoggedFood(meal: meal.type, name: it.name, grams: it.grams,
                                      kcal: it.macros.kcal, protein: it.macros.protein,
                                      carbs: it.macros.carbs, fat: it.macros.fat))
            }
        }
        ctx.insert(WaterLog(day: Calendar.current.startOfDay(for: Date()), glasses: 5))
        ctx.insert(ProfileRecord(from: Mock.profile))
        // Séance muscu de démo
        let session = WorkoutSessionModel(date: Date(), durationSec: 2535, title: "Push")
        ctx.insert(session)
        let bench = LoggedExerciseModel(name: "Développé couché", muscleRaw: MuscleGroup.chest.code, order: 0)
        bench.session = session
        ctx.insert(bench)
        for (i, set) in [(12, 60.0), (10, 70.0), (8, 75.0)].enumerated() {
            let s = LoggedSetModel(reps: set.0, weight: set.1, rpe: 7 + i, order: i)
            s.exercise = bench
            ctx.insert(s)
        }
        seedDefaultRoutines(ctx)
        seedDefaultExercisesIfNeeded(ctx)
        return container
    }()
}
