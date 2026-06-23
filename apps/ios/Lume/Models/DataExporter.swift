import Foundation

/// Génère les exports de données utilisateur : CSV (journal lisible) + JSON (sauvegarde complète).
/// Pur (pas d'I/O réseau), testable. L'écriture fichier se fait dans la vue via `writeTemp`.
enum DataExporter {
    // MARK: CSV — journal alimentaire + poids

    static func foodCSV(_ foods: [LoggedFood], calendar: Calendar = .current) -> String {
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

    // MARK: JSON — sauvegarde complète

    static func backupJSON(profile: ProfileRecord?,
                           foods: [LoggedFood],
                           weights: [WeightSample],
                           favorites: [FavoriteFood],
                           sessions: [WorkoutSessionModel]) throws -> Data
    {
        let backup = Backup(
            exportedAt: Self.iso(Date()),
            profile: profile.map(ProfileDTO.init),
            foods: foods.map(FoodDTO.init),
            weights: weights.map(WeightDTO.init),
            favorites: favorites.map(FavoriteDTO.init),
            workouts: sessions.map(SessionDTO.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    // MARK: Helpers

    private static func iso(_ date: Date) -> String { isoDate(date) }

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

private func isoDate(_ date: Date) -> String { sharedISOFormatter.string(from: date) }

// MARK: - DTOs Codable (plats, sans SwiftData)

private struct Backup: Codable {
    let exportedAt: String
    let profile: ProfileDTO?
    let foods: [FoodDTO]
    let weights: [WeightDTO]
    let favorites: [FavoriteDTO]
    let workouts: [SessionDTO]
}

private struct ProfileDTO: Codable {
    let name: String, sex: String, age: Int, heightCm: Int, weightKg: Double
    let activity: String, goal: String
    init(_ r: ProfileRecord) {
        name = r.name; sex = r.sexRaw; age = r.age; heightCm = r.heightCm; weightKg = r.weightKg
        activity = r.activityRaw; goal = r.goalRaw
    }
}

private struct FoodDTO: Codable {
    let date: String, meal: String, name: String, grams: Int
    let kcal: Int, protein: Int, carbs: Int, fat: Int
    init(_ f: LoggedFood) {
        date = isoDate(f.date)
        meal = f.mealRaw; name = f.name; grams = f.grams
        kcal = f.kcal; protein = f.protein; carbs = f.carbs; fat = f.fat
    }
}

private struct WeightDTO: Codable {
    let date: String, kg: Double
    init(_ s: WeightSample) { date = isoDate(s.date); kg = s.kg }
}

private struct FavoriteDTO: Codable {
    let name: String, kcal: Int, protein: Int, carbs: Int, fat: Int
    init(_ f: FavoriteFood) {
        name = f.name; kcal = f.kcal; protein = f.protein; carbs = f.carbs; fat = f.fat
    }
}

private struct SessionDTO: Codable {
    let date: String, title: String, durationSec: Int, exercises: [ExerciseDTO]
    init(_ s: WorkoutSessionModel) {
        date = isoDate(s.date)
        title = s.title; durationSec = s.durationSec
        exercises = s.orderedExercises.map(ExerciseDTO.init)
    }
}

private struct ExerciseDTO: Codable {
    let name: String, muscle: String, sets: [SetDTO]
    init(_ e: LoggedExerciseModel) {
        name = e.name; muscle = e.muscleRaw; sets = e.orderedSets.map(SetDTO.init)
    }
}

private struct SetDTO: Codable {
    let reps: Int, weight: Double, rpe: Int?
    init(_ s: LoggedSetModel) { reps = s.reps; weight = s.weight; rpe = s.rpe }
}
