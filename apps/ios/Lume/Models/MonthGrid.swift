import Foundation

/// Génère la grille d'un mois (semaines × 7 jours) pour un affichage calendrier.
/// Pur et testable. Les cases hors-mois sont `nil` (pour aligner sur la grille 7 colonnes).
struct MonthGrid {
    /// Date représentative du mois affiché (n'importe quel jour du mois).
    let month: Date
    let calendar: Calendar

    init(month: Date, calendar: Calendar = .current) {
        self.month = month
        self.calendar = calendar
    }

    /// Premier jour du mois (à minuit).
    var firstOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }

    /// Libellé "Mois AAAA" en français (ex. « Juin 2026 »).
    var title: String {
        Formatters.monthYearFR(firstOfMonth)
    }

    /// Les jours de la grille, alignés sur des semaines commençant le lundi.
    /// Longueur multiple de 7 ; `nil` = case vide (avant le 1er ou après le dernier jour).
    var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
        let weekday = calendar.component(.weekday, from: firstOfMonth) // 1 = dimanche … 7 = samedi
        // Décalage pour une semaine commençant le LUNDI.
        let leading = (weekday + 5) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                cells.append(date)
            }
        }
        // Complète la dernière semaine.
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    /// En-têtes de colonnes (lundi → dimanche).
    static let weekdaySymbols = ["L", "M", "M", "J", "V", "S", "D"]

    /// Mois précédent / suivant.
    func adding(_ months: Int) -> MonthGrid {
        let d = calendar.date(byAdding: .month, value: months, to: firstOfMonth) ?? firstOfMonth
        return MonthGrid(month: d, calendar: calendar)
    }

    /// Vrai si `date` est dans le même mois/année que la grille.
    func isInMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: firstOfMonth, toGranularity: .month)
    }
}
