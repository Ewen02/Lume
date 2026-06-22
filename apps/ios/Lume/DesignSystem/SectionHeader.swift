import SwiftUI

struct SectionHeader: View {
    var title: String
    var actionTitle: String? = nil
    var actionIcon: AppIcon? = nil
    var action: () -> Void = {}
    var body: some View {
        HStack {
            Text(title).font(.lumeHeadline).foregroundStyle(LumeColor.ink)
            Spacer()
            if let actionTitle {
                Button(action: action) {
                    HStack(spacing: Spacing.xs) {
                        if let actionIcon { Image(appIcon: actionIcon).lumeIcon(14, weight: .semibold) }
                        Text(actionTitle).font(.lumeSubhead.weight(.semibold))
                    }.foregroundStyle(LumeColor.ink)
                }.buttonStyle(.lumePress)
            }
        }
    }
}
