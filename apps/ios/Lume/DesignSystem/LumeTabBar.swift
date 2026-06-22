import SwiftUI

enum LumeTab: Int, CaseIterable {
    case today, workout, progress, profile
    var icon: AppIcon {
        switch self {
        case .today: .today
        case .workout: .workout
        case .progress: .progress
        case .profile: .profile
        }
    }

    var label: String {
        switch self {
        case .today: "Aujourd'hui"
        case .workout: "Muscu"
        case .progress: "Progrès"
        case .profile: "Profil"
        }
    }
}

struct LumeTabBar: View {
    @Binding var selection: LumeTab
    var body: some View {
        HStack {
            ForEach(LumeTab.allCases, id: \.rawValue) { tab in
                let active = tab == selection
                VStack(spacing: 5) {
                    Image(appIcon: tab.icon).lumeIcon(22, weight: .regular)
                    Text(tab.label).font(.lumeCaption)
                }
                .foregroundStyle(active ? LumeColor.ink : LumeColor.muted.opacity(0.7))
                .scaleEffect(active ? 1.08 : 1)
                .animation(LumeMotion.snappy, value: selection)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(LumeMotion.snappy) { selection = tab } }
            }
        }
        .padding(.top, Spacing.md + 2).padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.sm)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .lumeShadow(.card)
    }
}
