import Charts
import SwiftUI

/// Graphe en barres « produit » réutilisable : scrub au doigt (valeur + date en bulle),
/// axe Y avec quelques repères chiffrés, largeur de barre adaptative (jamais de
/// débordement), montée animée à l'apparition, mode « net » divergent autour de 0.
///
/// Centralise l'interaction tactile (auparavant inline dans le seul graphe poids) pour
/// les graphes calories / balance nette / pas.
struct InteractiveBarChart: View {
    var points: [ChartPoint]
    /// Couleur d'une barre. Par défaut `tint` ; en mode divergent on colore selon le signe.
    var tint: Color = LumeColor.ink
    /// Vue « net » : barres de 0 → valeur (peut être négative), domaine symétrique, ligne 0.
    var diverging: Bool = false
    /// Couleurs du mode divergent (valeur ≤ 0 / > 0). Déficit vert, surplus rouge par défaut.
    var negativeTint: Color = LumeColor.success
    var positiveTint: Color = LumeColor.negative
    /// Formate la valeur affichée dans la bulle (ex. "1 850 kcal", "8 200 pas").
    var format: (Int) -> String = { "\($0)" }
    var height: CGFloat = 150

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grow: Double = 0
    @State private var selected: Date?

    private var domain: ClosedRange<Double> {
        diverging ? ChartScale.symmetricDomain(points) : ChartScale.positiveDomain(points)
    }

    private var selectedPoint: ChartPoint? {
        guard let selected else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) }
    }

    private func barColor(_ p: ChartPoint) -> Color {
        guard diverging else { return tint }
        return p.value <= 0 ? negativeTint : positiveTint
    }

    var body: some View {
        GeometryReader { geo in
            let width = ChartScale.barWidth(count: points.count, available: geo.size.width)
            Chart {
                if diverging {
                    RuleMark(y: .value("Zéro", 0))
                        .lineStyle(.init(lineWidth: 1))
                        .foregroundStyle(LumeColor.border)
                }
                ForEach(points) { p in
                    BarMark(x: .value("Jour", p.date, unit: .day),
                            y: .value("Valeur", Double(p.value) * grow),
                            width: .fixed(width))
                        .foregroundStyle(barColor(p).opacity(selected == nil || selectedPoint?.id == p.id ? 1 : 0.35))
                        .cornerRadius(4)
                }
            }
            .chartYScale(domain: domain)
            .chartYAxis {
                // Quelques repères chiffrés discrets (lisibilité des ordres de grandeur).
                AxisMarks(position: .leading, values: yAxisValues) { value in
                    AxisGridLine().foregroundStyle(LumeColor.faint)
                    AxisValueLabel {
                        if let v = value.as(Double.self) { Text(format(Int(v))).font(.lumeFootnote).foregroundStyle(LumeColor.muted) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(LumeColor.faint)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.lumeFootnote)
                }
            }
            .chartXSelection(value: $selected)
            .overlay(alignment: .topLeading) {
                if let p = selectedPoint {
                    ChartLollipop(title: format(p.value),
                                  subtitle: Formatters.dayMonth.string(from: p.date),
                                  tint: diverging ? barColor(p) : LumeColor.ink)
                        .animation(LumeMotion.snappy, value: p.id)
                }
            }
        }
        .frame(height: height)
        .sensoryFeedback(.selection, trigger: selectedPoint?.id)
        .onAppear { withAnimation(reduceMotion ? nil : LumeMotion.smooth.delay(0.1)) { grow = 1 } }
        .accessibilityElement()
        .accessibilityLabel("Graphe")
        .accessibilityValue(selectedPoint.map { format($0.value) } ?? "")
    }

    /// Valeurs de l'axe Y : graduations rondes (mode positif) ou bornes symétriques (net).
    private var yAxisValues: [Double] {
        if diverging {
            let m = domain.upperBound
            return [-m, 0, m]
        }
        return ChartScale.ticks(domain).map(Double.init)
    }
}

#Preview {
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    func pts(_ vals: [Int]) -> [ChartPoint] {
        vals.enumerated().map { ChartPoint(date: base.addingTimeInterval(Double($0.offset) * 86400), value: $0.element) }
    }
    return VStack(spacing: Spacing.xl) {
        InteractiveBarChart(points: pts([1800, 2100, 0, 1950, 2300, 1700, 2000]), format: { "\($0) kcal" })
        InteractiveBarChart(points: pts([-300, -500, 200, -150, -600, 100, -400]),
                            diverging: true, format: { "\($0) kcal" })
    }
    .padding().background(LumeColor.cream)
}
