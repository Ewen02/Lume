import SwiftData
import SwiftUI

/// Écran « Récompenses » : badges d'un domaine (muscu ou nutrition), débloqués ou verrouillés.
struct BadgesView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var unlocks: [BadgeUnlock]

    var domain: Badge.Domain = .workout

    private var badges: [Badge] {
        BadgeCatalog.all(in: domain)
    }

    private var unlockedIDs: Set<String> {
        Set(unlocks.map(\.badgeID))
    }

    private var unlockedCount: Int {
        badges.filter { unlockedIDs.contains($0.id) }.count
    }

    /// Catégories présentes dans ce domaine.
    private var categories: [Badge.Category] {
        Badge.Category.allCases.filter { cat in badges.contains { $0.category == cat } }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                header
                ForEach(categories) { category in
                    let cat = badges.filter { $0.category == category }
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(title: LocalizedStringKey(category.label))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.md)], spacing: Spacing.md) {
                            ForEach(cat) { badge in
                                cell(badge).lumeEntrance(badges.firstIndex(where: { $0.id == badge.id }) ?? 0)
                            }
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
                    Text("\(unlockedCount) / \(badges.count) badges")
                        .font(.lumeHeadline).foregroundStyle(LumeColor.ink).monospacedDigit()
                    Text(domain == .nutrition ? "Débloque-les en suivant ton alimentation." : "Débloque-les en t'entraînant régulièrement.")
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
