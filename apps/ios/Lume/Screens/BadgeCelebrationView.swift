import SwiftUI

/// Feuille de célébration : un ou plusieurs badges fraîchement débloqués, présentés avec un « pop ».
struct BadgeCelebrationView: View {
    @Environment(\.dismiss) private var dismiss
    let badges: [Badge]
    var onClose: () -> Void = {}

    @State private var appeared = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(appIcon: .pr).lumeIcon(48, weight: .bold).foregroundStyle(LumeColor.warning)
                .scaleEffect(appeared ? 1 : 0.4).rotationEffect(.degrees(appeared ? 0 : -20))

            Text(badges.count > 1 ? "Nouveaux badges !" : "Nouveau badge !")
                .font(.lumeTitle).foregroundStyle(LumeColor.ink)

            HStack(spacing: Spacing.lg) {
                ForEach(badges) { badge in
                    VStack(spacing: Spacing.xs) {
                        Image(appIcon: badge.icon).lumeIcon(26, weight: .bold).foregroundStyle(badge.tint)
                            .frame(width: 72, height: 72).background(badge.tint.opacity(0.14), in: Circle())
                        Text(badge.title).font(.lumeCaption.weight(.semibold)).foregroundStyle(LumeColor.ink)
                            .multilineTextAlignment(.center).lineLimit(2)
                    }.frame(maxWidth: 100)
                }
            }
            .scaleEffect(appeared ? 1 : 0.7)

            if let detail = badges.first?.detail, badges.count == 1 {
                Text(detail).font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                    .multilineTextAlignment(.center).padding(.horizontal, Spacing.lg)
            }

            Spacer()
            PrimaryButton(title: "Super !", icon: .validate) { onClose(); dismiss() }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .background(LumeColor.cream.ignoresSafeArea())
        .presentationDetents([.medium])
        .onAppear { withAnimation(LumeMotion.celebrate.delay(0.1)) { appeared = true } }
        .sensoryFeedback(.success, trigger: appeared)
    }
}

#Preview {
    BadgeCelebrationView(badges: [BadgeCatalog.all.first!])
}
