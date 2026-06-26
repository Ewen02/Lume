import Foundation
import SwiftData

/// Matérialise les transactions récurrentes dues en `FinanceTransaction` réelles, puis avance le curseur
/// d'idempotence. Sépare la logique pure (`RecurrenceMaterializer`) de la persistance (ici).
/// Idempotent : un 2e appel le même jour ne crée aucun doublon (curseur `lastMaterializedDate`).
@MainActor
enum RecurrenceEngine {
    /// Génère les occurrences dues jusqu'à aujourd'hui pour toutes les règles actives.
    /// - Returns: le nombre de transactions créées (utile pour les tests / le debug).
    @discardableResult
    static func materializeDue(in context: ModelContext, now: Date = Date(),
                               calendar: Calendar = .current) -> Int
    {
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate { $0.isActive }
        )
        guard let rules = try? context.fetch(descriptor) else { return 0 }

        var created = 0
        for rule in rules {
            let due = RecurrenceMaterializer.dueOccurrences(rule: rule.rule, until: now, calendar: calendar)
            guard !due.isEmpty else { continue }
            for date in due {
                context.insert(FinanceTransaction(date: date, amountCents: rule.amountCents,
                                                  kind: rule.kind, category: rule.category,
                                                  note: rule.label, recurringID: rule.id))
                created += 1
            }
            // Avance le curseur à la dernière occurrence générée.
            rule.lastMaterializedDate = due.max()
        }
        // Persistance déterministe : on sauve dès qu'on a créé quelque chose (la vue peut
        // disparaître avant l'autosave), pour que le curseur d'idempotence soit fiable.
        if created > 0 { try? context.save() }
        return created
    }
}
