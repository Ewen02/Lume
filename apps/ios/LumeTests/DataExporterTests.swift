import Foundation
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
