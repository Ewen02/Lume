import Foundation

/// Manipulation de montants monétaires. **Toujours en centimes (Int)** — jamais de Double sur la
/// monnaie (évite les erreurs flottantes type 0,1 + 0,2 ≠ 0,3). Le formatage et le parsing sont
/// centralisés ici ; le `NumberFormatter` est statique caché (sa création est coûteuse).
enum Money {
    static let currencyCode = "EUR"

    /// Formatte des centimes en chaîne localisée ("12,50 €"). `showSign` préfixe +/− (revenu/dépense).
    static func format(_ cents: Int, showSign: Bool = false) -> String {
        let major = Double(abs(cents)) / 100
        let base = currencyFormatter.string(from: NSNumber(value: major)) ?? "\(major) €"
        // Sans showSign : on formate la valeur absolue (pas de signe parasite). Le signe explicite
        // (+/−) n'apparaît que quand l'appelant le demande (ex. le Solde).
        guard showSign else { return base }
        if cents > 0 { return "+" + base }
        if cents < 0 { return "−" + base }
        return base
    }

    /// Montant décimal sans symbole, pour l'export CSV importable en tableur ("12.50").
    static func plainDecimal(_ cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100)
    }

    /// Compose des centimes à partir des parties entière/décimale (12 € 50 → 1250).
    static func cents(major: Int, minor: Int) -> Int {
        max(0, major) * 100 + min(99, max(0, minor))
    }

    /// Décompose des centimes en (euros, centimes) pour l'affichage d'un stepper.
    static func components(_ cents: Int) -> (major: Int, minor: Int) {
        let c = abs(cents)
        return (c / 100, c % 100)
    }

    /// Parse une saisie clavier libre ("12,5", "12.50", "12") en centimes. `nil` si invalide.
    static func parse(_ text: String) -> Int? {
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value >= 0 else { return nil }
        // Arrondi au centime le plus proche pour éviter 1249 au lieu de 1250.
        return Int((value * 100).rounded())
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "fr_FR")
        f.currencyCode = currencyCode
        return f
    }()
}
