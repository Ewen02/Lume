import SwiftUI

/// Police d'icône qui suit Dynamic Type, à utiliser à la place de `.font(.system(size:))`
/// pour les glyphes (SF Symbols / Image(appIcon:)).
private struct ScaledIconFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(_ size: CGFloat, weight: Font.Weight, relativeTo: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

extension View {
    /// Taille d'icône adaptative (scale avec Dynamic Type).
    func lumeIcon(_ size: CGFloat, weight: Font.Weight = .semibold, relativeTo: Font.TextStyle = .body) -> some View {
        modifier(ScaledIconFont(size, weight: weight, relativeTo: relativeTo))
    }
}
