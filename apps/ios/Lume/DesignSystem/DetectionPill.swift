import SwiftUI

/// Étiquette de détection superposée à la photo.
struct DetectionPill: View {
    var color: Color
    var label: String
    var body: some View {
        HStack(spacing: Spacing.xs + 2) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.lumeFootnote.weight(.semibold)).foregroundStyle(LumeColor.ink)
        }
        .padding(.vertical, 7).padding(.horizontal, Spacing.md)
        .background(LumeColor.surface)
        .clipShape(Capsule())
        .lumeShadow(.soft)
    }
}
