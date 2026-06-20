import SwiftUI

/// Pastille valeur avec point coloré (macros, filtres).
struct Chip: View {
    var color: Color
    var text: String
    var body: some View {
        HStack(spacing: Spacing.xs + 2) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.lumeFootnote.weight(.semibold)).foregroundStyle(LumeColor.ink)
        }
        .padding(.vertical, 7).padding(.horizontal, 11)
        .background(LumeColor.cream)
        .clipShape(Capsule())
    }
}
