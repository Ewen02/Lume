import SwiftUI
import UIKit

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

    /// Couleur adaptative : `light` en mode clair, `dark` en mode sombre. Résolue au runtime selon
    /// le trait d'interface → un seul token suit l'apparence système, sans changement aux call sites.
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

/// Palette Lume — chaque token est adaptatif (clair / sombre chaud). Les écrans n'ont rien à changer :
/// `LumeColor.cream`, `LumeColor.ink`… suivent automatiquement l'apparence système.
/// Le mode sombre garde l'âme « papier chaud » de Lume : anthracite chaud plutôt que noir pur.
enum LumeColor {
    // Surfaces — dark = anthracite chaud (R−B positif), pas noir pur. Contrastes WCAG AA vérifiés.
    static let cream = Color(light: 0xF6F5F1, dark: 0x17150F) // fond app
    static let surface = Color(light: 0xFFFFFF, dark: 0x211E17) // cartes
    static let faint = Color(light: 0xEDEBE5, dark: 0x2B2820) // pistes / fills discrets
    static let border = Color(light: 0xE7E5DF, dark: 0x35312A) // séparateurs
    static let placeholder = Color(light: 0xDED0B6, dark: 0x4A4234) // fond photo en attente
    static let placeholderTint = Color(light: 0xB9A77F, dark: 0xB09C70) // icône sur placeholder

    // Texte — ink ~15:1, textSecondary ~8:1, muted ~4.7:1 sur surface (tous AA).
    static let ink = Color(light: 0x1B1B1D, dark: 0xF3EFE7) // primaire
    static let textSecondary = Color(light: 0x5B5B60, dark: 0xB6AFA3)
    static let muted = Color(light: 0x9A9A9F, dark: 0x8E877C) // tertiaire / labels

    // Macros — identité coral/ambre/bleu conservée, ≥5.9:1 sur surface en dark.
    static let protein = Color(light: 0xF2542D, dark: 0xFF6B47)
    static let carbs = Color(light: 0xF5A623, dark: 0xF7B23B)
    static let fat = Color(light: 0x4A90E2, dark: 0x6BA8F0)

    // Sémantiques — ≥5.3:1 sur surface en dark.
    static let success = Color(light: 0x2FBF71, dark: 0x46CE86)
    static let warning = Color(light: 0xE2B532, dark: 0xE8C24E)
    static let negative = Color(light: 0xE0454F, dark: 0xF0656D)
}

/// Échelle d'opacité du design system : niveaux nommés au lieu de nombres nus dispersés.
/// Sert surtout aux teintes posées sur une couleur (pastilles d'icône, textes secondaires sur fond
/// coloré, pistes translucides). Centralise les valeurs jusque-là codées en dur (0.7, 0.85, 0.14…).
enum LumeOpacity {
    /// Fond de pastille / halo d'icône teintée (cercle derrière un glyphe coloré).
    static let pill: Double = 0.14
    /// Fill très discret (piste de barre, surface translucide sur fond coloré).
    static let track: Double = 0.22
    /// Élément désactivé / fantôme sur fond coloré.
    static let disabled: Double = 0.3
    /// Texte secondaire posé sur un fond coloré (sous-titres du hero).
    static let secondary: Double = 0.7
    /// Texte/contrôle quasi opaque mais légèrement atténué (libellés forts sur fond coloré).
    static let strong: Double = 0.85
}
