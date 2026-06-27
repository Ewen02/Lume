import SwiftData
import SwiftUI

/// Liste des dépenses fixes récurrentes (abonnements, assurances…). Revenu/loyer/épargne se gèrent
/// dans « Mon budget », pas ici. Création / édition via éditeur, suppression par glissement.
struct RecurringListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \RecurringTransaction.label) private var recurrings: [RecurringTransaction]

    private enum Route: Identifiable {
        case add
        case edit(RecurringTransaction)
        var id: String {
            switch self { case .add: "add"; case let .edit(r): "edit-\(r.id)" }
        }
    }

    @State private var route: Route?
    @State private var pendingDelete: RecurringTransaction?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if recurrings.isEmpty {
                    LumeEmptyState(icon: .recurring, title: "Aucune dépense fixe",
                                   message: "Ajoute tes abonnements ou assurances — ils seront créés automatiquement chaque mois. (Ton revenu, ton loyer et ton épargne se gèrent dans « Mon budget ».)")
                        .padding(.top, Spacing.xl)
                } else {
                    ForEach(recurrings) { r in
                        row(r)
                    }
                }
                PrimaryButton(title: "Ajouter une dépense fixe", icon: .add) { route = .add }
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
        .sheet(item: $pendingDelete) { r in
            LumeConfirmSheet(icon: .trash, tint: LumeColor.negative,
                             title: "Supprimer « \(r.label.isEmpty ? r.category.title : r.label) » ?",
                             message: "Les transactions déjà créées sont conservées.",
                             confirmTitle: "Supprimer") { ctx.delete(r) }
                .presentationDetents([.height(280)])
        }
    }

    private func row(_ r: RecurringTransaction) -> some View {
        LumeCard {
            HStack(spacing: Spacing.md) {
                Image(appIcon: r.category.icon).lumeIcon(16, weight: .semibold).foregroundStyle(r.category.tint)
                    .frame(width: 38, height: 38).background(r.category.tint.opacity(LumeOpacity.pill), in: Circle())
                // Zone tappable principale → édition.
                Button { route = .edit(r) } label: {
                    HStack(spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.label.isEmpty ? r.category.title : r.label).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                            Text("\(r.frequency.title) · jour \(r.dayOfMonth)\(r.isActive ? "" : " · inactif")")
                                .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                        }
                        Spacer()
                        Text(Money.format(-r.amountCents, showSign: true))
                            .font(.lumeSubhead.weight(.bold)).monospacedDigit().foregroundStyle(LumeColor.ink)
                    }
                    .contentShape(Rectangle())
                }.buttonStyle(.lumePress)
                // Bouton supprimer dédié (découvrable, avec confirmation).
                Button { pendingDelete = r } label: {
                    Image(appIcon: .trash).lumeIcon(16, weight: .semibold).foregroundStyle(LumeColor.muted)
                        .frame(width: 32, height: 32).contentShape(Rectangle())
                }.buttonStyle(.lumePress).accessibilityLabel("Supprimer")
            }
        }
    }
}

#Preview {
    RecurringListView().modelContainer(LumeStore.preview)
}
