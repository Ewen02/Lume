import SwiftData
import SwiftUI

/// Écran « Récompenses » : tous les badges, débloqués ou verrouillés, groupés par catégorie.
struct BadgesView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var unlocks: [BadgeUnlock]

    private var unlockedIDs: Set<String> { Set(unlocks.map(\.badgeID)) }

    private var unlockedCount: Int {
        BadgeCatalog.all.filter { unlockedIDs.contains($0.id) }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                header
                ForEach(Badge.Category.allCases) { category in
                    let badges = BadgeCatalog.all.filter { $0.category == category }
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(title: category.label)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.md)], spacing: Spacing.md) {
                            ForEach(badges) { badge in cell(badge) }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Récompenses", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }

    private var header: some View {
        LumeCard {
            HStack(spacing: Spacing.md) {
                Image(appIcon: .pr).lumeIcon(22, weight: .bold).foregroundStyle(LumeColor.warning)
                    .frame(width: 48, height: 48).background(LumeColor.warning.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(unlockedCount) / \(BadgeCatalog.all.count) badges")
                        .font(.lumeHeadline).foregroundStyle(LumeColor.ink).monospacedDigit()
                    Text("Débloque-les en t'entraînant régulièrement.")
                        .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }
                Spacer()
            }
        }
    }

    private func cell(_ badge: Badge) -> some View {
        let unlocked = unlockedIDs.contains(badge.id)
        return VStack(spacing: Spacing.xs) {
            Image(appIcon: unlocked ? badge.icon : .lock)
                .lumeIcon(24, weight: .bold)
                .foregroundStyle(unlocked ? badge.tint : LumeColor.muted)
                .frame(width: 64, height: 64)
                .background((unlocked ? badge.tint : LumeColor.muted).opacity(unlocked ? 0.14 : 0.08), in: Circle())
            Text(badge.title).font(.lumeCaption.weight(.semibold))
                .foregroundStyle(unlocked ? LumeColor.ink : LumeColor.muted)
                .multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .opacity(unlocked ? 1 : 0.6)
        .padding(.vertical, Spacing.sm)
    }
}

#Preview { BadgesView().modelContainer(LumeStore.preview) }
