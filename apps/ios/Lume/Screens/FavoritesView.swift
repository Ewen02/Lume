import SwiftData
import SwiftUI

/// « Mes aliments » : favoris épinglés + aliments récents du journal, prêts à relogger.
struct FavoritesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \FavoriteFood.addedAt, order: .reverse) private var favorites: [FavoriteFood]
    @Query(sort: \LoggedFood.date, order: .reverse) private var logged: [LoggedFood]
    @Query(sort: \RecipeModel.createdAt, order: .reverse) private var recipes: [RecipeModel]

    @State private var tab = 0
    @State private var routeFood: FoodItem?
    @State private var showCustomEditor = false
    @State private var showRecipeEditor = false
    /// Recette qui vient d'être journalisée (déclenche l'haptique de succès + le retour).
    @State private var loggedRecipeID: UUID?

    /// Favoris (macros pour 100 g).
    private var favProducts: [ScannedProduct] {
        favorites.map { ScannedProduct(name: $0.name, code: "", source: "Favori", per100g: $0.per100g) }
    }

    /// Récents : derniers aliments distincts du journal (par nom), ramenés à 100 g.
    private var recents: [ScannedProduct] {
        var seen = Set<String>()
        var out: [ScannedProduct] = []
        for f in logged where !seen.contains(f.name.lowercased()) {
            seen.insert(f.name.lowercased())
            let factor = 100.0 / Double(max(f.grams, 1))
            out.append(ScannedProduct(name: f.name, code: "", source: "Journal",
                                      per100g: f.macros.scaled(factor)))
            if out.count >= 30 { break }
        }
        return out
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            SegmentedPicker(options: ["Favoris", "Récents", "Recettes"], selection: $tab)
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    content
                }
                .padding(.bottom, Spacing.xxl)
                .animation(LumeMotion.smooth, value: tab)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xl)
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            // Le « + » crée un aliment (onglets Favoris/Récents) ou une recette (onglet Recettes).
            TopBar(title: "Mes aliments", leading: .back, trailing: .add,
                   onLeading: { dismiss() }, onTrailing: { if tab == 2 { showRecipeEditor = true } else { showCustomEditor = true } })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(item: $routeFood) { FoodDetailView(food: $0, meal: .snack, canAddToJournal: true) }
        .sheet(isPresented: $showCustomEditor) { CustomFoodEditorView() }
        .sheet(isPresented: $showRecipeEditor) { RecipeEditorView() }
        .sensoryFeedback(.success, trigger: loggedRecipeID)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case 0:
            if favProducts.isEmpty {
                LumeEmptyState(icon: .favorite, title: "Aucun aliment enregistré",
                               message: "Crée ton propre aliment (repas maison, plat de resto…) ou épingle un résultat de recherche.",
                               actionTitle: "Créer un aliment", action: { showCustomEditor = true })
            } else {
                ForEach(favProducts) { row($0) }
            }
        case 1:
            if recents.isEmpty {
                LumeEmptyState(icon: .recents, title: "Aucun aliment récent",
                               message: "Les aliments que tu logues apparaîtront ici.")
            } else {
                ForEach(recents) { row($0) }
            }
        default:
            if recipes.isEmpty {
                LumeEmptyState(icon: .lunch, title: "Aucune recette",
                               message: "Compose un plat à partir de tes aliments enregistrés, logable en un geste.",
                               actionTitle: "Créer une recette", action: { showRecipeEditor = true })
            } else {
                ForEach(recipes) { recipeRow($0) }
            }
        }
    }

    /// Ligne recette : tap → journalise la recette (repas groupé) ; menu → supprimer.
    private func recipeRow(_ recipe: RecipeModel) -> some View {
        let total = recipe.totalMacros
        let count = recipe.orderedIngredients.count
        return Button {
            RecipeLogger.log(recipe, into: ctx)
            loggedRecipeID = recipe.id
            dismiss()
        } label: {
            FoodRow(name: recipe.name,
                    detail: String(localized: "\(count) ingrédients · \(total.kcal) kcal"),
                    kcal: total.kcal, trailing: .add)
        }
        .buttonStyle(.lumePress)
        .contextMenu {
            Button(role: .destructive) { ctx.delete(recipe) } label: {
                Label("Supprimer la recette", systemImage: "trash")
            }
        }
    }

    private func row(_ product: ScannedProduct) -> some View {
        Button { routeFood = FoodItem(name: product.name, grams: 100, macros: product.per100g) } label: {
            FoodRow(name: product.name,
                    detail: "\(product.per100g.kcal) kcal / 100 g · \(product.source)",
                    kcal: product.per100g.kcal,
                    trailing: .add)
        }
        .buttonStyle(.lumePress)
        .contextMenu {
            if tab == 0 {
                Button(role: .destructive) { removeFavorite(product) } label: {
                    Label("Retirer des favoris", systemImage: "star.slash")
                }
            } else if !isFavorite(product) {
                Button { addFavorite(product) } label: { Label("Ajouter aux favoris", systemImage: "star") }
            }
        }
    }

    private func isFavorite(_ p: ScannedProduct) -> Bool {
        favorites.contains { $0.name.lowercased() == p.name.lowercased() }
    }

    private func addFavorite(_ p: ScannedProduct) {
        guard !isFavorite(p) else { return }
        ctx.insert(FavoriteFood(name: p.name, per100g: p.per100g))
    }

    private func removeFavorite(_ p: ScannedProduct) {
        for f in favorites where f.name.lowercased() == p.name.lowercased() {
            ctx.delete(f)
        }
    }
}

#Preview { FavoritesView().modelContainer(LumeStore.preview) }
