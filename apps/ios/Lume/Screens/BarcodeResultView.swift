import SwiftData
import SwiftUI

struct BarcodeResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(HealthManager.self) private var health

    let product: ScannedProduct
    @State private var grams = 30
    @State private var added = false
    private let onLogged: () -> Void

    init(product: ScannedProduct = .sample, onLogged: @escaping () -> Void = {}) {
        self.product = product
        self.onLogged = onLogged
    }

    private var portion: Macros {
        product.per100g.scaled(Double(grams) / 100)
    }

    private var sourceLabel: String {
        product.source == "OpenFoodFacts" ? "Open Food Facts" : product.source
    }

    private func mealForNow() -> MealType {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5 ..< 11: .breakfast
        case 11 ..< 15: .lunch
        case 18 ..< 23: .dinner
        default: .snack
        }
    }

    private func add() {
        ctx.insert(LoggedFood(meal: mealForNow(), name: product.name, grams: grams,
                              kcal: portion.kcal, protein: portion.protein,
                              carbs: portion.carbs, fat: portion.fat))
        let p = portion
        Task { await health.logMeal(kcal: p.kcal, protein: p.protein, carbs: p.carbs, fat: p.fat) }
        added = true
        dismiss()
        onLogged()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    LumeCard {
                        HStack(spacing: Spacing.lg) {
                            Image(appIcon: .barcode).lumeIcon(26, weight: .semibold).foregroundStyle(LumeColor.ink)
                                .frame(width: 56, height: 56).background(LumeColor.cream)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(product.name).font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                                Text(product.code.isEmpty ? sourceLabel : "\(sourceLabel) · \(product.code)")
                                    .font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                            }
                            Spacer()
                        }
                    }
                    LumeCard {
                        VStack(spacing: Spacing.md) {
                            HStack { Text("Portion").font(.lumeBodyMed).foregroundStyle(LumeColor.ink); Spacer(); PortionStepper(grams: $grams) }
                            Rectangle().fill(LumeColor.border).frame(height: 1)
                            valueLine("Calories", "\(portion.kcal) kcal")
                            valueLine("Protéines", "\(portion.protein) g")
                            valueLine("Glucides", "\(portion.carbs) g")
                            valueLine("Lipides", "\(portion.fat) g")
                        }
                    }
                    Text("Données : \(sourceLabel)").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                }.padding(.horizontal, Spacing.xl).padding(.bottom, 100)
            }
            PrimaryButton(title: "Ajouter au journal", icon: .add) { add() }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: added)
        .safeAreaInset(edge: .top) {
            TopBar(title: "Produit scanné", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }

    private func valueLine(_ t: String, _ v: String) -> some View {
        HStack {
            Text(t).font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
            Spacer()
            Text(v).font(.lumeCallout).foregroundStyle(LumeColor.textSecondary).monospacedDigit()
        }
    }
}

#Preview { BarcodeResultView().modelContainer(LumeStore.preview).environment(HealthManager.shared) }
