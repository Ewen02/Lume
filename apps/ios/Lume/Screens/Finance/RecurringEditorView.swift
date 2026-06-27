import SwiftData
import SwiftUI

/// Création / édition d'une transaction récurrente.
struct RecurringEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    private let existing: RecurringTransaction?

    @State private var label: String
    @State private var cents: Int
    @State private var category: ExpenseCategory
    @State private var frequencyIndex: Int
    @State private var dayOfMonth: Int
    @State private var isActive: Bool
    @State private var showDeleteConfirm = false

    init() {
        existing = nil
        _label = State(initialValue: "")
        _cents = State(initialValue: 0)
        _category = State(initialValue: .subscriptions)
        _frequencyIndex = State(initialValue: 0)
        _dayOfMonth = State(initialValue: 1)
        _isActive = State(initialValue: true)
    }

    init(entry: RecurringTransaction) {
        existing = entry
        _label = State(initialValue: entry.label)
        _cents = State(initialValue: entry.amountCents)
        // Une récurrente héritée pouvait être revenu/épargne ; en édition on la ramène à une dépense.
        _category = State(initialValue: entry.kind == .expense ? entry.category : .subscriptions)
        _frequencyIndex = State(initialValue: entry.frequency == .weekly ? 1 : 0)
        _dayOfMonth = State(initialValue: entry.dayOfMonth)
        _isActive = State(initialValue: entry.isActive)
    }

    /// Une récurrente est TOUJOURS une dépense fixe : revenu/épargne/loyer sont gérés par le profil
    /// (« Mon budget »). On ne propose donc plus de picker de type ici.
    private let kind: TransactionKind = .expense

    private var frequency: RecurrenceFrequency {
        frequencyIndex == 1 ? .weekly : .monthly
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                LumeCard {
                    TextField("Nom (ex. Spotify, Assurance)", text: $label)
                        .font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                }
                LumeCard { AmountStepper(cents: $cents, tint: kind.tint) }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionHeader(title: "Catégorie")
                    // Loyer exclu : il se gère dans « Mon budget » (sinon double-comptage).
                    CategoryPicker(selection: $category, categories: ExpenseCategory.manualRecurringExpenseCases)
                }

                SegmentedPicker(options: ["Mensuel", "Hebdomadaire"], selection: $frequencyIndex)

                if frequency == .monthly {
                    LumeCard {
                        HStack {
                            Text("Jour du mois").font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
                            Spacer()
                            Stepper("\(dayOfMonth)", value: $dayOfMonth, in: 1 ... 31)
                                .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).fixedSize()
                        }
                    }
                    if dayOfMonth > 28 {
                        Text("Les mois plus courts utiliseront leur dernier jour.")
                            .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                    }
                }

                LumeCard {
                    Toggle(isOn: $isActive) {
                        Text("Active").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                    }.tint(LumeColor.ink)
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
            TopBar(title: existing == nil ? "Nouvelle récurrente" : "Modifier", leading: .close, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(isPresented: $showDeleteConfirm) {
            LumeConfirmSheet(icon: .trash, tint: LumeColor.negative,
                             title: "Supprimer cette récurrente ?",
                             message: "Les transactions déjà créées sont conservées.",
                             confirmTitle: "Supprimer") { delete() }
                .presentationDetents([.height(280)])
        }
    }

    private func save() {
        guard cents > 0 else { return }
        // Toujours une dépense fixe (kind == .expense) ; la catégorie choisie ne peut pas être housing.
        if let e = existing {
            e.label = label
            e.amountCents = cents
            e.kindRaw = kind.rawValue
            e.categoryRaw = category.rawValue
            e.frequencyRaw = frequency.rawValue
            e.dayOfMonth = min(31, max(1, dayOfMonth))
            e.isActive = isActive
        } else {
            ctx.insert(RecurringTransaction(label: label, amountCents: cents, kind: kind, category: category,
                                            frequency: frequency, dayOfMonth: dayOfMonth, isActive: isActive))
        }
        dismiss()
    }

    private func delete() {
        if let e = existing { ctx.delete(e) }
        dismiss()
    }
}

#Preview {
    RecurringEditorView().modelContainer(LumeStore.preview)
}
