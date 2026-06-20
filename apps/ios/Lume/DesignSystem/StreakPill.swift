import SwiftUI

struct StreakPill: View {
    var days: Int
    var body: some View {
        HStack(spacing: Spacing.xs + 2) {
            Image(appIcon: .streak).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.protein)
            Text("\(days)").font(.lumeCallout).foregroundStyle(LumeColor.ink)
        }
        .padding(.vertical, Spacing.sm).padding(.horizontal, Spacing.lg - 2)
        .background(LumeColor.surface)
        .clipShape(Capsule())
        .lumeShadow(.soft)
    }
}
