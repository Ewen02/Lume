import Foundation
import SwiftData

/// Évalue les badges débloqués depuis les séances, persiste les nouveaux déblocages,
/// et renvoie ceux fraîchement obtenus (pour l'animation de fin de séance).
enum BadgeEvaluator {
    /// Calcule les stats nécessaires aux badges à partir des séances persistées.
    static func stats(from sessions: [WorkoutSessionModel], goal: Int,
                      calendar: Calendar = .current) -> BadgeStats
    {
        let bestOneRM = sessions
            .flatMap { $0.orderedExercises.map(\.bestOneRM) }
            .max() ?? 0
        let totalVolume = sessions.reduce(0) { acc, s in
            acc + s.orderedExercises.reduce(0) { exAcc, ex in
                exAcc + ex.orderedSets.reduce(0) { $0 + Int($1.weight) * $1.reps }
            }
        }
        let longest = WorkoutStreak.longestStreak(from: sessions.map(\.date), goal: max(1, goal), calendar: calendar)
        return BadgeStats(totalSessions: sessions.count, bestOneRM: bestOneRM,
                          longestWeeklyStreak: longest, totalVolume: totalVolume)
    }

    /// Réconcilie les badges : insère les `BadgeUnlock` manquants pour les badges désormais atteints.
    /// Retourne les badges fraîchement débloqués (vide si aucun).
    @discardableResult
    @MainActor
    static func reconcile(sessions: [WorkoutSessionModel], goal: Int, context: ModelContext,
                          date: Date = Date()) -> [Badge]
    {
        let earned = BadgeCatalog.unlocked(for: stats(from: sessions, goal: goal))
        let existing = (try? context.fetch(FetchDescriptor<BadgeUnlock>())) ?? []
        let alreadyHave = Set(existing.map(\.badgeID))

        let freshIDs = earned.subtracting(alreadyHave)
        for id in freshIDs {
            context.insert(BadgeUnlock(badgeID: id, unlockedAt: date))
        }
        // Conserve l'ordre du catalogue pour l'affichage.
        return BadgeCatalog.all.filter { freshIDs.contains($0.id) }
    }
}
