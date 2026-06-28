import Charts
import SwiftUI

/// Courbe « produit » réutilisable : ligne lissée + aire, scrub au doigt (valeur + date en
/// bulle, point mis en évidence), axe Y avec repères chiffrés, révélation animée à l'apparition.
/// Pendant ligne d'`InteractiveBarChart`, pour les courbes (progression 1RM, etc.).
struct InteractiveLineChart: View {
    var points: [ChartPoint]
    var tint: Color = LumeColor.protein
    /// Formate la valeur affichée dans la bulle et l'axe Y.
    var format: (Int) -> String = { "\($0)" }
    var height: CGFloat = 180

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grow: Double = 0
    @State private var selected: Date?

    private var domain: ClosedRange<Double> {
        let vals = points.map(\.value)
        guard let lo = vals.min(), let hi = vals.max() else { return 0 ... 1 }
        // Marge de 5 % autour de la plage réelle (la courbe n'a pas à partir de 0).
        let pad = max(1.0, Double(hi - lo) * 0.1)
        return (Double(lo) - pad) ... (Double(hi) + pad)
    }

    private var selectedPoint: ChartPoint? {
        guard let selected else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) }
    }

    var body: some View {
        Chart {
            ForEach(points) { p in
                AreaMark(x: .value("Date", p.date), y: .value("Valeur", p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", p.date), y: .value("Valeur", p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(tint).lineStyle(.init(lineWidth: 2.5))
            }
            if let p = selectedPoint {
                PointMark(x: .value("Date", p.date), y: .value("Valeur", p.value))
                    .foregroundStyle(tint).symbolSize(80)
                RuleMark(x: .value("Date", p.date))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 3])).foregroundStyle(LumeColor.border)
            }
        }
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
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
        .opacity(grow)
        .frame(height: height)
        .overlay(alignment: .topLeading) {
            if let p = selectedPoint {
                ChartLollipop(title: format(p.value),
                              subtitle: Formatters.dayMonth.string(from: p.date), tint: tint)
                    .animation(LumeMotion.snappy, value: p.id)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedPoint?.id)
        .onAppear { withAnimation(reduceMotion ? nil : LumeMotion.smooth.delay(0.1)) { grow = 1 } }
        .accessibilityElement()
        .accessibilityLabel("Courbe")
        .accessibilityValue(selectedPoint.map { format($0.value) } ?? "")
    }
}
