import SwiftData
import SwiftUI

struct FoodDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var grams: Int
    @State private var favorite = false
    @State private var added = false
    private let base: FoodItem
    private let meal: MealType
    /// `true` quand l'aliment n'est pas encore au journal (recherche/favoris) → bouton d'ajout.
    /// `false` en consultation d'une entrée déjà loggée (depuis Aujourd'hui) → simple fermeture.
    private let canAddToJournal: Bool

    init(food: FoodItem = Mock.foods[0], meal: MealType = .snack, canAddToJournal: Bool = true) {
        base = food
        self.meal = meal
        self.canAddToJournal = canAddToJournal
        _grams = State(initialValue: food.grams)
    }

    /// macros recalculées au prorata des grammes
    private var factor: Double {
        Double(grams) / Double(max(base.grams, 1))
    }

    private func sc(_ v: Int) -> Int {
        Int((Double(v) * factor).rounded())
    }

    private var scaledMacros: Macros {
        Macros(kcal: sc(base.macros.kcal), protein: sc(base.macros.protein),
               carbs: sc(base.macros.carbs), fat: sc(base.macros.fat))
    }

    private func addToJournal() {
        let m = scaledMacros
        ctx.insert(LoggedFood(meal: meal, name: base.name, grams: grams,
                              kcal: m.kcal, protein: m.protein, carbs: m.carbs, fat: m.fat))
        added = true
        dismiss()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
                        VStack(spacing: Spacing.md) {
                            Text(base.name).font(.lumeTitle).foregroundStyle(LumeColor.ink)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(sc(base.macros.kcal))").font(.lumeNumberXL).foregroundStyle(LumeColor.ink).monospacedDigit()
                                Text("kcal").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                            }
                            PortionStepper(grams: $grams)
                        }.frame(maxWidth: .infinity)
                    }
                    LumeCard {
                        VStack(spacing: Spacing.lg) {
                            macroLine("Protéines", sc(base.macros.protein), LumeColor.protein)
                            macroLine("Glucides", sc(base.macros.carbs), LumeColor.carbs)
                            macroLine("Lipides", sc(base.macros.fat), LumeColor.fat)
                        }
                    }
                }.padding(.horizontal, Spacing.xl).padding(.bottom, 100)
            }
            if canAddToJournal {
                PrimaryButton(title: "Ajouter au journal", icon: .add) { addToJournal() }
                    .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
            } else {
                SecondaryButton(title: "Fermer") { dismiss() }
                    .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
            }
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: added)
        .safeAreaInset(edge: .top) {
            TopBar(title: "Aliment", leading: .back, trailing: favorite ? .favorite : .favorite,
                   onLeading: { dismiss() }, onTrailing: { favorite.toggle() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }

    private func macroLine(_ label: String, _ grams: Int, _ color: Color) -> some View {
        HStack(spacing: Spacing.md) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
            Spacer()
            Text("\(grams) g").font(.lumeCallout).foregroundStyle(LumeColor.textSecondary).monospacedDigit()
        }
    }
}

#Preview { FoodDetailView().modelContainer(LumeStore.preview) }
