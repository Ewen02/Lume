import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var tab = 0
    private var results: [FoodItem] {
        query.isEmpty ? Mock.foods : Mock.foods.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            SearchBar(text: $query)
            SegmentedPicker(options: ["Résultats", "Favoris", "Récents"], selection: $tab)
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    if results.isEmpty {
                        LumeEmptyState(icon: .search, title: "Aucun résultat",
                                       message: "Essaie un autre nom d'aliment.")
                    } else {
                        ForEach(results) { f in
                            FoodRow(name: f.name,
                                    detail: "\(f.grams) g · P \(f.macros.protein) G \(f.macros.carbs) L \(f.macros.fat)",
                                    kcal: f.macros.kcal)
                        }
                    }
                }.padding(.bottom, Spacing.xxl)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xl)
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Rechercher", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }
}

#Preview { SearchView() }
