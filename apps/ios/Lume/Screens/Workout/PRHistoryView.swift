import SwiftData
import SwiftUI

struct PRHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSessionModel.date) private var sessions: [WorkoutSessionModel]

    /// Meilleur 1RM estimé par exercice, à partir des séances persistées (aucun repli démo).
    private var prs: [(String, String, String)] {
        WorkoutStats.topPRs(from: sessions)
            .map { ($0.exercise, "\($0.oneRM) kg", Formatters.relative($0.date)) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                if prs.isEmpty {
                    LumeEmptyState(icon: .pr, title: "Aucun record",
                                   message: "Termine une séance pour voir tes records de force apparaître ici.")
                        .padding(.top, Spacing.xxl)
                } else {
                    ForEach(prs, id: \.0) { pr in
                        HStack(spacing: Spacing.md) {
                            Image(appIcon: .pr).lumeIcon(18, weight: .semibold).foregroundStyle(LumeColor.warning)
                                .frame(width: 44, height: 44).background(LumeColor.warning.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pr.0).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                                Text(pr.2).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                            }
                            Spacer()
                            Text(pr.1).font(.lumeHeadline).foregroundStyle(LumeColor.ink).monospacedDigit()
                        }
                        .padding(Spacing.lg - 2).background(LumeColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
                    }
                }
            }.padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Records", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }
}

#Preview { PRHistoryView().modelContainer(LumeStore.preview) }
