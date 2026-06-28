import Foundation
import SwiftData

/// Supprime de la base les récurrentes incohérentes avec le modèle « enveloppe » (revenu/épargne/loyer
/// gérés par le profil) et les doublons. Sépare la logique pure (`RecurringSanitizer`) de la
/// persistance (ici). Idempotent : un 2e appel ne supprime plus rien.
@MainActor
enum RecurringCleaner {
    /// Purge les récurrentes illégitimes + doublons. Retourne le nombre supprimé (tests / debug).
    @discardableResult
    static func purge(in context: ModelContext) -> Int {
        guard let rules = try? context.fetch(FetchDescriptor<RecurringTransaction>()) else { return 0 }
        guard !rules.isEmpty else { return 0 }

        // Ordre stable : la date de départ puis l'id, pour un dédoublonnage déterministe.
        let ordered = rules.sorted {
            $0.startDate == $1.startDate ? $0.id.uuidString < $1.id.uuidString : $0.startDate < $1.startDate
        }
        let flat = ordered.enumerated().map { index, r in
            RecurringSummary(id: r.id, label: r.label, amountCents: r.amountCents,
                             kind: r.kind, category: r.category, createdOrder: index)
        }
        let toRemove = RecurringSanitizer.idsToRemove(flat)
        guard !toRemove.isEmpty else { return 0 }

        var deleted = 0
        for r in rules where toRemove.contains(r.id) {
            context.delete(r)
            deleted += 1
        }
        // Save d'abord ; si ça échoue, on annule les suppressions en attente (pas d'état
        // incohérent où la base a « perdu » des règles en mémoire mais pas sur disque).
        if deleted > 0 {
            do {
                try context.save()
            } catch {
                context.rollback()
                return 0
            }
        }
        return deleted
    }
}
