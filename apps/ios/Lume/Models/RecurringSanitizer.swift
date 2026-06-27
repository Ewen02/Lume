import Foundation

/// Vue plate d'une récurrente (découplée de SwiftData) → logique de nettoyage 100 % testable.
struct RecurringSummary: Identifiable {
    var id: UUID
    var label: String
    var amountCents: Int
    var kind: TransactionKind
    var category: ExpenseCategory
    var createdOrder: Int // ordre stable (ex. index dans la requête) pour choisir quel doublon garder
}

/// Détecte les récurrentes à supprimer pour rester cohérent avec le modèle « enveloppe », où TOUT
/// ce qui est fixe (revenu, loyer, charges, épargne) vit dans le profil et n'est PAS matérialisé :
/// - **illégitimes** : récurrente dont le poste est géré par le profil → revenu (`income`/`salary`),
///   épargne (`saving`/`savings`) et loyer (`housing`). Les laisser en récurrente créerait du
///   double-comptage et les doublons observés. Restent légitimes : les DÉPENSES fixes manuelles
///   (abonnements, assurances…) que l'utilisateur ajoute lui-même.
/// - **doublons** : plusieurs récurrentes équivalentes (même sens + catégorie + montant + libellé
///   normalisé) — on garde la première (ordre stable), on supprime les suivantes.
/// Logique pure : ne touche pas la base. La persistance (suppression) se fait dans `RecurringCleaner`.
enum RecurringSanitizer {
    /// Clé d'équivalence d'une récurrente (pour repérer les doublons). Le libellé est normalisé
    /// (minuscule, espaces réduits) pour que « Loyer » et « loyer » comptent comme un doublon.
    static func dedupeKey(_ r: RecurringSummary) -> String {
        let label = r.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(r.kind.rawValue)|\(r.category.rawValue)|\(r.amountCents)|\(label)"
    }

    /// Une récurrente est-elle illégitime au regard du modèle enveloppe ?
    /// Revenu et épargne (quel que soit le poste) + dépense `housing` (loyer) sont gérés par le profil.
    static func isIllegitimate(_ r: RecurringSummary) -> Bool {
        switch r.kind {
        case .income, .saving: return true // revenu & épargne vivent dans le profil
        case .expense: return r.category == .housing // loyer géré dans « Mon budget »
        }
    }

    /// IDs des récurrentes à supprimer = illégitimes ∪ doublons (toutes les occurrences au-delà
    /// de la première, à clé d'équivalence identique). Déterministe via `createdOrder`.
    static func idsToRemove(_ rules: [RecurringSummary]) -> Set<UUID> {
        var remove = Set<UUID>()
        var seen = Set<String>()
        // Ordre stable : on garde la 1re occurrence rencontrée dans cet ordre.
        for r in rules.sorted(by: { $0.createdOrder < $1.createdOrder }) {
            if isIllegitimate(r) {
                remove.insert(r.id)
                continue // inutile de l'enregistrer comme « vue » : on la supprime de toute façon
            }
            let key = dedupeKey(r)
            if seen.contains(key) {
                remove.insert(r.id) // doublon d'une récurrente déjà conservée
            } else {
                seen.insert(key)
            }
        }
        return remove
    }
}
