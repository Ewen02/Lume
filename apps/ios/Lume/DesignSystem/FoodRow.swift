import SwiftUI

/// Ligne d'aliment réutilisable (recherche, favoris, récents).
struct FoodRow: View {
    var name: String
    var detail: String
    var kcal: Int
    var trailing: AppIcon = .add
    var action: () -> Void = {}
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                Text(detail).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
            }
            Spacer()
            Text("\(kcal) kcal").font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.textSecondary).monospacedDigit()
            Button(action: action) {
                Image(appIcon: trailing).lumeIcon(16, weight: .bold).foregroundStyle(LumeColor.surface)
                    .frame(width: 30, height: 30).background(LumeColor.ink).clipShape(Circle())
                    .contentShape(Rectangle()).frame(width: 44, height: 44) // hitbox ≥ 44pt
            }.buttonStyle(.lumePress)
        }
        .padding(.horizontal, Spacing.lg - 2).padding(.vertical, Spacing.md)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .lumeShadow(.soft)
    }
}
