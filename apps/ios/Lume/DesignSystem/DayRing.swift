import SwiftUI

/// Élément du sélecteur de semaine : lettre + anneau du jour.
struct DayRing: View {
    var letter: String
    var day: Int
    var progress: Double
    var isToday: Bool
    var isSelected: Bool = false
    var body: some View {
        VStack(spacing: Spacing.xs + 2) {
            Text(letter)
                .font(.lumeCaption)
                .foregroundStyle(isToday || isSelected ? LumeColor.ink : LumeColor.muted)
            ProgressRing(progress: progress,
                         color: progress >= 1 ? LumeColor.success : LumeColor.ink,
                         lineWidth: 2.5)
            {
                Text("\(day)")
                    .font(.lumeCaption.weight(isToday || isSelected ? .heavy : .semibold))
                    .foregroundStyle(LumeColor.ink)
                    .monospacedDigit()
            }
            .frame(width: 32, height: 32)
            // Pastille de sélection : fond crème foncé + contour pour le jour consulté.
            .background(
                Circle().fill(isSelected ? LumeColor.ink.opacity(0.08) : .clear)
                    .padding(-5)
            )
            .overlay(
                Circle().stroke(LumeColor.ink, lineWidth: isSelected && !isToday ? 1.5 : 0)
                    .padding(-5)
            )
        }
        .animation(LumeMotion.snappy, value: isSelected)
    }
}
