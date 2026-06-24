import Foundation

/// Point d'un graphe en barres daté : une date, une valeur. Type d'entrée commun aux
/// graphes interactifs de Progrès (calories, balance nette, pas).
struct ChartPoint: Identifiable {
    var date: Date
    var value: Int
    var id: Date {
        date
    }
}

/// Calculs d'échelle des graphes (purs, testables) : domaine Y et largeur de barre.
/// Évite les défauts de l'ancien écran — barres « fantômes » à 0, `.fixed` qui déborde
/// sur 30/90 j, échelle écrasée quand une série domine.
enum ChartScale {
    /// Domaine Y d'un graphe de valeurs positives : 0 → un peu au-dessus du max
    /// (10 % de marge), jamais dégénéré.
    static func positiveDomain(_ points: [ChartPoint]) -> ClosedRange<Double> {
        let maxV = points.map(\.value).max() ?? 1
        let top = Double(max(maxV, 1)) * 1.1
        return 0 ... top
    }

    /// Domaine Y **symétrique** autour de 0 (vue « net » déficit/surplus), basé sur le plus
    /// grand écart absolu → lisible dans les deux sens même si tout est déficit.
    static func symmetricDomain(_ points: [ChartPoint]) -> ClosedRange<Double> {
        let bound = Double(points.map { abs($0.value) }.max() ?? 1)
        let m = max(bound, 1) * 1.15
        return -m ... m
    }

    /// Largeur de barre adaptée au nombre de points et à la largeur disponible, bornée
    /// pour rester lisible (ni trait, ni pavé). Remplace les `.fixed(...)` qui débordaient.
    static func barWidth(count: Int, available: Double) -> Double {
        guard count > 0 else { return 16 }
        // ~65 % de l'espace alloué à chaque point va à la barre (35 % d'air entre barres).
        let slot = available / Double(count)
        return min(28, max(3, slot * 0.65))
    }

    /// 3 graduations Y « rondes » pour un domaine positif (0, milieu, haut arrondi).
    static func ticks(_ domain: ClosedRange<Double>) -> [Int] {
        let top = domain.upperBound
        guard top > 0 else { return [0] }
        let step = niceStep(top / 2)
        var ticks: [Int] = []
        var v = 0.0
        while v <= top + 0.5 {
            ticks.append(Int(v))
            v += step
        }
        return ticks
    }

    /// Arrondit un pas à une valeur « ronde » (1/2/5 × 10ⁿ) pour des graduations propres.
    private static func niceStep(_ raw: Double) -> Double {
        guard raw > 0 else { return 1 }
        let mag = pow(10, log10(raw).rounded(.down))
        let norm = raw / mag
        let nice = norm < 1.5 ? 1.0 : (norm < 3.5 ? 2.0 : (norm < 7.5 ? 5.0 : 10.0))
        return nice * mag
    }
}
