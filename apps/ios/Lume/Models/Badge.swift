import SwiftUI

/// Définition d'un badge (jalon). Catalogue statique ; le déblocage est persisté
/// via `BadgeUnlock`. `id` est stable (clé de persistance).
struct Badge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: AppIcon
    let tint: Color

    /// Domaine d'appartenance (sépare les badges muscu des badges nutrition à l'affichage).
    enum Domain: String { case workout, nutrition }

    enum Category: String, CaseIterable, Identifiable {
        /// Muscu
        case attendance, force, regularity
        // Nutrition
        case logging, streak, balance
        var id: String {
            rawValue
        }

        var label: String {
            switch self {
            case .attendance: "Assiduité"
            case .force: "Force"
            case .regularity: "Régularité"
            case .logging: "Suivi"
            case .streak: "Série"
            case .balance: "Équilibre"
            }
        }
    }

    let category: Category
    var domain: Badge.Domain = .workout
}

/// Stats agrégées nécessaires pour évaluer les badges (muscu + nutrition).
struct BadgeStats {
    /// — Muscu —
    var totalSessions: Int = 0
    /// Meilleur 1RM estimé tous exercices confondus (kg).
    var bestOneRM: Int = 0
    /// Plus long streak hebdomadaire historique (semaines).
    var longestWeeklyStreak: Int = 0

    /// — Nutrition —
    /// Nombre de jours distincts où au moins un repas a été logué.
    var loggedDays: Int = 0
    /// Plus longue série QUOTIDIENNE de jours avec repas (jours consécutifs).
    var longestDailyStreak: Int = 0
    /// Nombre de jours où les 3 macros ont atteint au moins 90 % de leur cible (jour « équilibré »).
    var balancedDays: Int = 0
}

enum BadgeCatalog {
    /// Tous les badges de l'app, dans l'ordre d'affichage.
    static let all: [Badge] = [
        // — Assiduité (nombre de séances) —
        Badge(id: "sessions_1", title: "Première séance", detail: "Tu as enregistré ta toute première séance.",
              icon: .workout, tint: LumeColor.success, category: .attendance),
        Badge(id: "sessions_10", title: "10 séances", detail: "10 séances au compteur. L'habitude s'installe.",
              icon: .workout, tint: LumeColor.success, category: .attendance),
        Badge(id: "sessions_25", title: "25 séances", detail: "25 séances. Régularité confirmée.",
              icon: .workout, tint: LumeColor.protein, category: .attendance),
        Badge(id: "sessions_50", title: "50 séances", detail: "50 séances. Une vraie discipline.",
              icon: .workout, tint: LumeColor.protein, category: .attendance),
        Badge(id: "sessions_100", title: "100 séances", detail: "100 séances. Du sérieux.",
              icon: .pr, tint: LumeColor.warning, category: .attendance),

        // — Force (1RM estimé) —
        Badge(id: "force_60", title: "60 kg", detail: "Tu as estimé un 1RM à 60 kg ou plus.",
              icon: .oneRepMax, tint: LumeColor.fat, category: .force),
        Badge(id: "force_100", title: "Club des 100 kg", detail: "Un 1RM estimé à 100 kg. Belle force.",
              icon: .oneRepMax, tint: LumeColor.fat, category: .force),
        Badge(id: "force_140", title: "140 kg", detail: "1RM estimé à 140 kg. Impressionnant.",
              icon: .oneRepMax, tint: LumeColor.protein, category: .force),
        Badge(id: "force_180", title: "180 kg", detail: "1RM estimé à 180 kg. Costaud.",
              icon: .pr, tint: LumeColor.warning, category: .force),

        // — Régularité (streak hebdo) —
        Badge(id: "streak_2", title: "2 semaines", detail: "2 semaines d'affilée à ton objectif de séances.",
              icon: .streak, tint: LumeColor.warning, category: .regularity),
        Badge(id: "streak_4", title: "1 mois régulier", detail: "4 semaines consécutives à l'objectif.",
              icon: .streak, tint: LumeColor.carbs, category: .regularity),
        Badge(id: "streak_12", title: "3 mois en feu", detail: "12 semaines d'affilée. En feu 🔥",
              icon: .streak, tint: LumeColor.negative, category: .regularity),

        // ===== NUTRITION =====
        // — Suivi (jours logués) —
        Badge(id: "log_1", title: "Premier repas", detail: "Tu as logué ton tout premier repas.",
              icon: .calories, tint: LumeColor.success, category: .logging, domain: .nutrition),
        Badge(id: "log_7", title: "7 jours suivis", detail: "7 jours où tu as logué tes repas.",
              icon: .calories, tint: LumeColor.success, category: .logging, domain: .nutrition),
        Badge(id: "log_30", title: "30 jours suivis", detail: "30 jours de suivi alimentaire.",
              icon: .calories, tint: LumeColor.protein, category: .logging, domain: .nutrition),
        Badge(id: "log_100", title: "100 jours suivis", detail: "100 jours suivis. Une vraie routine.",
              icon: .pr, tint: LumeColor.warning, category: .logging, domain: .nutrition),

        // — Série quotidienne (streak nutrition) —
        Badge(id: "nstreak_3", title: "3 jours d'affilée", detail: "3 jours consécutifs avec au moins un repas logué.",
              icon: .streak, tint: LumeColor.warning, category: .streak, domain: .nutrition),
        Badge(id: "nstreak_7", title: "1 semaine en feu", detail: "7 jours consécutifs. La régularité paie 🔥",
              icon: .streak, tint: LumeColor.carbs, category: .streak, domain: .nutrition),
        Badge(id: "nstreak_30", title: "30 jours d'affilée", detail: "30 jours consécutifs. Discipline de fer.",
              icon: .streak, tint: LumeColor.negative, category: .streak, domain: .nutrition),

        // — Équilibre (jours où les macros sont atteintes) —
        Badge(id: "balance_1", title: "Jour équilibré", detail: "Un jour où tes 3 macros ont approché leur cible (≥ 90 %).",
              icon: .validate, tint: LumeColor.success, category: .balance, domain: .nutrition),
        Badge(id: "balance_10", title: "10 jours équilibrés", detail: "10 journées où tes 3 macros ont approché leur cible.",
              icon: .validate, tint: LumeColor.protein, category: .balance, domain: .nutrition),
    ]

    /// IDs des badges débloqués au vu des stats fournies.
    static func unlocked(for stats: BadgeStats) -> Set<String> {
        var ids = Set<String>()
        func unlock(_ id: String, _ condition: Bool) {
            if condition { ids.insert(id) }
        }

        unlock("sessions_1", stats.totalSessions >= 1)
        unlock("sessions_10", stats.totalSessions >= 10)
        unlock("sessions_25", stats.totalSessions >= 25)
        unlock("sessions_50", stats.totalSessions >= 50)
        unlock("sessions_100", stats.totalSessions >= 100)

        unlock("force_60", stats.bestOneRM >= 60)
        unlock("force_100", stats.bestOneRM >= 100)
        unlock("force_140", stats.bestOneRM >= 140)
        unlock("force_180", stats.bestOneRM >= 180)

        unlock("streak_2", stats.longestWeeklyStreak >= 2)
        unlock("streak_4", stats.longestWeeklyStreak >= 4)
        unlock("streak_12", stats.longestWeeklyStreak >= 12)

        // — Nutrition —
        unlock("log_1", stats.loggedDays >= 1)
        unlock("log_7", stats.loggedDays >= 7)
        unlock("log_30", stats.loggedDays >= 30)
        unlock("log_100", stats.loggedDays >= 100)

        unlock("nstreak_3", stats.longestDailyStreak >= 3)
        unlock("nstreak_7", stats.longestDailyStreak >= 7)
        unlock("nstreak_30", stats.longestDailyStreak >= 30)

        unlock("balance_1", stats.balancedDays >= 1)
        unlock("balance_10", stats.balancedDays >= 10)

        return ids
    }

    /// Badges d'un domaine (muscu ou nutrition), dans l'ordre du catalogue.
    static func all(in domain: Badge.Domain) -> [Badge] {
        all.filter { $0.domain == domain }
    }

    static func badge(id: String) -> Badge? {
        all.first { $0.id == id }
    }
}
