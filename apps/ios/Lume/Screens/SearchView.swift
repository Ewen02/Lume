import SwiftData
import SwiftUI
import Translation

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.foodAPI) private var api
    @Environment(\.modelContext) private var ctx
    @Query(sort: \LoggedFood.date, order: .reverse) private var logged: [LoggedFood]
    @Query(sort: \FavoriteFood.addedAt, order: .reverse) private var favorites: [FavoriteFood]

    @State private var query = ""
    @State private var tab = 0
    @State private var results: [ScannedProduct] = []
    @State private var loading = false
    @State private var searchError = false
    @State private var searchTask: Task<Void, Never>?
    @State private var routeFood: FoodItem?
    /// Traduction native iOS 18+ : la session est fournie par .translationTask.
    @State private var translationSession: TranslationSession?

    /// Récents : derniers aliments distincts du journal (par nom).
    private var recents: [ScannedProduct] {
        var seen = Set<String>()
        var out: [ScannedProduct] = []
        for f in logged where !seen.contains(f.name.lowercased()) {
            seen.insert(f.name.lowercased())
            // Ramène les macros à 100 g comme base de recherche.
            let factor = 100.0 / Double(max(f.grams, 1))
            out.append(ScannedProduct(name: f.name, code: "", source: "Journal",
                                      per100g: f.macros.scaled(factor)))
            if out.count >= 20 { break }
        }
        return out
    }

    private var favProducts: [ScannedProduct] {
        favorites.map { ScannedProduct(name: $0.name, code: "", source: "Favori", per100g: $0.per100g) }
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            SearchBar(text: $query, placeholder: "Rechercher un aliment")
                .onSubmit { startSearch(debounced: false) }
                .onChange(of: query) { _, v in
                    searchTask?.cancel() // annule la requête en vol avant d'en lancer une autre
                    if v.trimmingCharacters(in: .whitespaces).count < 3 { results = []; searchError = false }
                    else { startSearch(debounced: true) }
                }
            SegmentedPicker(options: ["Recherche", "Récents", "Favoris"], selection: $tab)

            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    content
                }
                .padding(.bottom, Spacing.xxl)
                .animation(LumeMotion.smooth, value: tab)
                .animation(LumeMotion.smooth, value: loading)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xl)
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Rechercher", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(item: $routeFood) { FoodDetailView(food: $0, meal: .snack, canAddToJournal: true) }
        // Prépare la traduction FR→EN locale (télécharge le modèle au besoin) et garde la session.
        .translationTask(
            TranslationSession.Configuration(source: Locale.Language(identifier: "fr"),
                                             target: Locale.Language(identifier: "en"))
        ) { session in
            translationSession = session
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case 0: searchTab
        case 1: list(recents, icon: .recents, emptyTitle: "Aucun aliment récent",
                     emptyMsg: "Les aliments que tu logues apparaîtront ici.")
        default: favoritesTab
        }
    }

    /// Correspondances dans tes données françaises (journal + favoris), filtrées par la requête.
    private var localMatches: [ScannedProduct] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var seen = Set<String>()
        var out: [ScannedProduct] = []
        for p in favProducts + recents where p.name.lowercased().contains(q) {
            let key = p.name.lowercased()
            if !seen.contains(key) { seen.insert(key); out.append(p) }
        }
        return out
    }

    /// Résultats affichés : tes aliments (français) d'abord, puis l'API (anglais), dédupliqués.
    private var combinedResults: [ScannedProduct] {
        var seen = Set(localMatches.map { $0.name.lowercased() })
        var out = localMatches
        for r in results where !seen.contains(r.name.lowercased()) {
            seen.insert(r.name.lowercased()); out.append(r)
        }
        return out
    }

    @ViewBuilder
    private var searchTab: some View {
        let items = combinedResults
        if query.isEmpty {
            LumeEmptyState(icon: .search, title: "Recherche un aliment",
                           message: "Tape un nom puis valide. Astuce : pour la base mondiale, l'anglais marche mieux (ex. « chicken »).")
        } else if loading, items.isEmpty {
            LumeSkeletonList(count: 6)
        } else if searchError, items.isEmpty {
            LumeErrorState(title: "Recherche indisponible",
                           message: "Impossible de joindre la base d'aliments. Vérifie ta connexion.",
                           retry: { startSearch(debounced: false) })
        } else if items.isEmpty {
            LumeEmptyState(icon: .search, title: "Aucun résultat",
                           message: "Essaie en anglais (ex. « lettuce » pour laitue).")
        } else {
            ForEach(items) { row($0, favoritable: true) }
        }
    }

    @ViewBuilder
    private var favoritesTab: some View {
        if favProducts.isEmpty {
            LumeEmptyState(icon: .favorite, title: "Aucun favori",
                           message: "Épingle un aliment (appui long) pour le retrouver vite.")
        } else {
            ForEach(favProducts) { row($0, favoritable: false) }
        }
    }

    @ViewBuilder
    private func list(_ items: [ScannedProduct], icon: AppIcon, emptyTitle: String, emptyMsg: String) -> some View {
        if items.isEmpty {
            LumeEmptyState(icon: icon, title: emptyTitle, message: emptyMsg)
        } else {
            ForEach(items) { row($0, favoritable: true) }
        }
    }

    private func row(_ product: ScannedProduct, favoritable: Bool) -> some View {
        Button { routeFood = item(from: product) } label: {
            FoodRow(name: product.name,
                    detail: "\(product.per100g.kcal) kcal / 100 g · \(product.source)",
                    kcal: product.per100g.kcal, trailing: .add)
        }
        .buttonStyle(.lumePress)
        .contextMenu {
            if favoritable, !isFavorite(product) {
                Button { addFavorite(product) } label: { Label("Ajouter aux favoris", systemImage: "star") }
            }
            if isFavorite(product) {
                Button(role: .destructive) { removeFavorite(product) } label: {
                    Label("Retirer des favoris", systemImage: "star.slash")
                }
            }
        }
    }

    private func item(from p: ScannedProduct) -> FoodItem {
        FoodItem(name: p.name, grams: 100, macros: p.per100g)
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

    /// Lance une recherche annulable. `debounced` ajoute une pause de frappe (500 ms).
    /// Un seul Task à la fois : on annule le précédent dans `.onChange`.
    private func startSearch(debounced: Bool) {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 3 else { results = []; return }
        searchTask = Task { await runSearch(q, debounced: debounced) }
    }

    private func runSearch(_ q: String, debounced: Bool) async {
        if debounced {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
        }
        loading = true
        searchError = false
        defer { loading = false }
        do {
            var found = try await api.search(q)
            // Rien en français → on traduit en anglais et on réessaie (USDA/OFF anglophones).
            if found.isEmpty, let en = await englishTerm(for: q), en.lowercased() != q.lowercased() {
                guard !Task.isCancelled else { return }
                found = try await api.search(en)
            }
            // Garde anti-périmé : n'écrit que si la requête est toujours d'actualité.
            guard !Task.isCancelled, q == query.trimmingCharacters(in: .whitespaces) else { return }
            results = found
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            searchError = true
        }
    }

    /// Traduction FR→EN : dictionnaire embarqué d'abord (instantané), puis Translation iOS.
    private func englishTerm(for term: String) async -> String? {
        if let quick = FoodTranslator.toEnglish(term) { return quick }
        guard let session = translationSession else { return nil }
        return try? await session.translate(term).targetText
    }
}

#Preview { SearchView().modelContainer(LumeStore.preview) }
