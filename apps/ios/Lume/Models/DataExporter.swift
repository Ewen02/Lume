import Foundation
import SwiftData

/// Génère les exports de données utilisateur : CSV (journal lisible) + JSON (sauvegarde complète).
/// Pur (pas d'I/O réseau), testable. L'écriture fichier se fait dans la vue via `writeTemp`.
enum DataExporter {
    // MARK: CSV — journal alimentaire + poids

    static func foodCSV(_ foods: [LoggedFood], calendar _: Calendar = .current) -> String {
        var rows = ["date,repas,aliment,grammes,kcal,proteines_g,glucides_g,lipides_g"]
        for f in foods.sorted(by: { $0.date < $1.date }) {
            let cols = [
                Self.iso(f.date),
                f.meal.title,
                f.name,
                String(f.grams),
                String(f.kcal),
                String(f.protein),
                String(f.carbs),
                String(f.fat),
            ]
            rows.append(cols.map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    static func weightCSV(_ samples: [WeightSample]) -> String {
        var rows = ["date,poids_kg"]
        for s in samples.sorted(by: { $0.date < $1.date }) {
            rows.append([Self.iso(s.date), String(format: "%.1f", s.kg)].map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    /// Journal financier : montant en décimal sans symbole (importable en tableur).
    static func transactionsCSV(_ transactions: [FinanceTransaction]) -> String {
        var rows = ["date,type,categorie,montant_eur,note"]
        for t in transactions.sorted(by: { $0.date < $1.date }) {
            let cols = [
                Self.iso(t.date),
                t.kind.title,
                t.category.title,
                Money.plainDecimal(t.amountCents),
                t.note,
            ]
            rows.append(cols.map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    // MARK: JSON — sauvegarde complète

    static func backupJSON(profile: ProfileRecord?,
                           foods: [LoggedFood],
                           weights: [WeightSample],
                           favorites: [FavoriteFood],
                           sessions: [WorkoutSessionModel],
                           routines: [RoutineModel],
                           customExercises: [ExerciseModel],
                           transactions: [FinanceTransaction] = [],
                           recurring: [RecurringTransaction] = [],
                           budgets: [CategoryBudget] = []) throws -> Data
    {
        let backup = Backup(
            exportedAt: Self.iso(Date()),
            profile: profile.map(ProfileDTO.init),
            foods: foods.map(FoodDTO.init),
            weights: weights.map(WeightDTO.init),
            favorites: favorites.map(FavoriteDTO.init),
            workouts: sessions.map(SessionDTO.init),
            routines: routines.map(RoutineDTO.init),
            customExercises: customExercises.map(CustomExerciseDTO.init),
            transactions: transactions.map(TransactionDTO.init),
            recurring: recurring.map(RecurringDTO.init),
            budgets: budgets.map(BudgetDTO.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    // MARK: Restauration (import du backup JSON)

    /// Résultat lisible d'un import : combien d'éléments ont été restaurés (pour le retour UI).
    struct RestoreSummary: Equatable {
        var foods = 0, weights = 0, favorites = 0, workouts = 0
        var routines = 0, customExercises = 0, transactions = 0, recurring = 0, budgets = 0
        var profileRestored = false
        var total: Int {
            foods + weights + favorites + workouts + routines + customExercises + transactions + recurring + budgets
        }
    }

    enum RestoreError: LocalizedError {
        case invalidFormat
        var errorDescription: String? {
            switch self {
            case .invalidFormat: String(localized: "Ce fichier n'est pas une sauvegarde Lume valide.")
            }
        }
    }

    /// Décode un backup JSON sans toucher à la base (validation préalable possible avant restauration).
    static func decodeBackup(_ data: Data) throws -> Backup {
        do { return try JSONDecoder().decode(Backup.self, from: data) }
        catch { throw RestoreError.invalidFormat }
    }

    /// Restaure une sauvegarde dans le contexte : REMPLACE les données existantes (sémantique
    /// « je récupère mon backup sur un nouvel appareil »). N'inclut pas les réglages `@AppStorage`
    /// ni Apple Santé — seulement les modèles SwiftData. Idempotent : ré-importer le même backup
    /// redonne le même état.
    @MainActor
    @discardableResult
    static func restore(_ backup: Backup, into ctx: ModelContext) throws -> RestoreSummary {
        /// 1) Purge des modèles concernés (mêmes types que ceux du backup). On supprime objet par
        /// objet après fetch : plus robuste que `delete(model:where:)` (qui peut planter selon le store)
        /// et la cascade des relations (séances→exos→séries, routines→exos) s'applique correctement.
        func wipe<T: PersistentModel>(_: T.Type) {
            for object in (try? ctx.fetch(FetchDescriptor<T>())) ?? [] {
                ctx.delete(object)
            }
        }
        wipe(LoggedFood.self)
        wipe(WeightSample.self)
        wipe(FavoriteFood.self)
        wipe(WorkoutSessionModel.self) // cascade → exercices/séries
        wipe(RoutineModel.self) // cascade → exercices de routine
        // Exercices : on ne supprime QUE les custom (le catalogue seedé n'est pas « des données »).
        // Filtrage en mémoire (un #Predicate générique sur FetchDescriptor<T> est instable ici).
        for ex in (try? ctx.fetch(FetchDescriptor<ExerciseModel>())) ?? [] where ex.isCustom {
            ctx.delete(ex)
        }
        wipe(FinanceTransaction.self)
        wipe(RecurringTransaction.self)
        wipe(CategoryBudget.self)

        var summary = RestoreSummary()

        // 2) Profil : on met à jour l'existant s'il y en a un, sinon on en crée un.
        if let p = backup.profile {
            let existing = try? ctx.fetch(FetchDescriptor<ProfileRecord>())
            let record: ProfileRecord
            if let first = existing?.first { record = first }
            else { record = ProfileRecord(); ctx.insert(record) }
            record.name = p.name; record.sexRaw = p.sex; record.age = p.age
            record.heightCm = p.heightCm; record.weightKg = p.weightKg
            record.activityRaw = p.activity; record.goalRaw = p.goal
            summary.profileRestored = true
        }

        // 3) Journal alimentaire.
        for f in backup.foods {
            ctx.insert(LoggedFood(date: parseDate(f.date), meal: MealType(rawValue: f.meal) ?? .snack,
                                  name: f.name, grams: f.grams,
                                  kcal: f.kcal, protein: f.protein, carbs: f.carbs, fat: f.fat))
            summary.foods += 1
        }

        // 4) Poids.
        for w in backup.weights {
            ctx.insert(WeightSample(date: parseDate(w.date), kg: w.kg)); summary.weights += 1
        }

        // 5) Favoris.
        for fav in backup.favorites {
            ctx.insert(FavoriteFood(name: fav.name,
                                    per100g: Macros(kcal: fav.kcal, protein: fav.protein, carbs: fav.carbs, fat: fav.fat)))
            summary.favorites += 1
        }

        // 6) Séances (+ exercices + séries, en recâblant les relations).
        for s in backup.workouts {
            let session = WorkoutSessionModel(date: parseDate(s.date), durationSec: s.durationSec, title: s.title)
            ctx.insert(session)
            for (i, e) in s.exercises.enumerated() {
                let ex = LoggedExerciseModel(name: e.name, muscleRaw: e.muscle, order: i)
                ex.session = session
                ctx.insert(ex)
                for (j, set) in e.sets.enumerated() {
                    let m = LoggedSetModel(reps: set.reps, weight: set.weight, rpe: set.rpe, order: j)
                    m.exercise = ex
                    ctx.insert(m)
                }
            }
            summary.workouts += 1
        }

        // 7) Routines (+ exercices de routine).
        for r in backup.routines {
            let routine = RoutineModel(name: r.name, order: r.order)
            ctx.insert(routine)
            for (i, e) in r.exercises.enumerated() {
                let re = RoutineExerciseModel(exerciseName: e.name, muscleRaw: e.muscle,
                                              equipment: e.equipment, targetSets: e.targetSets,
                                              targetReps: e.targetReps, order: i)
                re.routine = routine
                ctx.insert(re)
            }
            summary.routines += 1
        }

        // 8) Exercices personnalisés.
        for e in backup.customExercises {
            ctx.insert(ExerciseModel(name: e.name, muscleRaw: e.muscle, equipment: e.equipment, isCustom: true))
            summary.customExercises += 1
        }

        // 9) Finances.
        for t in backup.transactions {
            ctx.insert(FinanceTransaction(date: parseDate(t.date), amountCents: t.amountCents,
                                          kind: TransactionKind(rawValue: t.kind) ?? .expense,
                                          category: ExpenseCategory(rawValue: t.category) ?? .other,
                                          note: t.note))
            summary.transactions += 1
        }
        for r in backup.recurring {
            ctx.insert(RecurringTransaction(label: r.label, amountCents: r.amountCents,
                                            kind: TransactionKind(rawValue: r.kind) ?? .expense,
                                            category: ExpenseCategory(rawValue: r.category) ?? .other,
                                            frequency: RecurrenceFrequency(rawValue: r.frequency) ?? .monthly,
                                            dayOfMonth: r.dayOfMonth, isActive: r.isActive))
            summary.recurring += 1
        }
        for b in backup.budgets {
            ctx.insert(CategoryBudget(category: ExpenseCategory(rawValue: b.category) ?? .other,
                                      monthlyLimitCents: b.monthlyLimitCents))
            summary.budgets += 1
        }

        try ctx.save()
        return summary
    }

    /// Parse une date ISO du backup ; repli sur « maintenant » si le format est inattendu
    /// (un backup légèrement abîmé ne doit pas perdre l'élément, juste sa date exacte).
    private static func parseDate(_ s: String) -> Date {
        sharedISOFormatter.date(from: s) ?? Date()
    }

    // MARK: Helpers

    private static func iso(_ date: Date) -> String {
        isoDate(date)
    }

    /// Échappe un champ CSV (guillemets si virgule, guillemet ou saut de ligne).
    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}

// MARK: - Formatter de date partagé (un seul, caché)

private let sharedISOFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private func isoDate(_ date: Date) -> String {
    sharedISOFormatter.string(from: date)
}

// MARK: - DTOs Codable (plats, sans SwiftData)

struct Backup: Codable {
    let exportedAt: String
    let profile: ProfileDTO?
    let foods: [FoodDTO]
    let weights: [WeightDTO]
    let favorites: [FavoriteDTO]
    let workouts: [SessionDTO]
    let routines: [RoutineDTO]
    let customExercises: [CustomExerciseDTO]
    let transactions: [TransactionDTO]
    let recurring: [RecurringDTO]
    let budgets: [BudgetDTO]
}

struct ProfileDTO: Codable {
    let name: String, sex: String, age: Int, heightCm: Int, weightKg: Double
    let activity: String, goal: String
    init(_ r: ProfileRecord) {
        name = r.name; sex = r.sexRaw; age = r.age; heightCm = r.heightCm; weightKg = r.weightKg
        activity = r.activityRaw; goal = r.goalRaw
    }
}

struct FoodDTO: Codable {
    let date: String, meal: String, name: String, grams: Int
    let kcal: Int, protein: Int, carbs: Int, fat: Int
    init(_ f: LoggedFood) {
        date = isoDate(f.date)
        meal = f.mealRaw; name = f.name; grams = f.grams
        kcal = f.kcal; protein = f.protein; carbs = f.carbs; fat = f.fat
    }
}

struct WeightDTO: Codable {
    let date: String, kg: Double
    init(_ s: WeightSample) {
        date = isoDate(s.date); kg = s.kg
    }
}

struct FavoriteDTO: Codable {
    let name: String, kcal: Int, protein: Int, carbs: Int, fat: Int
    init(_ f: FavoriteFood) {
        name = f.name; kcal = f.kcal; protein = f.protein; carbs = f.carbs; fat = f.fat
    }
}

struct SessionDTO: Codable {
    let date: String, title: String, durationSec: Int, exercises: [ExerciseDTO]
    init(_ s: WorkoutSessionModel) {
        date = isoDate(s.date)
        title = s.title; durationSec = s.durationSec
        exercises = s.orderedExercises.map(ExerciseDTO.init)
    }
}

struct ExerciseDTO: Codable {
    let name: String, muscle: String, sets: [SetDTO]
    init(_ e: LoggedExerciseModel) {
        name = e.name; muscle = e.muscleRaw; sets = e.orderedSets.map(SetDTO.init)
    }
}

struct SetDTO: Codable {
    let reps: Int, weight: Double, rpe: Int?
    init(_ s: LoggedSetModel) {
        reps = s.reps; weight = s.weight; rpe = s.rpe
    }
}

struct RoutineDTO: Codable {
    let name: String, order: Int, exercises: [RoutineExerciseDTO]
    init(_ r: RoutineModel) {
        name = r.name; order = r.order
        exercises = r.orderedExercises.map(RoutineExerciseDTO.init)
    }
}

struct RoutineExerciseDTO: Codable {
    let name: String, muscle: String, equipment: String, targetSets: Int, targetReps: String
    init(_ e: RoutineExerciseModel) {
        name = e.exerciseName; muscle = e.muscleRaw; equipment = e.equipment
        targetSets = e.targetSets; targetReps = e.targetReps
    }
}

struct CustomExerciseDTO: Codable {
    let name: String, muscle: String, equipment: String
    init(_ e: ExerciseModel) {
        name = e.name; muscle = e.muscleRaw; equipment = e.equipment
    }
}

// MARK: - DTOs Finance (montants en centimes Int pour fidélité)

struct TransactionDTO: Codable {
    let date: String, kind: String, category: String, amountCents: Int, note: String
    init(_ t: FinanceTransaction) {
        date = isoDate(t.date); kind = t.kindRaw; category = t.categoryRaw
        amountCents = t.amountCents; note = t.note
    }
}

struct RecurringDTO: Codable {
    let label: String, kind: String, category: String, amountCents: Int
    let frequency: String, dayOfMonth: Int, isActive: Bool
    init(_ r: RecurringTransaction) {
        label = r.label; kind = r.kindRaw; category = r.categoryRaw; amountCents = r.amountCents
        frequency = r.frequencyRaw; dayOfMonth = r.dayOfMonth; isActive = r.isActive
    }
}

struct BudgetDTO: Codable {
    let category: String, monthlyLimitCents: Int
    init(_ b: CategoryBudget) {
        category = b.categoryRaw; monthlyLimitCents = b.monthlyLimitCents
    }
}
