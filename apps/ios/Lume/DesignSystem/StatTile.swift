import SwiftUI

struct StatTile: View {
    var icon: AppIcon
    var tint: Color
    var value: String
    var label: String
    /// Si vrai, l'icône est posée dans une pastille teintée (cercle) au lieu d'être nue.
    /// Opt-in pour différencier visuellement certaines tuiles ; les usages existants restent inchangés.
    var iconInPill: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if iconInPill {
                Image(appIcon: icon).lumeIcon(16, weight: .semibold).foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(LumeOpacity.pill), in: Circle())
            } else {
                Image(appIcon: icon).lumeIcon(18, weight: .semibold).foregroundStyle(tint)
            }
            Text(value).font(.lumeTitle).foregroundStyle(LumeColor.ink).monospacedDigit()
                .contentTransition(.numericText()) // chiffres roulants quand la valeur change
            Text(label).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .lumeShadow(.soft)
    }
}
