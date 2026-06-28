import Foundation
import SwiftData

/// Container SwiftData de l'app. Synchronisé via CloudKit (base privée par compte iCloud) quand le
/// flag `CLOUDKIT_ENABLED` est posé ; sinon purement local (compte Apple gratuit). Voir `cloudKitMode`.
///
/// ⚠️ Pour CloudKit : activer la capability **iCloud → CloudKit** + **Background Modes → Remote
/// notifications** sur la cible, restaurer `Lume.entitlements`, et poser `CLOUDKIT_ENABLED`.
enum LumeStore {
    static let schema = Schema([
        LoggedFood.self, WaterLog.self, WeightSample.self, ProfileRecord.self,
        FavoriteFood.self, RecipeModel.self, RecipeIngredientModel.self,
        WorkoutSessionModel.self, LoggedExerciseModel.self, LoggedSetModel.self,
        RoutineModel.self, RoutineExerciseModel.self, ExerciseModel.self,
        BadgeUnlock.self,
        FinanceTransaction.self, RecurringTransaction.self, CategoryBudget.self, FinanceProfile.self,
        FixedCharge.self,
    ])

    /// Mode CloudKit du store selon la capability disponible :
    /// - avec le flag de compilation `CLOUDKIT_ENABLED` (compte Apple Developer payant + entitlement
    ///   iCloud activé sur la cible) → `.automatic` : sync iCloud privée par compte, multi-appareils.
    /// - sinon (Personal Team gratuite) → `.none` : données purement locales.
    ///
    /// ⚠️ Pour activer CloudKit : (1) restaurer `Lume.entitlements` depuis le `.full-account.bak`,
    /// (2) cocher iCloud → CloudKit + Background Modes → Remote notifications sur la cible,
    /// (3) ajouter `CLOUDKIT_ENABLED` dans Build Settings → Active Compilation Conditions.
    private static var cloudKitMode: ModelConfiguration.CloudKitDatabase {
        #if CLOUDKIT_ENABLED
            .automatic
        #else
            .none
        #endif
    }

    static let shared: ModelContainer = {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: cloudKitMode)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Filet anti-crash-loop : si le store local est corrompu ou qu'une migration de schéma
            // échoue, on ne `fatalError` PAS (sinon l'app crashe en boucle au lancement, sans recours).
            // On repart d'un store neuf (les données locales perdues sont, le cas échéant, récupérables
            // via l'import d'une sauvegarde JSON — cf. DataExporter.restore).
            #if DEBUG
                print("⚠️ ModelContainer init échoué (\(error)). Reconstruction d'un store vierge.")
            #endif
            return recreatedContainer(config: config)
        }
    }()

    /// Recrée un container après échec : tente d'effacer le store sur disque puis ré-ouvre.
    /// Dernier recours = store en mémoire (l'app reste utilisable, sans persistance, plutôt qu'un crash).
    private static func recreatedContainer(config: ModelConfiguration) -> ModelContainer {
        if let url = config.url as URL?, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        let fresh = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: cloudKitMode)
        if let container = try? ModelContainer(for: schema, configurations: [fresh]) { return container }
        // Tout a échoué : store en mémoire pour que l'app démarre quand même.
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // En dernier recours, si même la mémoire échoue, on laisse remonter (cas pathologique).
        return try! ModelContainer(for: schema, configurations: [memory])
    }

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
        seedFinanceDemo(ctx)
        return container
    }()

    /// Données de démo Finance pour les #Preview du module Argent (mois courant).
    @MainActor private static func seedFinanceDemo(_ ctx: ModelContext) {
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        func day(_ d: Int) -> Date {
            cal.date(byAdding: .day, value: d - 1, to: monthStart) ?? monthStart
        }
        // Modèle enveloppe : seules les DÉPENSES VARIABLES sont des transactions. Revenu, loyer,
        // charges et épargne vivent dans le profil (déduits, jamais matérialisés) → pas de doublons.
        let demo: [(Int, Int, TransactionKind, ExpenseCategory, String)] = [
            (3, 4290, .expense, .restaurant, "Restaurant midi"),
            (5, 8750, .expense, .groceries, "Courses"),
            (9, 3420, .expense, .transport, "Essence"),
            (12, 5600, .expense, .leisure, "Cinéma + sortie"),
        ]
        for (d, cents, kind, cat, note) in demo {
            ctx.insert(FinanceTransaction(date: day(d), amountCents: cents, kind: kind, category: cat, note: note))
        }
        ctx.insert(CategoryBudget(category: .groceries, monthlyLimitCents: 40000))
        ctx.insert(CategoryBudget(category: .restaurant, monthlyLimitCents: 15000))
        // Une vraie récurrente légitime : une DÉPENSE fixe manuelle (abonnement), pas le salaire.
        ctx.insert(RecurringTransaction(label: "Spotify", amountCents: 1099, kind: .expense,
                                        category: .subscriptions, frequency: .monthly, dayOfMonth: 5))
        // Profil de démo : revenu 2 100 €, loyer 650 €, charges 110 €, épargne 300 €.
        let profile = FinanceProfile(monthlyNetIncomeCents: 210_000, rentCents: 65000,
                                     fixedChargesCents: 11000, monthlySavingCents: 30000)
        ctx.insert(profile)
        // Détail des charges (somme = 110 €) conservé pour un reconfig fidèle.
        ctx.insert(FixedCharge(label: "Assurance", amountCents: 6000, category: .subscriptions))
        ctx.insert(FixedCharge(label: "Internet", amountCents: 5000, category: .subscriptions))
        // Les #Preview montrent l'écran : budget global = dépenses variables, flag posé.
        UserDefaults.standard.set(profile.variableBudgetCents, forKey: FinanceSettings.globalBudgetKey)
        UserDefaults.standard.set(true, forKey: FinanceSettings.setupDoneKey)
    }
}
