import SwiftUI

/// Sélecteur segmenté en pilule (modes de capture, etc.).
struct SegmentedPicker: View {
    var options: [String]
    @Binding var selection: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let active = i == selection
                Text(options[i])
                    .font(.lumeSubhead.weight(.semibold))
                    .foregroundStyle(active ? LumeColor.surface : LumeColor.muted)
                    .padding(.vertical, 9).padding(.horizontal, Spacing.lg - 4)
                    .background(active ? LumeColor.ink : .clear)
                    .clipShape(Capsule())
                    .onTapGesture { withAnimation(LumeMotion.snappy) { selection = i } }
            }
        }
        .padding(Spacing.xs)
        .background(LumeColor.surface)
        .clipShape(Capsule())
        .lumeShadow(.soft)
    }
}
