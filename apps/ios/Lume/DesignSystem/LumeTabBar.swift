import SwiftUI

enum LumeTab: Int, CaseIterable {
    case today, money, workout, progress, profile
    var icon: AppIcon {
        switch self {
        case .today: .today
        case .money: .wallet
        case .workout: .workout
        case .progress: .progress
        case .profile: .profile
        }
    }

    var label: String {
        switch self {
        case .today: "Aujourd'hui"
        case .money: "Budget"
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
                        .lineLimit(1).minimumScaleFactor(0.8) // 5 onglets : « Aujourd'hui » sur 1 ligne
                }
                .foregroundStyle(active ? LumeColor.ink : LumeColor.muted.opacity(0.7))
                .scaleEffect(active ? 1.08 : 1)
                .animation(LumeMotion.snappy, value: selection)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(LumeMotion.snappy) { selection = tab } }
            }
        }
        .padding(.top, Spacing.md + 2).padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .lumeShadow(.card)
    }
}
