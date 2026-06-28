import Foundation

/// Formatters mis en cache : leur création est coûteuse, on évite d'en recréer à chaque rendu/ligne.
///
/// i18n : tous suivent `Locale.current` (langue de l'utilisateur), et utilisent `setLocalizedDateFormatFromTemplate`
/// pour que l'ORDRE des composants (jour/mois) suive aussi la langue (« 28 juin » en FR, « June 28 » en EN).
enum Formatters {
    static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = .current
        f.unitsStyle = .short
        return f
    }()

    /// "lundi 28 juin" (FR) / "Monday, June 28" (EN) — ordre des composants localisé.
    static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return f
    }()

    /// "juin 2026" (FR) / "June 2026" (EN).
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("LLLLyyyy")
        return f
    }()

    static func relative(_ date: Date) -> String {
        relative.localizedString(for: date, relativeTo: Date())
    }

    /// Mois + année, casse localisée (FR capitalise l'initiale ; EN est déjà capitalisé par le formatter).
    static func monthYearLabel(_ date: Date) -> String {
        let s = monthYear.string(from: date)
        return localizedCapitalizedFirst(s)
    }

    /// Jour + mois, casse localisée pour un en-tête.
    static func dayMonthLabel(_ date: Date) -> String {
        localizedCapitalizedFirst(dayMonth.string(from: date))
    }

    /// Capitalise la 1re lettre selon la locale courante, sans toucher au reste (≠ `.capitalized`
    /// qui met une majuscule à CHAQUE mot — faux pour un titre de date en anglais).
    private static func localizedCapitalizedFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return String(first).uppercased(with: .current) + s.dropFirst()
    }
}
