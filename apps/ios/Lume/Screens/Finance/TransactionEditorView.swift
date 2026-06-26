import SwiftData
import SwiftUI

/// Saisie / édition d'une transaction. Deux inits : création (`init()`) et édition (`init(entry:)`),
/// cf. le pattern d'AnalyzeView. Le montant est stocké TOUJOURS positif ; le signe vient du `kind`.
struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    private let existing: FinanceTransaction?
    var onSaved: () -> Void = {}

    @State private var kindIndex: Int
    @State private var cents: Int
    @State private var category: ExpenseCategory
    @State private var date: Date
    @State private var note: String
    @State private var showDeleteConfirm = false

    /// Ordre des segments du picker de type : index → `TransactionKind`.
    private static let kinds: [TransactionKind] = [.expense, .income, .saving]
    private static func index(of kind: TransactionKind) -> Int {
        kinds.firstIndex(of: kind) ?? 0
    }

    init(onSaved: @escaping () -> Void = {}) {
        existing = nil
        self.onSaved = onSaved
        _kindIndex = State(initialValue: 0)
        _cents = State(initialValue: 0)
        _category = State(initialValue: .food)
        _date = State(initialValue: Date())
        _note = State(initialValue: "")
    }

    init(entry: FinanceTransaction, onSaved: @escaping () -> Void = {}) {
        existing = entry
        self.onSaved = onSaved
        _kindIndex = State(initialValue: Self.index(of: entry.kind))
        _cents = State(initialValue: entry.amountCents)
        _category = State(initialValue: entry.category)
        _date = State(initialValue: entry.date)
        _note = State(initialValue: entry.note)
    }

    private var kind: TransactionKind {
        Self.kinds[min(kindIndex, Self.kinds.count - 1)]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Type sur 3 segments : Dépense / Revenu / Épargne (l'épargne est désormais saisissable
                // directement, plus seulement à l'édition).
                SegmentedPicker(options: ["Dépense", "Revenu", "Épargne"], selection: $kindIndex)
                    .onChange(of: kindIndex) { _, _ in
                        // Bascule cohérente : revenu → Salaire, épargne → Épargne, dépense → catégorie de dépense.
                        switch kind {
                        case .income: category = .salary
                        case .saving: category = .savings
                        case .expense: if category == .salary || category == .savings { category = .food }
                        }
                    }

                LumeCard { AmountStepper(cents: $cents, tint: kind.tint) }

                if kind == .expense {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(title: "Catégorie")
                        CategoryPicker(selection: $category)
                    }
                }

                LumeCard {
                    VStack(spacing: Spacing.md) {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .font(.lumeBodyMed).tint(LumeColor.ink)
                        Divider().background(LumeColor.border)
                        TextField("Note (facultatif)", text: $note)
                            .font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
                    }
                }

                PrimaryButton(title: "Enregistrer", icon: .validate) { save() }
                    .disabled(cents <= 0).opacity(cents <= 0 ? 0.5 : 1)

                if existing != nil {
                    SecondaryButton(title: "Supprimer", icon: .trash) { showDeleteConfirm = true }
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: existing == nil ? "Nouvelle transaction" : "Modifier", leading: .close, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(isPresented: $showDeleteConfirm) {
            LumeConfirmSheet(icon: .trash, tint: LumeColor.negative,
                             title: "Supprimer cette transaction ?",
                             message: "Cette action est irréversible.",
                             confirmTitle: "Supprimer") { delete() }
                .presentationDetents([.height(280)])
        }
    }

    /// Catégorie cohérente avec le type : épargne → savings, revenu → salaire, dépense → choisie.
    private var resolvedCategory: ExpenseCategory {
        switch kind {
        case .saving: .savings
        case .income: .salary
        case .expense: category
        }
    }

    private func save() {
        guard cents > 0 else { return }
        if let e = existing {
            e.amountCents = cents
            e.kindRaw = kind.rawValue
            e.categoryRaw = resolvedCategory.rawValue
            e.date = date
            e.note = note
        } else {
            ctx.insert(FinanceTransaction(date: date, amountCents: cents, kind: kind,
                                          category: resolvedCategory, note: note))
        }
        onSaved()
        dismiss()
    }

    private func delete() {
        if let e = existing { ctx.delete(e) }
        onSaved()
        dismiss()
    }
}

#Preview("Création") {
    TransactionEditorView().modelContainer(LumeStore.preview)
}
