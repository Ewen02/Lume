import Foundation

/// Règle de récurrence, à plat (découplée de SwiftData) pour rester testable.
struct RecurrenceData {
    var frequency: RecurrenceFrequency
    var dayOfMonth: Int // 1...31, clampé au dernier jour réel du mois si dépassement
    var startDate: Date
    var lastMaterialized: Date?
}

/// Calcule les dates d'échéance d'une récurrente **non encore matérialisées** (idempotent).
/// Logique pure : ne touche pas la base. La persistance (insertion + avancée du curseur) se fait
/// dans `RecurrenceEngine`.
enum RecurrenceMaterializer {
    /// Occurrences dues dans ]curseur, until], depuis `startDate`. Vide si rien à générer.
    /// - L'idempotence repose sur `rule.lastMaterialized` : on ne renvoie que des dates strictement
    ///   postérieures. Un 2e appel le même jour ne renvoie donc rien de nouveau.
    static func dueOccurrences(rule: RecurrenceData, until: Date, calendar: Calendar = .current) -> [Date] {
        let upper = calendar.startOfDay(for: until)
        let begin = calendar.startOfDay(for: rule.startDate)
        guard begin <= upper else { return [] }

        // On ne génère que ce qui suit le curseur (exclu) — cœur de l'idempotence.
        let afterExclusive = rule.lastMaterialized.map { calendar.startOfDay(for: $0) }

        var occurrences: [Date] = []
        switch rule.frequency {
        case .monthly:
            // Itère mois par mois du mois de départ au mois de `until`.
            var monthCursor = monthStart(of: begin, calendar)
            let lastMonth = monthStart(of: upper, calendar)
            while monthCursor <= lastMonth {
                if let due = occurrence(inMonth: monthCursor, dayOfMonth: rule.dayOfMonth, calendar: calendar),
                   due >= begin, due <= upper,
                   afterExclusive == nil || due > afterExclusive!
                {
                    occurrences.append(due)
                }
                guard let next = calendar.date(byAdding: .month, value: 1, to: monthCursor) else { break }
                monthCursor = next
            }
        case .weekly:
            var cursor = begin
            while cursor <= upper {
                if afterExclusive == nil || cursor > afterExclusive! {
                    occurrences.append(cursor)
                }
                guard let next = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
                cursor = next
            }
        }
        return occurrences
    }

    /// Date d'échéance d'un mois donné, jour clampé au dernier jour réel (ex. 31 → 28/29/30).
    private static func occurrence(inMonth monthStart: Date, dayOfMonth: Int, calendar: Calendar) -> Date? {
        // `range(of:in:for:)` renvoie un Range demi-ouvert (ex. 1..<32) → le repli doit l'être aussi.
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1 ..< 29
        let daysInMonth = range.upperBound - 1
        let day = min(max(1, dayOfMonth), daysInMonth)
        return calendar.date(byAdding: .day, value: day - 1, to: monthStart)
    }

    private static func monthStart(of date: Date, _ calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }
}
