import Foundation
import SwiftData

/// Badge de musculation débloqué (jalon atteint). Persiste l'identifiant du badge + la date.
/// Contraintes CloudKit : valeurs par défaut, aucune contrainte unique.
@Model
final class BadgeUnlock {
    /// Identifiant stable du badge (= `Badge.id` du catalogue).
    var badgeID: String = ""
    var unlockedAt: Date = Date()

    init(badgeID: String, unlockedAt: Date = Date()) {
        self.badgeID = badgeID
        self.unlockedAt = unlockedAt
    }
}
