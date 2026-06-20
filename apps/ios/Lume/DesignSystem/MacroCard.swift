import SwiftUI

struct MacroCard: View {
    var letter: String
    var value: Int
    var goal: Int
    var color: Color
    var label: String
    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(value)").font(.system(size: 16, weight: .heavy)).foregroundStyle(LumeColor.ink)
                Text("/\(goal)").font(.lumeCaption).foregroundStyle(LumeColor.muted)
            }
            ProgressRing(progress: Double(value) / Double(max(goal, 1)), color: color, lineWidth: 5) {
                Text(letter).font(.system(size: 15, weight: .bold)).foregroundStyle(color)
            }
            .frame(width: 46, height: 46)
            Text(label).font(.lumeCaption).foregroundStyle(LumeColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .lumeShadow(.soft)
    }
}

/// Grand bloc calories (chiffre + anneau).
struct CalorieCard: View {
    var consumed: Int
    var goal: Int
    var body: some View {
        let remaining = max(0, goal - consumed)
        LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(remaining)").font(.lumeNumberXL).foregroundStyle(LumeColor.ink)
                            .monospacedDigit()
                        Text("/ \(goal)").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                    }
                    Text("Calories restantes").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                }
                Spacer()
                ProgressRing(progress: Double(consumed) / Double(max(goal, 1)),
                             color: LumeColor.ink, lineWidth: 9)
                {
                    Image(appIcon: .calories).lumeIcon(24, weight: .semibold).foregroundStyle(LumeColor.ink)
                }
                .frame(width: 86, height: 86)
            }
        }
    }
}
