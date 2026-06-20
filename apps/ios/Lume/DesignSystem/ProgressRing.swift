import SwiftUI

/// Anneau de progression réutilisable, avec contenu central optionnel.
/// Le remplissage s'anime à l'apparition et au changement de valeur (sauf Reduce Motion).
struct ProgressRing<Center: View>: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 8
    var track: Color = LumeColor.faint
    @ViewBuilder var center: () -> Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animated: Double = 0

    private var clamped: Double {
        max(0, min(1, progress))
    }

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, animated)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
        .onAppear { apply(clamped) }
        .onChange(of: progress) { _, _ in apply(clamped) }
    }

    private func apply(_ value: Double) {
        if reduceMotion { animated = value }
        else { withAnimation(LumeMotion.smooth) { animated = value } }
    }
}

extension ProgressRing where Center == EmptyView {
    init(progress: Double, color: Color, lineWidth: CGFloat = 8, track: Color = LumeColor.faint) {
        self.init(progress: progress, color: color, lineWidth: lineWidth, track: track) { EmptyView() }
    }
}
