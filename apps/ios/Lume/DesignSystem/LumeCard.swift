import SwiftUI

/// Conteneur carte standard (surface + rayon + ombre).
struct LumeCard<Content: View>: View {
    var padding: CGFloat = Spacing.lg
    var radius: CGFloat = Radius.xl
    var shadow: LumeShadowStyle = .card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(LumeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .lumeShadow(shadow)
    }
}
