import Foundation

/// Formatters mis en cache : leur création est coûteuse, on évite d'en recréer à chaque rendu/ligne.
enum Formatters {
    static let relativeFR: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .short
        return f
    }()

    static let dayMonthFR: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    static func relative(_ date: Date) -> String {
        relativeFR.localizedString(for: date, relativeTo: Date())
    }

    /// "Juin 2026" (mois capitalisé).
    static func monthYearFR(_ date: Date) -> String {
        monthYear.string(from: date).capitalized
    }
}
