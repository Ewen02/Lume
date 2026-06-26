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
        FinanceTransaction.self, RecurringTransaction.self, CategoryBudget.self, FinanceProfile.self,
        FixedCharge.self,
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
        // Modèle enveloppe : seules les DÉPENSES VARIABLES (et le salaire en revenu) sont des
        // transactions. Loyer/charges/épargne vivent dans le profil (déduits, non matérialisés).
        let demo: [(Int, Int, TransactionKind, ExpenseCategory, String)] = [
            (1, 210_000, .income, .salary, "Salaire"),
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
        // Récurrente salaire : on amorce le curseur d'idempotence au salaire déjà seedé (jour 1 du mois
        // courant), sinon `materializeDue` recréerait une 2e transaction salaire → revenus doublés en preview.
        let salaryRule = RecurringTransaction(label: "Salaire", amountCents: 210_000, kind: .income,
                                              category: .salary, frequency: .monthly, dayOfMonth: 1)
        salaryRule.lastMaterializedDate = day(1)
        ctx.insert(salaryRule)
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
