import Foundation

/// Fenêtre temporelle des graphes Progrès (poids & calories).
/// `nil` jours = « Tout l'historique ».
enum ChartPeriod: Int, CaseIterable, Identifiable {
    case week, month, quarter, all
    var id: Int {
        rawValue
    }

    /// Nombre de jours de la fenêtre (`nil` = illimité).
    var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .all: nil
        }
    }

    var label: String {
        switch self {
        case .week: "7 j"
        case .month: "30 j"
        case .quarter: "90 j"
        case .all: "Tout"
        }
    }

    /// Date de début de la fenêtre (incluse), `nil` si « Tout ».
    func start(reference: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let days else { return nil }
        let today0 = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: .day, value: -(days - 1), to: today0)
    }

    /// Au-delà d'une semaine, on agrège les calories par semaine (sinon graphe illisible).
    var aggregatesByWeek: Bool {
        self != .week
    }
}
