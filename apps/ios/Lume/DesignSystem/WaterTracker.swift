import SwiftUI

struct WaterTracker: View {
    var filled: Int
    var total: Int = 8
    var body: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Image(appIcon: .water).lumeIcon(18, weight: .semibold).foregroundStyle(LumeColor.fat)
                Text("Eau").font(.lumeCallout).foregroundStyle(LumeColor.ink)
                Text("\(filled) / \(total) verres").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
            }
            Spacer()
            HStack(spacing: Spacing.xs) {
                ForEach(0 ..< total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i < filled ? LumeColor.fat : LumeColor.faint)
                        .frame(width: 8, height: 18)
                }
            }
        }
        .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.md + 2)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md + 4, style: .continuous))
        .lumeShadow(.soft)
    }
}
