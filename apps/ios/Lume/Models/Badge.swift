import SwiftUI

/// Définition d'un badge (jalon de musculation). Catalogue statique ; le déblocage est persisté
/// via `BadgeUnlock`. `id` est stable (clé de persistance).
struct Badge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: AppIcon
    let tint: Color

    enum Category: String, CaseIterable, Identifiable {
        case volume, force, regularity
        var id: String {
            rawValue
        }

        var label: String {
            switch self {
            case .volume: "Assiduité"
            case .force: "Force"
            case .regularity: "Régularité"
            }
        }
    }

    let category: Category
}

/// Stats agrégées nécessaires pour évaluer les badges (calculées une fois depuis les séances).
struct BadgeStats {
    var totalSessions: Int
    /// Meilleur 1RM estimé tous exercices confondus (kg).
    var bestOneRM: Int
    /// Plus long streak hebdomadaire historique (semaines).
    var longestWeeklyStreak: Int
    /// Volume total cumulé sur toutes les séances (kg).
    var totalVolume: Int
}

enum BadgeCatalog {
    /// Tous les badges de l'app, dans l'ordre d'affichage.
    static let all: [Badge] = [
        // — Assiduité (nombre de séances) —
        Badge(id: "sessions_1", title: "Première séance", detail: "Tu as enregistré ta toute première séance.",
              icon: .workout, tint: LumeColor.success, category: .volume),
        Badge(id: "sessions_10", title: "10 séances", detail: "10 séances au compteur. L'habitude s'installe.",
              icon: .workout, tint: LumeColor.success, category: .volume),
        Badge(id: "sessions_25", title: "25 séances", detail: "25 séances. Régularité confirmée.",
              icon: .workout, tint: LumeColor.protein, category: .volume),
        Badge(id: "sessions_50", title: "50 séances", detail: "50 séances. Une vraie discipline.",
              icon: .workout, tint: LumeColor.protein, category: .volume),
        Badge(id: "sessions_100", title: "100 séances", detail: "100 séances. Du sérieux.",
              icon: .pr, tint: LumeColor.warning, category: .volume),

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

        return ids
    }

    static func badge(id: String) -> Badge? {
        all.first { $0.id == id }
    }
}
