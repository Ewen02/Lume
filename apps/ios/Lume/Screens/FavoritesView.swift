import SwiftUI

struct FavoritesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0

    var body: some View {
        VStack(spacing: Spacing.lg) {
            SegmentedPicker(options: ["Favoris", "Récents"], selection: $tab)
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    ForEach(Mock.foods) { f in
                        FoodRow(name: f.name,
                                detail: "\(f.grams) g · \(f.macros.kcal) kcal",
                                kcal: f.macros.kcal,
                                trailing: .add)
                    }
                }.padding(.bottom, Spacing.xxl)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xl)
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Mes aliments", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }
}

#Preview { FavoritesView() }
