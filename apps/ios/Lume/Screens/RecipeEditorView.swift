import SwiftData
import SwiftUI

/// Création d'une recette : un nom + des ingrédients piochés dans « Mes aliments » (favoris +
/// aliments custom), chacun à sa portion en grammes. Persiste un `RecipeModel` → la recette est
/// ensuite logable en un geste (tous ses ingrédients d'un coup, en repas groupé).
struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \FavoriteFood.addedAt, order: .reverse) private var favorites: [FavoriteFood]

    @State private var name = ""
    /// Ingrédients en cours de composition (avant enregistrement).
    @State private var drafts: [DraftIngredient] = []
    @State private var showPicker = false

    /// Un ingrédient de la recette en construction : nom + macros/100g + portion.
    private struct DraftIngredient: Identifiable {
        let id = UUID()
        var name: String
        var per100g: Macros
        var grams: Int
        var macros: Macros { per100g.scaled(Double(grams) / 100) }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedName.isEmpty && !drafts.isEmpty }
    private var total: Macros { drafts.reduce(.zero) { $0 + $1.macros } }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                LumeCard {
                    HStack {
                        Text("Nom").font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
                        Spacer()
                        TextField("Ex. Bowl protéiné", text: $name)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.sentences)
                            .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink)
                    }
                }

                if drafts.isEmpty {
                    LumeEmptyState(icon: .lunch, title: "Aucun ingrédient",
                                   message: "Ajoute des aliments depuis tes aliments enregistrés.",
                                   actionTitle: "Ajouter un ingrédient", action: { showPicker = true })
                } else {
                    totalCard
                    ForEach($drafts) { $draft in ingredientRow($draft) }
                    addIngredientButton
                }

                if canSave {
                    PrimaryButton(title: "Enregistrer la recette", icon: .validate) { save() }
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Nouvelle recette", leading: .close, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(isPresented: $showPicker) {
            IngredientPickerView(favorites: favorites) { product in
                drafts.append(DraftIngredient(name: product.name, per100g: product.per100g, grams: 100))
                showPicker = false
            }
        }
    }

    private var totalCard: some View {
        LumeCard(radius: Radius.xxl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(total.kcal)").font(.lumeNumberL).foregroundStyle(LumeColor.ink).monospacedDigit()
                    Text("kcal").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                }
                HStack(spacing: Spacing.sm) {
                    Chip(color: LumeColor.protein, text: "P \(total.protein)")
                    Chip(color: LumeColor.carbs, text: "G \(total.carbs)")
                    Chip(color: LumeColor.fat, text: "L \(total.fat)")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func ingredientRow(_ draft: Binding<DraftIngredient>) -> some View {
        let it = draft.wrappedValue
        return HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(it.name).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                Text("\(it.macros.kcal) kcal").font(.lumeFootnote).foregroundStyle(LumeColor.muted).monospacedDigit()
            }
            Spacer()
            PortionStepper(grams: draft.grams)
        }
        .padding(.horizontal, Spacing.lg - 2).padding(.vertical, Spacing.md)
        .background(LumeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .lumeShadow(.soft)
        .swipeActions {
            Button(role: .destructive) { drafts.removeAll { $0.id == it.id } } label: {
                Image(appIcon: .trash)
            }
        }
        .contextMenu {
            Button(role: .destructive) { drafts.removeAll { $0.id == it.id } } label: {
                Label("Retirer", systemImage: "trash")
            }
        }
    }

    private var addIngredientButton: some View {
        Button { showPicker = true } label: {
            HStack(spacing: Spacing.sm) {
                Image(appIcon: .add).lumeIcon(16, weight: .semibold)
                Text("Ajouter un ingrédient").font(.lumeCallout)
            }.foregroundStyle(LumeColor.ink).frame(maxWidth: .infinity).padding(.vertical, Spacing.md)
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(LumeColor.border, lineWidth: 1))
        }.buttonStyle(.lumePress)
    }

    private func save() {
        guard canSave else { return }
        let recipe = RecipeModel(name: trimmedName)
        ctx.insert(recipe)
        for (i, d) in drafts.enumerated() {
            let ing = RecipeIngredientModel(name: d.name, grams: d.grams, per100g: d.per100g, order: i)
            ing.recipe = recipe
            ctx.insert(ing)
        }
        dismiss()
    }
}

/// Sélecteur d'ingrédient : liste « Mes aliments » (favoris + custom) pour composer une recette.
private struct IngredientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let favorites: [FavoriteFood]
    let onPick: (ScannedProduct) -> Void

    private var products: [ScannedProduct] {
        favorites.map { ScannedProduct(name: $0.name, code: "", source: "Favori", per100g: $0.per100g) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                if products.isEmpty {
                    LumeEmptyState(icon: .favorite, title: "Aucun aliment enregistré",
                                   message: "Crée d'abord des aliments (Mes aliments → +) pour composer une recette.")
                } else {
                    ForEach(products) { product in
                        Button { onPick(product) } label: {
                            FoodRow(name: product.name,
                                    detail: "\(product.per100g.kcal) kcal / 100 g",
                                    kcal: product.per100g.kcal, trailing: .add)
                        }.buttonStyle(.lumePress)
                    }
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Choisir un aliment", leading: .close, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }
}

#Preview { RecipeEditorView().modelContainer(LumeStore.preview) }
