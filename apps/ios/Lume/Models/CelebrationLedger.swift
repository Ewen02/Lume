import Foundation

/// Garantit qu'une célébration (mois bouclé, objectif d'épargne atteint…) ne se rejoue pas à chaque
/// ouverture : on horodate le dernier déclenchement par clé + mois (`YYYY-MM`). Logique pure
/// (testable), persistée via `UserDefaults`.
enum CelebrationLedger {
    /// Identifiant de mois stable « 2026-06 » pour borner une célébration à un mois donné.
    static func monthKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// Une célébration `id` doit-elle se déclencher pour `month`, sachant le dernier mois fêté `last` ?
    /// Pure : vrai seulement si on n'a pas déjà fêté ce mois (et qu'on ne « rattrape » pas un mois passé).
    static func shouldCelebrate(currentMonth: String, lastCelebrated: String?) -> Bool {
        guard let last = lastCelebrated else { return true }
        return currentMonth > last
    }

    // MARK: Façade persistée

    private static func storageKey(_ id: String) -> String {
        "lume.finance.celebration.\(id)"
    }

    /// Le dernier mois (`YYYY-MM`) où la célébration `id` a été déclenchée, ou `nil`.
    static func lastCelebrated(_ id: String) -> String? {
        UserDefaults.standard.string(forKey: storageKey(id))
    }

    /// Doit-on célébrer `id` maintenant ? (sans marquer — l'appelant marque après l'avoir montré).
    static func shouldCelebrate(_ id: String, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        shouldCelebrate(currentMonth: monthKey(now, calendar: calendar), lastCelebrated: lastCelebrated(id))
    }

    /// Marque `id` comme fêté pour le mois courant (à appeler une fois la célébration affichée).
    static func markCelebrated(_ id: String, now: Date = Date(), calendar: Calendar = .current) {
        UserDefaults.standard.set(monthKey(now, calendar: calendar), forKey: storageKey(id))
    }
}
