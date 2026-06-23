import Foundation

/// Bilan hebdomadaire (7 derniers jours) : jours suivis, moyenne kcal vs cible, séances muscu.
/// Logique extraite des vues, testable.
struct WeeklyGoals {
    /// Nombre de jours (sur 7) où au moins un repas a été enregistré.
    var trackedDays: Int
    /// Moyenne kcal/jour sur les jours renseignés.
    var avgKcal: Int
    /// Cible kcal quotidienne (depuis le profil/TDEE).
    var targetKcal: Int
    /// Nombre de séances muscu enregistrées sur la fenêtre.
    var workouts: Int
    /// Objectif de séances/semaine (par défaut 3).
    var workoutGoal: Int

    /// Progression de suivi (0...1) : jours suivis / 7.
    var trackingProgress: Double { Double(trackedDays) / 7.0 }
    /// Progression séances (0...1, plafonnée).
    var workoutProgress: Double {
        workoutGoal <= 0 ? 0 : min(1, Double(workouts) / Double(workoutGoal))
    }
    /// Écart à la cible kcal (négatif = sous la cible).
    var kcalDelta: Int { avgKcal - targetKcal }

    static func compute(foods: [LoggedFood],
                        sessions: [WorkoutSessionModel],
                        targetKcal: Int,
                        workoutGoal: Int = 3,
                        reference: Date = Date(),
                        calendar: Calendar = .current) -> WeeklyGoals
    {
        let today0 = calendar.startOfDay(for: reference)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today0) ?? today0

        // Jours distincts avec au moins un repas dans la fenêtre.
        let days = Set(
            foods
                .filter { $0.date >= weekStart }
                .map { calendar.startOfDay(for: $0.date) }
        )

        let week = WeeklyCalories.lastSevenDays(from: foods, reference: reference, calendar: calendar)
        let avg = WeeklyCalories.dailyAverage(of: week)

        let workouts = sessions.filter { $0.date >= weekStart }.count

        return WeeklyGoals(trackedDays: days.count, avgKcal: avg, targetKcal: targetKcal,
                           workouts: workouts, workoutGoal: workoutGoal)
    }
}
