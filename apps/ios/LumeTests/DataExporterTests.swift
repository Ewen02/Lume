import Foundation
import SwiftData
import Testing
@testable import Lume

/// Vérifie que l'export couvre bien les données utilisateur — en particulier les routines et
/// exercices custom, longtemps absents de la « sauvegarde complète ».
struct DataExporterTests {
    private func json(routines: [RoutineModel] = [], customExercises: [ExerciseModel] = [],
                      foods: [LoggedFood] = []) throws -> String
    {
        let data = try DataExporter.backupJSON(profile: nil, foods: foods, weights: [],
                                               favorites: [], sessions: [],
                                               routines: routines, customExercises: customExercises)
        return String(decoding: data, as: UTF8.self)
    }

    @Test func backupIncludesRoutines() throws {
        let routine = RoutineModel(name: "Push A", order: 0)
        routine.exercises = [RoutineExerciseModel(exerciseName: "Développé couché",
                                                  muscleRaw: MuscleGroup.chest.code,
                                                  equipment: "Barre", targetSets: 4, targetReps: "6-8")]
        let out = try json(routines: [routine])
        #expect(out.contains("Push A"))
        #expect(out.contains("Développé couché"))
        #expect(out.contains("\"routines\""))
    }

    @Test func backupIncludesCustomExercises() throws {
        let ex = ExerciseModel(name: "Tirage poulie custom", muscleRaw: MuscleGroup.back.code,
                               equipment: "Poulie", isCustom: true)
        let out = try json(customExercises: [ex])
        #expect(out.contains("Tirage poulie custom"))
        #expect(out.contains("\"customExercises\""))
    }

    @Test func backupKeysPresentEvenWhenEmpty() throws {
        let out = try json()
        // Le contrat de la « sauvegarde complète » : les sections existent toujours.
        #expect(out.contains("\"routines\""))
        #expect(out.contains("\"customExercises\""))
        #expect(out.contains("\"favorites\""))
        #expect(out.contains("\"transactions\""))
        #expect(out.contains("\"recurring\""))
        #expect(out.contains("\"budgets\""))
    }

    @Test func backupIncludesTransactions() throws {
        let tx = FinanceTransaction(date: Date(), amountCents: 4290, kind: .expense, category: .restaurant, note: "Resto midi")
        let data = try DataExporter.backupJSON(profile: nil, foods: [], weights: [], favorites: [],
                                               sessions: [], routines: [], customExercises: [],
                                               transactions: [tx])
        let out = String(decoding: data, as: UTF8.self)
        #expect(out.contains("Resto midi"))
        #expect(out.contains("4290")) // montant en centimes (fidélité)
    }

    @Test func transactionsCSVHasHeaderAndRow() {
        let tx = FinanceTransaction(date: Date(timeIntervalSince1970: 1_700_000_000), amountCents: 1250,
                             kind: .expense, category: .food, note: "Pain")
        let csv = DataExporter.transactionsCSV([tx])
        #expect(csv.hasPrefix("date,type,categorie,montant_eur,note"))
        #expect(csv.contains("Pain"))
        #expect(csv.contains("12.50")) // décimal sans symbole
    }

    @Test func foodCSVHasHeaderAndRow() {
        let food = LoggedFood(date: Date(timeIntervalSince1970: 1_700_000_000), meal: .lunch,
                              name: "Riz", grams: 200, kcal: 260, protein: 6, carbs: 56, fat: 0)
        let csv = DataExporter.foodCSV([food])
        #expect(csv.hasPrefix("date,repas,aliment,grammes,kcal"))
        #expect(csv.contains("Riz"))
    }
}

// MARK: - Round-trip import : backupJSON → decodeBackup → restore

/// Sérialisé + container UNIQUE partagé : SwiftData trap si l'on instancie plusieurs `ModelContainer`
/// sur le même schéma dans un même process. On crée donc le container une seule fois, et chaque test
/// repart d'un contexte vide (la restauration purge déjà tout en début d'opération).
@MainActor
@Suite(.serialized)
struct DataImportTests {
    /// Container UNIQUE pour tout le process (créé une seule fois) : instancier plusieurs
    /// `ModelContainer` sur le même schéma fait planter SwiftData.
    private static let sharedContainer: ModelContainer = {
        let config = ModelConfiguration(schema: LumeStore.schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: LumeStore.schema, configurations: [config])
    }()

    /// Contexte du container partagé, vidé au préalable pour repartir d'un état propre.
    private func freshContext() throws -> ModelContext {
        let ctx = Self.sharedContainer.mainContext
        for object in (try? ctx.fetch(FetchDescriptor<LoggedFood>())) ?? [] { ctx.delete(object) }
        for object in (try? ctx.fetch(FetchDescriptor<WorkoutSessionModel>())) ?? [] { ctx.delete(object) }
        for object in (try? ctx.fetch(FetchDescriptor<FinanceTransaction>())) ?? [] { ctx.delete(object) }
        try? ctx.save()
        return ctx
    }

    @Test func decodeRejectsGarbage() {
        let garbage = Data("ceci n'est pas un backup".utf8)
        #expect(throws: DataExporter.RestoreError.self) {
            _ = try DataExporter.decodeBackup(garbage)
        }
    }

    @Test func restoreRoundTripFood() throws {
        // 1) Source : un repas connu.
        let food = LoggedFood(date: Date(timeIntervalSince1970: 1_700_000_000), meal: .dinner,
                              name: "Saumon", grams: 150, kcal: 280, protein: 30, carbs: 0, fat: 18)
        let data = try DataExporter.backupJSON(profile: nil, foods: [food], weights: [], favorites: [],
                                               sessions: [], routines: [], customExercises: [])
        // 2) Restaure dans un container neuf.
        let ctx = try freshContext()
        let backup = try DataExporter.decodeBackup(data)
        let summary = try DataExporter.restore(backup, into: ctx)
        // 3) Vérifie le contenu restauré.
        #expect(summary.foods == 1)
        let restored = try ctx.fetch(FetchDescriptor<LoggedFood>())
        #expect(restored.count == 1)
        #expect(restored.first?.name == "Saumon")
        #expect(restored.first?.kcal == 280)
        #expect(restored.first?.meal == .dinner)
    }

    @Test func restoreRoundTripWorkoutWithSets() throws {
        let session = WorkoutSessionModel(date: Date(), durationSec: 3600, title: "Push A")
        let ex = LoggedExerciseModel(name: "Développé couché", muscleRaw: MuscleGroup.chest.code, order: 0)
        ex.session = session
        ex.sets = [LoggedSetModel(reps: 8, weight: 80, rpe: 8, order: 0),
                   LoggedSetModel(reps: 6, weight: 85, rpe: 9, order: 1)]
        session.exercises = [ex]

        let data = try DataExporter.backupJSON(profile: nil, foods: [], weights: [], favorites: [],
                                               sessions: [session], routines: [], customExercises: [])
        let ctx = try freshContext()
        let summary = try DataExporter.restore(try DataExporter.decodeBackup(data), into: ctx)

        #expect(summary.workouts == 1)
        let sessions = try ctx.fetch(FetchDescriptor<WorkoutSessionModel>())
        #expect(sessions.count == 1)
        let restoredEx = sessions.first?.orderedExercises ?? []
        #expect(restoredEx.count == 1)
        #expect(restoredEx.first?.name == "Développé couché")
        // Les séries et leur ordre/charge doivent survivre au round-trip.
        let sets = restoredEx.first?.orderedSets ?? []
        #expect(sets.count == 2)
        #expect(sets.first?.weight == 80)
        #expect(sets.last?.reps == 6)
    }

    @Test func restoreRoundTripFinance() throws {
        let tx = FinanceTransaction(date: Date(), amountCents: 4290, kind: .expense, category: .restaurant, note: "Resto")
        let data = try DataExporter.backupJSON(profile: nil, foods: [], weights: [], favorites: [],
                                               sessions: [], routines: [], customExercises: [],
                                               transactions: [tx])
        let ctx = try freshContext()
        let summary = try DataExporter.restore(try DataExporter.decodeBackup(data), into: ctx)
        #expect(summary.transactions == 1)
        let restored = try ctx.fetch(FetchDescriptor<FinanceTransaction>())
        #expect(restored.first?.amountCents == 4290)
        #expect(restored.first?.category == .restaurant)
        #expect(restored.first?.note == "Resto")
    }

    @Test func restoreReplacesExistingData() throws {
        let ctx = try freshContext()
        // Données pré-existantes (qui doivent disparaître à la restauration).
        ctx.insert(LoggedFood(meal: .lunch, name: "Ancien repas", grams: 100, kcal: 100, protein: 0, carbs: 0, fat: 0))
        try ctx.save()

        // Backup avec UN repas différent.
        let food = LoggedFood(meal: .breakfast, name: "Nouveau repas", grams: 50, kcal: 200, protein: 5, carbs: 30, fat: 5)
        let data = try DataExporter.backupJSON(profile: nil, foods: [food], weights: [], favorites: [],
                                               sessions: [], routines: [], customExercises: [])
        try DataExporter.restore(try DataExporter.decodeBackup(data), into: ctx)

        // L'ancien repas est remplacé, pas cumulé.
        let restored = try ctx.fetch(FetchDescriptor<LoggedFood>())
        #expect(restored.count == 1)
        #expect(restored.first?.name == "Nouveau repas")
    }

    @Test func restoreIsIdempotent() throws {
        let food = LoggedFood(meal: .snack, name: "Pomme", grams: 120, kcal: 62, protein: 0, carbs: 16, fat: 0)
        let data = try DataExporter.backupJSON(profile: nil, foods: [food], weights: [], favorites: [],
                                               sessions: [], routines: [], customExercises: [])
        let ctx = try freshContext()
        let backup = try DataExporter.decodeBackup(data)
        // Deux restaurations successives du même backup → même état (pas de doublon).
        try DataExporter.restore(backup, into: ctx)
        try DataExporter.restore(backup, into: ctx)
        let restored = try ctx.fetch(FetchDescriptor<LoggedFood>())
        #expect(restored.count == 1)
    }
}
