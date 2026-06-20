import SwiftUI

struct MealCell: View {
    var icon: AppIcon
    var tint: Color
    var title: String
    var subtitle: String
    var kcal: Int
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(appIcon: icon)
                .lumeIcon(20, weight: .semibold)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(LumeColor.cream)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                Text(subtitle).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(kcal)").font(.lumeCallout.weight(.bold)).foregroundStyle(LumeColor.ink).monospacedDigit()
                Text("kcal").font(.lumeCaption.weight(.regular)).foregroundStyle(LumeColor.muted)
            }
        }
        .padding(.horizontal, Spacing.lg - 2).padding(.vertical, Spacing.md)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .lumeShadow(.soft)
    }
}
