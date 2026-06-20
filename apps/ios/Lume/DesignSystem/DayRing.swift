import SwiftUI

/// Élément du sélecteur de semaine : lettre + anneau du jour.
struct DayRing: View {
    var letter: String
    var day: Int
    var progress: Double
    var isToday: Bool
    var body: some View {
        VStack(spacing: Spacing.xs + 2) {
            Text(letter)
                .font(.lumeCaption)
                .foregroundStyle(isToday ? LumeColor.ink : LumeColor.muted)
            ProgressRing(progress: progress,
                         color: progress >= 1 ? LumeColor.success : LumeColor.ink,
                         lineWidth: 2.5)
            {
                Text("\(day)")
                    .font(.system(size: 12, weight: isToday ? .heavy : .semibold))
                    .foregroundStyle(LumeColor.ink)
            }
            .frame(width: 32, height: 32)
        }
    }
}
