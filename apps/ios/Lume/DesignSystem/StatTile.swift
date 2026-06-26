import SwiftUI

struct StatTile: View {
    var icon: AppIcon
    var tint: Color
    var value: String
    var label: String
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(appIcon: icon).lumeIcon(18, weight: .semibold).foregroundStyle(tint)
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
