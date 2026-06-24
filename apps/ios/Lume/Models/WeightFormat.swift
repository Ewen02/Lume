import Foundation

/// Conversion et formatage des poids. **Le stockage reste toujours en kg** (modèle) ; seul
/// l'affichage et la saisie basculent en livres quand l'utilisateur choisit les unités
/// impériales. Logique pure → testable.
enum WeightFormat {
    static let lbPerKg = 2.20462

    /// Clé du réglage d'unités (impérial vs métrique).
    static let defaultsKey = "lume.useImperialUnits"

    /// Lit le réglage courant (pour le code hors-vue : exports, etc.).
    static var isImperial: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func kgToLb(_ kg: Double) -> Double {
        kg * lbPerKg
    }

    static func lbToKg(_ lb: Double) -> Double {
        lb / lbPerKg
    }

    /// Unité courte affichée ("kg" / "lb").
    static func unit(imperial: Bool) -> String {
        imperial ? "lb" : "kg"
    }

    /// Poids corporel formaté ("74,5 kg" / "164,2 lb"), 1 décimale.
    static func body(_ kg: Double, imperial: Bool, decimals: Int = 1) -> String {
        let v = imperial ? kgToLb(kg) : kg
        return "\(string(v, decimals: decimals)) \(unit(imperial: imperial))"
    }

    /// Variation signée ("+0,4 kg" / "−1,2 lb").
    static func bodyDelta(_ kg: Double, imperial: Bool, decimals: Int = 1) -> String {
        let v = imperial ? kgToLb(kg) : kg
        let sign = v >= 0 ? "+" : ""
        return "\(sign)\(string(v, decimals: decimals)) \(unit(imperial: imperial))"
    }

    /// Charge de musculation entière formatée ("60 kg" / "132 lb").
    static func load(_ kg: Int, imperial: Bool) -> String {
        let v = imperial ? Int((Double(kg) * lbPerKg).rounded()) : kg
        return "\(v) \(unit(imperial: imperial))"
    }

    /// Charge décimale (poids d'une série) formatée sans zéro inutile ("62,5 kg" / "138 lb").
    static func loadDecimal(_ kg: Double, imperial: Bool) -> String {
        let v = imperial ? kgToLb(kg) : kg
        return "\(v.clean) \(unit(imperial: imperial))"
    }

    /// Pas de saisie dans l'unité courante (0,5 kg ≈ 1 lb), exprimé en KG (stockage).
    static func stepKg(imperial: Bool) -> Double {
        imperial ? lbToKg(1) : 0.5
    }

    /// Formatage numérique fixe (séparateur décimal local). 1 décimale par défaut.
    private static func string(_ v: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", v)
    }
}
