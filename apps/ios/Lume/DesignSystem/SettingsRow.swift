import SwiftUI

struct SettingsRow: View {
    var icon: AppIcon
    var tint: Color = LumeColor.ink
    var title: LocalizedStringKey
    var value: String? = nil
    var showsChevron: Bool = true
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(appIcon: icon).lumeIcon(16, weight: .semibold).foregroundStyle(tint)
                .frame(width: 36, height: 36).background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(title).font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
            Spacer()
            if let value { Text(value).font(.lumeSubhead).foregroundStyle(LumeColor.muted) }
            if showsChevron { Image(appIcon: .forward).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted) }
        }
        .padding(.horizontal, Spacing.lg - 2).padding(.vertical, Spacing.md)
        // Toute la ligne (Spacer inclus) capte le tap : sans ça, le vide entre le titre et le
        // chevron n'est pas hit-testé et l'utilisateur doit viser le texte ou la flèche.
        .contentShape(Rectangle())
    }
}
