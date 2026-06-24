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
        let longest = WorkoutStreak.longestStreak(from: sessions.map(\.date), goal: max(1, goal), calendar: calendar)
        return BadgeStats(totalSessions: sessions.count, bestOneRM: bestOneRM,
                          longestWeeklyStreak: longest)
    }

    /// Stats nutrition : jours logués, plus long streak quotidien, jours équilibrés (3 macros ≥ 90 % cible).
    static func nutritionStats(from foods: [LoggedFood], target: Macros,
                               calendar: Calendar = .current) -> BadgeStats
    {
        // Regroupe les calories/macros par jour.
        var byDay: [Date: Macros] = [:]
        for f in foods {
            let day = calendar.startOfDay(for: f.date)
            byDay[day, default: .zero] = (byDay[day] ?? .zero) + f.macros
        }
        let loggedDays = byDay.count
        let longestDaily = StreakCalculator.longestStreak(from: foods.map(\.date), calendar: calendar)

        /// Jour « équilibré » : les 3 macros atteignent ≥ 90 % de la cible.
        func reached(_ value: Int, _ goal: Int) -> Bool {
            goal <= 0 || Double(value) >= Double(goal) * 0.9
        }
        let balanced = byDay.values.filter {
            reached($0.protein, target.protein) && reached($0.carbs, target.carbs) && reached($0.fat, target.fat)
        }.count

        return BadgeStats(loggedDays: loggedDays, longestDailyStreak: longestDaily, balancedDays: balanced)
    }

    /// Réconcilie les badges MUSCU : insère les `BadgeUnlock` manquants désormais atteints.
    /// Retourne les badges muscu fraîchement débloqués (vide si aucun).
    @discardableResult
    @MainActor
    static func reconcile(sessions: [WorkoutSessionModel], goal: Int, context: ModelContext,
                          date: Date = Date()) -> [Badge]
    {
        reconcileEarned(BadgeCatalog.unlocked(for: stats(from: sessions, goal: goal)),
                        domain: .workout, context: context, date: date)
    }

    /// Réconcilie les badges NUTRITION. Retourne les nouveaux badges nutrition (pour célébration).
    @discardableResult
    @MainActor
    static func reconcileNutrition(foods: [LoggedFood], target: Macros, context: ModelContext,
                                   date: Date = Date()) -> [Badge]
    {
        reconcileEarned(BadgeCatalog.unlocked(for: nutritionStats(from: foods, target: target)),
                        domain: .nutrition, context: context, date: date)
    }

    /// Insère les déblocages manquants pour un domaine donné, sans toucher à l'autre domaine.
    @MainActor
    private static func reconcileEarned(_ earned: Set<String>, domain: Badge.Domain,
                                        context: ModelContext, date: Date) -> [Badge]
    {
        // On ne considère que les badges du domaine concerné (les stats de l'autre sont à 0).
        let domainIDs = Set(BadgeCatalog.all(in: domain).map(\.id))
        let earnedInDomain = earned.intersection(domainIDs)

        let existing = (try? context.fetch(FetchDescriptor<BadgeUnlock>())) ?? []
        let alreadyHave = Set(existing.map(\.badgeID))

        let freshIDs = earnedInDomain.subtracting(alreadyHave)
        for id in freshIDs {
            context.insert(BadgeUnlock(badgeID: id, unlockedAt: date))
        }
        return BadgeCatalog.all.filter { freshIDs.contains($0.id) }
    }
}
