import Foundation
import SwiftData

/// Profil financier de l'utilisateur (propre au module Budget, distinct du ProfileRecord nutrition).
/// **Source de vérité** du modèle « enveloppe » : revenu, fixes (loyer + charges) et épargne sont
/// stockés ici et déduits UNE fois pour calculer le budget de dépenses variables — ils ne sont PAS
/// matérialisés en transactions (sauf le salaire, en revenu, pour alimenter le solde).
/// CloudKit-safe : tous défauts, aucune `.unique`.
@Model
final class FinanceProfile: Identifiable {
    var id: UUID = UUID()
    /// Revenu net **mensuel** en centimes (l'annuel n'est qu'une saisie convertie ÷12).
    var monthlyNetIncomeCents: Int = 0
    /// Loyer mensuel (déduit du budget, non matérialisé).
    var rentCents: Int = 0
    /// Total des charges fixes mensuelles (abonnements, assurances… déduit, non matérialisé).
    var fixedChargesCents: Int = 0
    /// Épargne mensuelle mise de côté (déduite du budget, non matérialisée en transaction).
    var monthlySavingCents: Int = 0
    var createdAt: Date = Date()

    init(monthlyNetIncomeCents: Int = 0, rentCents: Int = 0,
         fixedChargesCents: Int = 0, monthlySavingCents: Int = 0)
    {
        self.monthlyNetIncomeCents = max(0, monthlyNetIncomeCents)
        self.rentCents = max(0, rentCents)
        self.fixedChargesCents = max(0, fixedChargesCents)
        self.monthlySavingCents = max(0, monthlySavingCents)
    }

    /// Reste à vivre brut (peut être négatif) = revenu − loyer − charges − épargne.
    var resteAVivreCents: Int {
        BudgetPlanner.resteAVivre(
            monthlyIncomeCents: monthlyNetIncomeCents,
            fixedMonthlyCents: rentCents + fixedChargesCents + monthlySavingCents
        )
    }

    /// Budget de dépenses variables = reste à vivre, planché à 0 (un budget ne peut être négatif).
    var variableBudgetCents: Int {
        max(0, resteAVivreCents)
    }

    /// Les engagements fixes (loyer + charges + épargne) dépassent-ils les revenus ? → budget intenable.
    var isOverCommitted: Bool {
        monthlyNetIncomeCents > 0 && resteAVivreCents < 0
    }

    /// De combien les engagements dépassent les revenus (positif), 0 sinon.
    var overCommitCents: Int {
        max(0, -resteAVivreCents)
    }
}

/// Calculs purs du budget mensuel à partir du profil + des dépenses fixes (testables, sans SwiftData).
enum BudgetPlanner {
    /// Net mensuel à partir d'un salaire annuel net (÷12, arrondi au centime).
    static func monthly(fromAnnual annualCents: Int) -> Int {
        Int((Double(max(0, annualCents)) / 12).rounded())
    }

    /// Annuel à partir d'un net mensuel (×12) — pour pré-remplir le toggle annuel/mensuel.
    static func annual(fromMonthly monthlyCents: Int) -> Int {
        max(0, monthlyCents) * 12
    }

    /// « Reste à vivre » = revenu mensuel net − total des dépenses fixes mensuelles. Jamais négatif
    /// affiché comme budget (plancher 0), mais on expose le brut pour pouvoir alerter si négatif.
    static func resteAVivre(monthlyIncomeCents: Int, fixedMonthlyCents: Int) -> Int {
        monthlyIncomeCents - fixedMonthlyCents
    }

    // MARK: Suggestions de pré-remplissage (règle 50/30/20 — repères, pas des cibles imposées)

    /// Part indicative du revenu allouée au loyer dans la règle « besoins » (≈ 30 %).
    static let suggestedRentRatio = 30
    /// Part indicative du revenu mise de côté chaque mois (≈ 20 %).
    static let suggestedSavingRatio = 20

    /// Loyer suggéré à partir du revenu mensuel net (≈ 30 %, arrondi à l'euro inférieur via les centimes).
    static func suggestedRent(monthlyIncomeCents: Int) -> Int {
        max(0, monthlyIncomeCents) * suggestedRentRatio / 100
    }

    /// Épargne mensuelle suggérée à partir du revenu net (≈ 20 %).
    static func suggestedSaving(monthlyIncomeCents: Int) -> Int {
        max(0, monthlyIncomeCents) * suggestedSavingRatio / 100
    }
}
