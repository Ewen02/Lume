import SwiftUI

/// Grille de pastilles de catégorie (icône + label + teinte). Sert à la saisie d'une transaction
/// et au filtre de l'historique. Binding sur `ExpenseCategory`.
struct CategoryPicker: View {
    @Binding var selection: ExpenseCategory
    /// Catégories proposées (par défaut : dépenses, hors « Salaire »).
    var categories: [ExpenseCategory] = ExpenseCategory.expenseCases

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: Spacing.sm)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.sm) {
            ForEach(categories) { cat in
                let active = cat == selection
                VStack(spacing: Spacing.xs) {
                    Image(appIcon: cat.icon).lumeIcon(18, weight: .semibold)
                        .foregroundStyle(active ? LumeColor.surface : cat.tint)
                        .frame(width: 40, height: 40)
                        .background(active ? cat.tint : cat.tint.opacity(0.14), in: Circle())
                    Text(cat.title).font(.lumeCaption)
                        .foregroundStyle(active ? LumeColor.ink : LumeColor.muted)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xs)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(LumeMotion.snappy) { selection = cat } }
            }
        }
    }
}

#Preview {
    CategoryPicker(selection: .constant(.food))
        .padding()
        .background(LumeColor.cream)
}
