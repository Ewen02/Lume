import SwiftData
import SwiftUI

/// « Mes aliments » : favoris épinglés + aliments récents du journal, prêts à relogger.
struct FavoritesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \FavoriteFood.addedAt, order: .reverse) private var favorites: [FavoriteFood]
    @Query(sort: \LoggedFood.date, order: .reverse) private var logged: [LoggedFood]

    @State private var tab = 0
    @State private var routeFood: FoodItem?
    @State private var showCustomEditor = false

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
            SegmentedPicker(options: ["Favoris", "Récents"], selection: $tab)
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
            TopBar(title: "Mes aliments", leading: .back, trailing: .add,
                   onLeading: { dismiss() }, onTrailing: { showCustomEditor = true })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(item: $routeFood) { FoodDetailView(food: $0, meal: .snack, canAddToJournal: true) }
        .sheet(isPresented: $showCustomEditor) { CustomFoodEditorView() }
    }

    @ViewBuilder
    private var content: some View {
        if tab == 0 {
            if favProducts.isEmpty {
                LumeEmptyState(icon: .favorite, title: "Aucun aliment enregistré",
                               message: "Crée ton propre aliment (repas maison, plat de resto…) ou épingle un résultat de recherche.",
                               actionTitle: "Créer un aliment", action: { showCustomEditor = true })
            } else {
                ForEach(favProducts) { row($0) }
            }
        } else {
            if recents.isEmpty {
                LumeEmptyState(icon: .recents, title: "Aucun aliment récent",
                               message: "Les aliments que tu logues apparaîtront ici.")
            } else {
                ForEach(recents) { row($0) }
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
