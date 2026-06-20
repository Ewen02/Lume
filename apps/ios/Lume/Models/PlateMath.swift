import Foundation

/// Calcul glouton des disques par côté d'une barre.
enum PlateMath {
    static let standardPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    /// Disques à mettre de chaque côté pour atteindre `target` (barre `bar`).
    /// Retourne [] si la cible est ≤ au poids de la barre.
    static func perSide(target: Double, bar: Double = 20, available: [Double] = standardPlates) -> [Double] {
        var rem = (target - bar) / 2
        guard rem > 0 else { return [] }
        var out: [Double] = []
        for plate in available {
            while rem >= plate - 0.001 {
                out.append(plate); rem -= plate
            }
        }
        return out
    }
}
