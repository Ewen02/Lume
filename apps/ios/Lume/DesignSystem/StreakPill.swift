import SwiftUI

struct StreakPill: View {
    var days: Int
    var body: some View {
        HStack(spacing: Spacing.xs + 2) {
            StreakFlame(streak: days, size: 15)
            Text("\(days)").font(.lumeCallout).foregroundStyle(LumeColor.ink).monospacedDigit()
        }
        .padding(.vertical, Spacing.sm).padding(.horizontal, Spacing.lg - 2)
        .background(LumeColor.surface)
        .clipShape(Capsule())
        .lumeShadow(.soft)
    }
}
