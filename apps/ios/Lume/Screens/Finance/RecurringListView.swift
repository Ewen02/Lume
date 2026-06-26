import SwiftData
import SwiftUI

/// Liste des transactions récurrentes (loyer, abonnements, salaire). Création / édition via éditeur.
struct RecurringListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecurringTransaction.label) private var recurrings: [RecurringTransaction]

    private enum Route: Identifiable {
        case add
        case edit(RecurringTransaction)
        var id: String {
            switch self { case .add: "add"; case let .edit(r): "edit-\(r.id)" }
        }
    }

    @State private var route: Route?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if recurrings.isEmpty {
                    LumeEmptyState(icon: .recurring, title: "Aucune récurrente",
                                   message: "Ajoute tes dépenses fixes (loyer, abonnements) ou ton salaire — elles seront créées automatiquement chaque mois.")
                        .padding(.top, Spacing.xl)
                } else {
                    ForEach(recurrings) { r in
                        Button { route = .edit(r) } label: { row(r) }.buttonStyle(.lumePress)
                    }
                }
                PrimaryButton(title: "Ajouter une récurrente", icon: .add) { route = .add }
                    .padding(.top, Spacing.sm)
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Récurrentes", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(item: $route) { dest in
            switch dest {
            case .add: RecurringEditorView()
            case let .edit(r): RecurringEditorView(entry: r)
            }
        }
    }

    private func row(_ r: RecurringTransaction) -> some View {
        LumeCard {
            HStack(spacing: Spacing.md) {
                Image(appIcon: r.category.icon).lumeIcon(16, weight: .semibold).foregroundStyle(r.category.tint)
                    .frame(width: 38, height: 38).background(r.category.tint.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.label.isEmpty ? r.category.title : r.label).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                    Text("\(r.frequency.title) · jour \(r.dayOfMonth)\(r.isActive ? "" : " · inactif")")
                        .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }
                Spacer()
                Text(Money.format(r.kind == .income ? r.amountCents : -r.amountCents, showSign: true))
                    .font(.lumeSubhead.weight(.bold)).monospacedDigit()
                    .foregroundStyle(r.kind == .income ? LumeColor.success : LumeColor.ink)
            }
        }
    }
}

#Preview {
    RecurringListView().modelContainer(LumeStore.preview)
}
