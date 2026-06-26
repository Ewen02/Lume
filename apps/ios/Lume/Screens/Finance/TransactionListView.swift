import SwiftData
import SwiftUI

/// Historique des transactions d'un mois, avec navigation entre mois + filtres (type / recherche /
/// récurrentes). Filtrage en mémoire sur toutes les transactions (volume mensuel faible).
struct TransactionListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var allTx: [FinanceTransaction]

    @State private var selectedMonth: Date
    @State private var kindFilter = 0 // 0 = tout, 1 = dépenses, 2 = revenus
    @State private var query = ""
    @State private var recurringOnly = false
    @State private var editing: FinanceTransaction?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(month: Date = Date()) {
        _selectedMonth = State(initialValue: month)
    }

    private var monthTx: [FinanceTransaction] {
        let (start, end) = FinanceCalculator.monthBounds(of: selectedMonth)
        return allTx.filter { $0.date >= start && $0.date < end }
    }

    /// Filtre de type : index → kind (nil = tout). L'épargne est filtrable (elle est désormais
    /// saisissable comme une transaction à part entière).
    private static let kindFilters: [TransactionKind?] = [nil, .expense, .income, .saving]
    private var kindFilterKind: TransactionKind? {
        Self.kindFilters[min(kindFilter, Self.kindFilters.count - 1)]
    }

    private var filtered: [FinanceTransaction] {
        monthTx.filter { t in
            let kindOK = kindFilterKind == nil || t.kind == kindFilterKind
            let q = query.trimmingCharacters(in: .whitespaces).lowercased()
            let queryOK = q.isEmpty || t.note.lowercased().contains(q) || t.category.title.lowercased().contains(q)
            let recurringOK = !recurringOnly || t.recurringID != nil
            return kindOK && queryOK && recurringOK
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                MonthStepper(month: $selectedMonth)
                SegmentedPicker(options: ["Tout", "Dépenses", "Revenus", "Épargne"], selection: $kindFilter)
                SearchBar(text: $query, placeholder: "Rechercher une transaction")
                // Filtre « récurrentes seulement » (loyer, salaire, abos auto-générés).
                Button { withAnimation(LumeMotion.snappy) { recurringOnly.toggle() } } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(appIcon: .recurring).lumeIcon(12, weight: .semibold)
                        Text("Récurrentes").font(.lumeFootnote.weight(.semibold))
                    }
                    .foregroundStyle(recurringOnly ? LumeColor.surface : LumeColor.muted)
                    .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.xs)
                    .background(recurringOnly ? LumeColor.ink : LumeColor.faint, in: Capsule())
                }
                .buttonStyle(.lumePress)
                .frame(maxWidth: .infinity, alignment: .leading)

                if filtered.isEmpty {
                    LumeEmptyState(icon: .search, title: "Aucun résultat",
                                   message: "Aucune transaction ne correspond à ce filtre.")
                        .padding(.top, Spacing.xl)
                } else {
                    ForEach(filtered) { t in
                        TransactionRow(category: t.category, title: t.note,
                                       detail: Formatters.dayMonthFR.string(from: t.date).capitalized,
                                       amountCents: t.amountCents, kind: t.kind,
                                       isRecurring: t.recurringID != nil) { editing = t }
                            .transition(.opacity)
                    }
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
            // La liste transitionne quand on change de filtre / recherche.
            .animation(reduceMotion ? nil : LumeMotion.snappy, value: filtered.count)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Transactions", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(item: $editing) { t in TransactionEditorView(entry: t) }
    }
}

#Preview {
    TransactionListView().modelContainer(LumeStore.preview)
}
