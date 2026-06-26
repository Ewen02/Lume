import SwiftUI

/// Ligne de transaction : pastille catégorie à gauche, libellé + date au centre, montant signé
/// et coloré à droite (revenu vert, dépense ink). Adapté de `FoodRow` mais avec montant signé.
struct TransactionRow: View {
    var category: ExpenseCategory
    var title: String
    var detail: String
    var amountCents: Int
    var kind: TransactionKind
    /// Issue d'une récurrente (loyer, salaire, abo) → petit badge « auto ».
    var isRecurring: Bool = false
    var action: () -> Void = {}

    private var displayTitle: String {
        title.isEmpty ? category.title : title
    }

    /// Montant signé : revenu +, dépense −, épargne sans signe (transfert, pas une perte).
    private var amountText: String {
        switch kind {
        case .income: Money.format(amountCents, showSign: true)
        case .expense: Money.format(-amountCents, showSign: true)
        case .saving: Money.format(amountCents)
        }
    }

    private var amountTint: Color {
        switch kind {
        case .income: LumeColor.success
        case .saving: LumeColor.fat
        case .expense: LumeColor.ink
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(appIcon: category.icon).lumeIcon(16, weight: .semibold).foregroundStyle(category.tint)
                    .frame(width: 38, height: 38).background(category.tint.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(displayTitle).font(.lumeCallout).foregroundStyle(LumeColor.ink).lineLimit(1)
                        if isRecurring {
                            Image(appIcon: .recurring).lumeIcon(10, weight: .semibold).foregroundStyle(LumeColor.muted)
                                .accessibilityLabel("Récurrente")
                        }
                    }
                    Text(detail).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }
                Spacer()
                Text(amountText)
                    .font(.lumeSubhead.weight(.bold)).monospacedDigit()
                    .foregroundStyle(amountTint)
            }
            .padding(.horizontal, Spacing.lg - 2).padding(.vertical, Spacing.md)
            .background(LumeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .lumeShadow(.soft)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lumePress)
    }
}

#Preview {
    VStack(spacing: Spacing.sm) {
        TransactionRow(category: .restaurant, title: "Restaurant midi", detail: "5 juin",
                       amountCents: 4290, kind: .expense)
        TransactionRow(category: .salary, title: "Salaire", detail: "1 juin",
                       amountCents: 210_000, kind: .income)
    }
    .padding()
    .background(LumeColor.cream)
}
