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

    // MARK: Jalons « une fois pour toutes » (non mensuels)

    // Certaines célébrations ne se rejouent JAMAIS une fois vues : franchissement d'un palier de
    // série (7 jours…), objectif de poids atteint, fin d'onboarding. On les marque par un simple
    // booléen persistant, sans logique de mois. Préfixe distinct de la façade mensuelle.

    private static func milestoneKey(_ id: String) -> String {
        "lume.celebration.milestone.\(id)"
    }

    /// Ce jalon `id` a-t-il déjà été fêté (à vie) ?
    static func hasFired(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: milestoneKey(id))
    }

    /// Marque le jalon `id` comme fêté définitivement (à appeler une fois la célébration affichée).
    static func markFired(_ id: String) {
        UserDefaults.standard.set(true, forKey: milestoneKey(id))
    }

    /// Doit-on fêter le jalon `id` maintenant ? Vrai seulement la première fois.
    /// Ne marque pas : l'appelant marque après affichage (cohérent avec la façade mensuelle).
    static func shouldFire(_ id: String) -> Bool {
        !hasFired(id)
    }
}

/// Paliers de série fêtés proactivement (la grande flamme s'ouvre toute seule au franchissement).
/// Pure et testable : `crossed` renvoie le plus haut palier atteint par `streak` et pas encore fêté.
enum StreakMilestone {
    /// Paliers nutrition (jours consécutifs) — alignés sur les badges `nstreak_*`.
    static let nutrition = [3, 7, 30]
    /// Paliers muscu (semaines consécutives) — alignés sur les badges `streak_*`.
    static let workout = [2, 4, 12]

    /// Identifiant de jalon stable pour le ledger (ex. `streak.nutrition.7`).
    static func ledgerID(domain: String, threshold: Int) -> String {
        "streak.\(domain).\(threshold)"
    }

    /// Plus haut palier (`thresholds`) atteint par `streak` et non encore fêté (`alreadyFired`), ou `nil`.
    /// On ne fête qu'un palier à la fois (le plus haut nouvellement atteint), pour éviter une rafale.
    static func crossed(streak: Int, thresholds: [Int],
                        alreadyFired: (Int) -> Bool) -> Int?
    {
        thresholds
            .filter { streak >= $0 && !alreadyFired($0) }
            .max()
    }
}
