import SwiftUI

/// Échelle typographique Lume.
/// Mappée sur les *text styles* système → suit automatiquement Dynamic Type
/// (best practice WWDC : pas de tailles figées pour le texte).
/// Les chiffres conservent un poids fort ; appliquer `.monospacedDigit()` au besoin.
extension Font {
    static let lumeNumberXL = Font.system(.largeTitle, design: .default, weight: .heavy)
    static let lumeNumberL = Font.system(.title, design: .default, weight: .heavy)
    static let lumeDisplay = Font.system(.title2, design: .default, weight: .heavy)
    static let lumeTitle = Font.system(.title3, design: .default, weight: .bold)
    static let lumeTitle3 = Font.system(.headline, design: .default, weight: .bold)
    static let lumeHeadline = Font.system(.headline, design: .default, weight: .semibold)
    static let lumeBody = Font.system(.subheadline, design: .default, weight: .regular)
    static let lumeBodyMed = Font.system(.subheadline, design: .default, weight: .medium)
    static let lumeCallout = Font.system(.subheadline, design: .default, weight: .semibold)
    static let lumeSubhead = Font.system(.footnote, design: .default, weight: .medium)
    static let lumeFootnote = Font.system(.caption, design: .default, weight: .regular)
    static let lumeCaption = Font.system(.caption2, design: .default, weight: .semibold)
}
