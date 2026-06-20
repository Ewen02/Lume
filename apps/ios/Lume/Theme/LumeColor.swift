import SwiftUI

/// Palette Lume. Source de vérité unique des couleurs.
/// (Mappe 1:1 les variables Figma "Lume/Color".)
extension Color {
    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

enum LumeColor {
    // Surfaces
    static let cream = Color(hex: 0xF6F5F1) // fond app
    static let surface = Color(hex: 0xFFFFFF) // cartes
    static let faint = Color(hex: 0xEDEBE5) // pistes / fills discrets
    static let border = Color(hex: 0xE7E5DF) // séparateurs
    static let placeholder = Color(hex: 0xDED0B6) // fond photo en attente
    static let placeholderTint = Color(hex: 0xB9A77F) // icône sur placeholder

    // Texte
    static let ink = Color(hex: 0x1B1B1D) // primaire
    static let textSecondary = Color(hex: 0x5B5B60)
    static let muted = Color(hex: 0x9A9A9F) // tertiaire / labels

    // Macros
    static let protein = Color(hex: 0xF2542D)
    static let carbs = Color(hex: 0xF5A623)
    static let fat = Color(hex: 0x4A90E2)

    // Sémantiques
    static let success = Color(hex: 0x2FBF71)
    static let warning = Color(hex: 0xE2B532)
    static let negative = Color(hex: 0xE0454F)
}
