import Foundation

/// Vue plate d'une transaction, découplée de SwiftData → la logique reste 100 % testable
/// (cf. `EnergyBalance` testé sans modèle). Une extension mappe `FinanceTransaction` (model) → `TransactionData`.
struct TransactionData {
    var date: Date
    var kind: TransactionKind
    var category: ExpenseCategory
    var amountCents: Int // toujours positif
}

/// Statut d'un budget vis-à-vis du dépensé.
enum BudgetStatus {
    case under, near, over
    /// Seuil "near" : ≥ 85 % du budget. "over" : > 100 %.
    static func of(spent: Int, budget: Int) -> BudgetStatus {
        guard budget > 0 else { return .under }
        let ratio = Double(spent) / Double(budget)
        if ratio > 1 { return .over }
        if ratio >= 0.85 { return .near }
        return .under
    }
}

/// Agrégations financières pures (centimes Int). Aucune dépendance SwiftData ni SwiftUI.
enum FinanceCalculator {
    /// Bornes [début, début mois suivant[ pour un mois donné.
    static func monthBounds(of date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return (start, end)
    }

    private static func inMonth(_ tx: [TransactionData], _ month: Date, _ calendar: Calendar) -> [TransactionData] {
        let (start, end) = monthBounds(of: month, calendar: calendar)
        return tx.filter { $0.date >= start && $0.date < end }
    }

    /// Total des DÉPENSES du mois (centimes).
    static func totalSpent(_ tx: [TransactionData], in month: Date, calendar: Calendar = .current) -> Int {
        inMonth(tx, month, calendar).filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
    }

    /// Total des REVENUS du mois (centimes).
    static func totalIncome(_ tx: [TransactionData], in month: Date, calendar: Calendar = .current) -> Int {
        inMonth(tx, month, calendar).filter { $0.kind == .income }.reduce(0) { $0 + $1.amountCents }
    }

    /// Total ÉPARGNÉ sur le mois (centimes) — distinct des dépenses (n'entame pas le budget variable).
    static func totalSaved(_ tx: [TransactionData], in month: Date, calendar: Calendar = .current) -> Int {
        inMonth(tx, month, calendar).filter { $0.kind == .saving }.reduce(0) { $0 + $1.amountCents }
    }

    /// Capital épargné cumulé (toutes périodes confondues) — pour l'indicateur « total mis de côté ».
    static func cumulativeSaved(_ tx: [TransactionData]) -> Int {
        tx.filter { $0.kind == .saving }.reduce(0) { $0 + $1.amountCents }
    }

    /// Solde « brut » du mois = revenus matérialisés − dépenses matérialisées (centimes, peut être négatif).
    /// ⚠️ Ne reflète PAS les engagements fixes non matérialisés (loyer/charges/épargne). Pour le solde
    /// réellement « à vivre », utiliser `realBalance` qui les déduit depuis le profil.
    static func balance(_ tx: [TransactionData], in month: Date, calendar: Calendar = .current) -> Int {
        totalIncome(tx, in: month, calendar: calendar) - totalSpent(tx, in: month, calendar: calendar)
    }

    /// Engagements fixes mensuels non matérialisés (loyer + charges + épargne), déduits une fois du
    /// solde réel pour ne pas mentir : ils sont décomptés du revenu mais ne sont pas des transactions.
    /// Ne s'applique qu'au mois courant (les mois passés n'ont pas d'historique de profil fiable).
    static func committedOutflow(rentCents: Int, fixedChargesCents: Int, savingCents: Int) -> Int {
        max(0, rentCents) + max(0, fixedChargesCents) + max(0, savingCents)
    }

    /// Solde RÉEL « à vivre » du mois = revenus − dépenses variables − engagements fixes (loyer +
    /// charges + épargne du profil). C'est le chiffre honnête : ce qu'il reste après TOUTES les sorties.
    /// `committed` vaut 0 pour un mois passé (pas de profil historique) → on retombe sur `balance`.
    static func realBalance(_ tx: [TransactionData], in month: Date,
                            committed: Int, calendar: Calendar = .current) -> Int
    {
        balance(tx, in: month, calendar: calendar) - max(0, committed)
    }

    /// Dépensé par catégorie sur le mois (centimes). Seules les dépenses comptent.
    static func spentByCategory(_ tx: [TransactionData], in month: Date, calendar: Calendar = .current) -> [ExpenseCategory: Int] {
        var out: [ExpenseCategory: Int] = [:]
        for t in inMonth(tx, month, calendar) where t.kind == .expense {
            out[t.category, default: 0] += t.amountCents
        }
        return out
    }

    /// Progression dépensé/budget (0…1, plafonnée), pour les barres et anneaux.
    static func progress(spent: Int, budget: Int) -> Double {
        guard budget > 0 else { return 0 }
        return min(1, max(0, Double(spent) / Double(budget)))
    }

    /// Dépense moyenne par jour du mois : jours écoulés pour le mois courant, sinon nb de jours du mois.
    static func averagePerDay(_ tx: [TransactionData], in month: Date,
                              reference: Date = Date(), calendar: Calendar = .current) -> Int
    {
        let spent = totalSpent(tx, in: month, calendar: calendar)
        let (start, end) = monthBounds(of: month, calendar: calendar)
        let isCurrentMonth = reference >= start && reference < end
        let lastDay = isCurrentMonth ? reference : calendar.date(byAdding: .day, value: -1, to: end) ?? start
        let days = max(1, (calendar.dateComponents([.day], from: start, to: lastDay).day ?? 0) + 1)
        // Arrondi explicite (Int, pas de Double qui traîne).
        return Int((Double(spent) / Double(days)).rounded())
    }

    /// Série des dépenses des `months` derniers mois (du plus ancien au plus récent) →
    /// `ChartPoint` réutilisable par `InteractiveBarChart` (value en centimes).
    static func monthlySeries(_ tx: [TransactionData], months: Int = 6,
                              reference: Date = Date(), calendar: Calendar = .current) -> [ChartPoint]
    {
        let currentStart = monthBounds(of: reference, calendar: calendar).start
        var points: [ChartPoint] = []
        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: currentStart) else { continue }
            points.append(ChartPoint(date: monthStart, value: totalSpent(tx, in: monthStart, calendar: calendar)))
        }
        return points
    }
}
